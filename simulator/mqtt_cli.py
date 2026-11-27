import argparse
import math
import os

from simulator.scenarios.executor import ScenarioExecutor
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import ScenarioConfig, ScenarioType
from simulator.scenarios.route import build_route
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState

DEFAULT_LATITUDE = 12.9716
DEFAULT_LONGITUDE = 77.5946


def _validate_percentage(value: float, name: str) -> float:
    """Validate that a percentage value is a finite number between 0 and 100."""
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(value)
        or not 0 <= value <= 100
    ):
        raise ValueError(f"{name} must be between 0 and 100")
    return float(value)


def create_scenario_executor(
    state: VehicleState,
    scenario: ScenarioType,
    engine: SimulationEngine | None = None,
) -> ScenarioExecutor:
    """Prepare a scenario using the MQTT simulator's vehicle state."""
    manager = ScenarioManager(state)
    config = ScenarioConfig()
    sim_engine = engine or SimulationEngine(state)

    if scenario == ScenarioType.CHARGING_TO_TARGET:
        initial_battery = _validate_percentage(
            state.battery_percentage,
            "initial_battery_percentage",
        )
        raw_target = (
            sim_engine.target_percentage
            if sim_engine.stop_charging_at_target
            else 100.0
        )
        target_battery = _validate_percentage(
            raw_target,
            "charging_target_percentage",
        )
        config = ScenarioConfig(
            initial_battery_percentage=initial_battery,
            charging_target_percentage=target_battery,
        )
    elif scenario in (
        ScenarioType.DRIVING_ROUTE,
        ScenarioType.COMPLETED_JOURNEY,
    ):
        start_lat = state.latitude if state.latitude is not None else DEFAULT_LATITUDE
        start_lon = (
            state.longitude if state.longitude is not None else DEFAULT_LONGITUDE
        )
        loop = scenario == ScenarioType.DRIVING_ROUTE
        config = ScenarioConfig(
            route=build_route(start_lat, start_lon, loop=loop),
            loop_route=loop,
        )

    manager.select_scenario(scenario, config)
    return ScenarioExecutor(manager, sim_engine)


def parse_mqtt_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse and validate CLI arguments for the MQTT simulator."""
    env_vehicle_id = os.getenv("VEHICLE_ID", "XEV-001")
    env_interval = os.getenv("TELEMETRY_INTERVAL", "5.0")

    parser = argparse.ArgumentParser(
        description="Run the XEV 9S MQTT vehicle simulator"
    )
    parser.add_argument(
        "--vehicle-id",
        default=env_vehicle_id,
        help="Vehicle identifier",
    )
    parser.add_argument(
        "--telemetry-interval",
        default=env_interval,
        help="Telemetry publishing interval in seconds",
    )
    parser.add_argument(
        "--scenario",
        choices=[scenario.value for scenario in ScenarioType],
        default=None,
        help="Optional demonstration scenario to execute",
    )
    parser.add_argument(
        "--lat", type=float, default=DEFAULT_LATITUDE, help="Initial vehicle latitude"
    )
    parser.add_argument(
        "--lon", type=float, default=DEFAULT_LONGITUDE, help="Initial vehicle longitude"
    )

    args = parser.parse_args(argv)

    if not args.vehicle_id.strip() or any(ch in args.vehicle_id for ch in "/+#"):
        parser.error("Vehicle ID is invalid for MQTT topics")

    try:
        args.telemetry_interval = float(args.telemetry_interval)
    except (TypeError, ValueError):
        parser.error("Telemetry interval must be a positive finite number")

    if not math.isfinite(args.telemetry_interval) or args.telemetry_interval <= 0:
        parser.error("Telemetry interval must be a positive finite number")
    if not math.isfinite(args.lat) or not -90 <= args.lat <= 90:
        parser.error("Latitude must be between -90 and 90")
    if not math.isfinite(args.lon) or not -180 <= args.lon <= 180:
        parser.error("Longitude must be between -180 and 180")

    return args
