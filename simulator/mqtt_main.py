import json
import logging
import math
import time
from collections import deque

from simulator.communication.message_handler import MQTTMessageHandler
from simulator.communication.mqtt_client import MQTTClient
from simulator.communication.mqtt_handlers import (
    handle_charging_preferences,
    handle_mqtt_command,
    on_mqtt_connected,
)
from simulator.mqtt_cli import (
    DEFAULT_LATITUDE,
    DEFAULT_LONGITUDE,
    create_scenario_executor,
    parse_mqtt_args,
)
from simulator.scenarios.execution_models import ConnectivityStatus
from simulator.scenarios.models import ScenarioStatus, ScenarioType
from simulator.telemetry.generator import generate_telemetry
from simulator.vehicle.charging_tracker import ChargingEventTracker
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState
from simulator.vehicle.state_manager import VehicleStateManager

logger = logging.getLogger(__name__)

__all__ = [
    "DEFAULT_LATITUDE",
    "DEFAULT_LONGITUDE",
    "ChargingEventTracker",
    "create_mqtt_simulator",
    "create_scenario_executor",
    "handle_charging_preferences",
    "handle_mqtt_command",
    "main",
    "on_mqtt_connected",
    "run_mqtt_simulator",
]


def create_mqtt_simulator(
    vehicle_id: str,
    latitude: float = DEFAULT_LATITUDE,
    longitude: float = DEFAULT_LONGITUDE,
    engine: SimulationEngine | None = None,
) -> tuple[VehicleState, VehicleStateManager, MQTTMessageHandler, MQTTClient]:
    """Create the vehicle state and its MQTT communication components."""
    state = VehicleState(
        vehicle_id=vehicle_id,
        latitude=latitude,
        longitude=longitude,
    )
    state_manager = VehicleStateManager(state)
    message_handler = MQTTMessageHandler(state, state_manager)
    sim_engine = engine if engine is not None else SimulationEngine(state)
    message_handler.simulation_engine = sim_engine  # type: ignore[attr-defined]

    mqtt_client = MQTTClient(
        vehicle_id=vehicle_id,
        message_callback=lambda topic, payload: handle_mqtt_command(
            topic,
            payload,
            message_handler,
            mqtt_client,
            sim_engine,
        ),
        on_connected=lambda: on_mqtt_connected(mqtt_client),
    )

    return state, state_manager, message_handler, mqtt_client


def run_mqtt_simulator(
    vehicle_id: str,
    telemetry_interval: float = 5.0,
    scenario: ScenarioType | None = None,
    latitude: float = DEFAULT_LATITUDE,
    longitude: float = DEFAULT_LONGITUDE,
) -> None:
    """Run the simulator, process commands, and publish telemetry."""
    if not math.isfinite(telemetry_interval) or telemetry_interval <= 0:
        raise ValueError("Telemetry interval must be a positive finite number")

    state, _, message_handler, mqtt_client = create_mqtt_simulator(
        vehicle_id,
        latitude=latitude,
        longitude=longitude,
    )
    engine = getattr(message_handler, "simulation_engine", None)
    if not isinstance(engine, SimulationEngine):
        engine = SimulationEngine(state)
    charging_tracker = ChargingEventTracker()
    pending_events: deque[dict] = deque(maxlen=100)
    executor = (
        create_scenario_executor(state, scenario, engine=engine)
        if scenario is not None
        else None
    )

    if executor is not None:
        update = executor.start()
        pending_events.extend(charging_tracker.evaluate(state, engine))
        logger.info("Started scenario %s for vehicle %s", scenario.value, vehicle_id)
        logger.info("Initial scenario telemetry: %s", update.telemetry)

    try:
        mqtt_client.connect()
        logger.info("MQTT simulator started for vehicle %s", vehicle_id)

        while True:
            if mqtt_client.is_connected:
                connectivity = ConnectivityStatus.ONLINE
                if (
                    executor is not None
                    and executor.manager.status == ScenarioStatus.RUNNING
                ):
                    update = executor.advance(telemetry_interval)
                    telemetry = update.telemetry
                    connectivity = update.connectivity
                else:
                    telemetry = generate_telemetry(state)

                pending_events.extend(charging_tracker.evaluate(state, engine))

                if connectivity == ConnectivityStatus.ONLINE:
                    try:
                        mqtt_client.publish(
                            mqtt_client.telemetry_topic,
                            json.dumps(telemetry),
                            qos=0,
                        )
                    except RuntimeError:
                        logger.warning(
                            "Failed to publish telemetry; broker disconnected"
                        )

                    while pending_events:
                        event = pending_events[0]
                        try:
                            mqtt_client.publish(
                                mqtt_client.charging_events_topic,
                                json.dumps(event),
                                qos=1,
                            )
                            pending_events.popleft()
                        except RuntimeError:
                            logger.warning(
                                "Failed to publish charging event %s; will retry",
                                event.get("event_id"),
                            )
                            break

            time.sleep(telemetry_interval)

    except KeyboardInterrupt:
        logger.info("MQTT simulator shutdown requested")

    finally:
        if executor is not None and executor.manager.status == ScenarioStatus.RUNNING:
            executor.stop()

        mqtt_client.disconnect()
        logger.info("MQTT simulator stopped")


def main(argv: list[str] | None = None) -> int:
    """Parse arguments and start the MQTT simulator."""
    args = parse_mqtt_args(argv)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    scenario = ScenarioType(args.scenario) if args.scenario else None
    run_mqtt_simulator(
        args.vehicle_id,
        args.telemetry_interval,
        scenario,
        latitude=args.lat,
        longitude=args.lon,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
