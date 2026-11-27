
import argparse
import json
import logging
import math
import time

from simulator.communication.message_handler import MQTTMessageHandler
from simulator.communication.mqtt_client import MQTTClient
from simulator.scenarios.executor import ScenarioExecutor
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import (
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)
from simulator.telemetry.generator import generate_telemetry
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState
from simulator.vehicle.state_manager import VehicleStateManager

logger = logging.getLogger(__name__)

def on_mqtt_connected(mqtt_client: MQTTClient) -> None:
    """Subscribe to the vehicle command topic after connecting."""
    mqtt_client.subscribe(mqtt_client.command_topic, qos=1)
    logger.info("Listening for commands on %s", mqtt_client.command_topic)


def handle_mqtt_command(
    topic: str,
    payload: bytes,
    message_handler: MQTTMessageHandler,
    mqtt_client: MQTTClient,
) -> None:
    """Execute an incoming command and publish its response."""
    if topic != mqtt_client.command_topic:
        logger.warning("Ignoring unexpected MQTT topic: %s", topic)
        return

    response = message_handler.handle_message(payload)

    try:
        mqtt_client.publish(
            mqtt_client.response_topic,
            json.dumps(response),
            qos=1,
        )
    except RuntimeError:
        logger.exception("Failed to publish command response")
        return

    logger.info(
        "Processed command %s with status %s",
        response.get("command_id"),
        response.get("status"),
    )

def create_mqtt_simulator(
    vehicle_id: str,
) -> tuple[VehicleState, VehicleStateManager, MQTTMessageHandler, MQTTClient]:
    """Create the vehicle state and its MQTT communication components."""
    state = VehicleState(vehicle_id=vehicle_id)
    state_manager = VehicleStateManager(state)
    message_handler = MQTTMessageHandler(state, state_manager)

    mqtt_client = MQTTClient(
        vehicle_id=vehicle_id,
        message_callback=lambda topic, payload: handle_mqtt_command(
            topic,
            payload,
            message_handler,
            mqtt_client,
        ),
        on_connected=lambda: on_mqtt_connected(mqtt_client),
    )

    return state, state_manager, message_handler, mqtt_client

def create_scenario_executor(
    state: VehicleState,
    scenario: ScenarioType,
) -> ScenarioExecutor:
    """Prepare a scenario using the MQTT simulator's vehicle state."""
    manager = ScenarioManager(state)

    config = ScenarioConfig()

    if scenario == ScenarioType.CHARGING_TO_TARGET:
        config = ScenarioConfig(
            initial_battery_percentage=50.0,
            charging_target_percentage=90.0,
        )
    elif scenario in (
        ScenarioType.DRIVING_ROUTE,
        ScenarioType.COMPLETED_JOURNEY,
    ):
        config = ScenarioConfig(
            route=((0.0, 0.0), (0.0, 0.01)),
        )

    manager.select_scenario(scenario, config)
    return ScenarioExecutor(manager, SimulationEngine(state))

def run_mqtt_simulator(
    vehicle_id: str,
    telemetry_interval: float = 5.0,
    scenario: ScenarioType | None = None,
) -> None:
    """Run the simulator, process commands, and publish telemetry."""
    if not math.isfinite(telemetry_interval) or telemetry_interval <= 0:
        raise ValueError("Telemetry interval must be a positive finite number")

    state, _, _, mqtt_client = create_mqtt_simulator(vehicle_id)
    executor = (
        create_scenario_executor(state, scenario)
        if scenario is not None
        else None
    )

    if executor is not None:
        update = executor.start()
        logger.info("Started scenario %s for vehicle %s", scenario.value, vehicle_id)
        logger.info("Initial scenario telemetry: %s", update.telemetry)

    try:
        mqtt_client.connect()
        logger.info("MQTT simulator started for vehicle %s", vehicle_id)

        while True:
            if mqtt_client.is_connected:
                if (
                    executor is not None
                    and executor.manager.status == ScenarioStatus.RUNNING
                ):
                    telemetry = executor.advance(telemetry_interval).telemetry
                else:
                    telemetry = generate_telemetry(state)

                mqtt_client.publish(
                    mqtt_client.telemetry_topic,
                    json.dumps(telemetry),
                    qos=0,
                )

            time.sleep(telemetry_interval)

    except KeyboardInterrupt:
        logger.info("MQTT simulator shutdown requested")

    finally:
        if (
            executor is not None
            and executor.manager.status == ScenarioStatus.RUNNING
        ):
            executor.stop()

        mqtt_client.disconnect()
        logger.info("MQTT simulator stopped")

def main(argv: list[str] | None = None) -> int:
    """Parse arguments and start the MQTT simulator."""
    parser = argparse.ArgumentParser(
        description="Run the XEV 9S MQTT vehicle simulator"
    )
    parser.add_argument(
        "--vehicle-id",
        default="XEV-001",
        help="Vehicle identifier",
    )
    parser.add_argument(
        "--telemetry-interval",
        type=float,
        default=5.0,
        help="Telemetry publishing interval in seconds",
    )
    parser.add_argument(
        "--scenario",
        choices=[scenario.value for scenario in ScenarioType],
        default=None,
        help="Optional demonstration scenario to execute",
    )

    args = parser.parse_args(argv)

    if not math.isfinite(args.telemetry_interval) or args.telemetry_interval <= 0:
        parser.error("Telemetry interval must be a positive finite number")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    scenario = ScenarioType(args.scenario) if args.scenario else None
    run_mqtt_simulator(
        args.vehicle_id,
        args.telemetry_interval,
        scenario,
    )
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
