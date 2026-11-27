import argparse
import math

from simulator.scenarios.executor import ScenarioExecutor
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import ScenarioConfig, ScenarioType
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState

DEFAULT_LATITUDE = 12.9716
DEFAULT_LONGITUDE = 77.5946


def create_scenario_executor(
    state: VehicleState,
    scenario: ScenarioType,
    engine: SimulationEngine | None = None,
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
        config = ScenarioConfig(route=((0.0, 0.0), (0.0, 0.01)))

    manager.select_scenario(scenario, config)
    return ScenarioExecutor(manager, engine or SimulationEngine(state))


def parse_mqtt_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse and validate CLI arguments for the MQTT simulator."""
    parser = argparse.ArgumentParser(
        description="Run the XEV 9S MQTT vehicle simulator"
    )
    parser.add_argument("--vehicle-id", default="XEV-001", help="Vehicle identifier")
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
    parser.add_argument(
        "--lat", type=float, default=DEFAULT_LATITUDE, help="Initial vehicle latitude"
    )
    parser.add_argument(
        "--lon", type=float, default=DEFAULT_LONGITUDE, help="Initial vehicle longitude"
    )

    args = parser.parse_args(argv)

    if not math.isfinite(args.telemetry_interval) or args.telemetry_interval <= 0:
        parser.error("Telemetry interval must be a positive finite number")
    if not math.isfinite(args.lat) or not -90 <= args.lat <= 90:
        parser.error("Latitude must be between -90 and 90")
    if not math.isfinite(args.lon) or not -180 <= args.lon <= 180:
        parser.error("Longitude must be between -180 and 180")

    return args
