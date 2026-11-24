import argparse
import json
import logging
import math
from collections.abc import Sequence

from simulator.scenarios.execution_models import ScenarioExecutionUpdate
from simulator.scenarios.executor import ScenarioExecutor
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import (
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState

logger = logging.getLogger(__name__)

def create_simulator(
    vehicle_id: str,
    scenario: ScenarioType,
    config: ScenarioConfig,
) -> ScenarioExecutor:
    """Create and configure a vehicle scenario executor."""

    state = VehicleState(vehicle_id=vehicle_id)
    manager = ScenarioManager(state)
    manager.select_scenario(scenario, config)

    engine = SimulationEngine(state)

    return ScenarioExecutor(manager, engine)

def build_scenario_config(scenario: ScenarioType) -> ScenarioConfig:
    """Build suitable default configuration for each scenario."""

    if scenario in (
        ScenarioType.DRIVING_ROUTE,
        ScenarioType.COMPLETED_JOURNEY,
    ):
        return ScenarioConfig(
            route=((0.0, 0.0), (0.0, 0.01)),
        )

    if scenario == ScenarioType.CHARGING_TO_TARGET:
        return ScenarioConfig(
            initial_battery_percentage=50.0,
            charging_target_percentage=60.0,
        )

    if scenario == ScenarioType.CONNECTIVITY_LOSS_RESTORE:
        return ScenarioConfig(offline_duration_seconds=20)

    return ScenarioConfig()

def display_update(update: ScenarioExecutionUpdate) -> None:
    """Display the latest scenario execution update."""

    print(f"\nScenario status: {update.status.value}")
    print(f"Connectivity: {update.connectivity.value}")

    print("\nVehicle telemetry:")
    print(json.dumps(update.telemetry, indent=4))

    if update.events:
        print("\nScenario events:")
        for event in update.events:
            print(f"- {event.event_type}: {event.details}")

def run_scenario(
    executor: ScenarioExecutor,
    scenario: ScenarioType,
    time_step: float,
    max_steps: int,
) -> None:
    """Start and advance a scenario until it completes."""

    update = executor.start()
    display_update(update)

    static_scenarios = {
        ScenarioType.PARKED_BATTERY_LEVEL,
        ScenarioType.LOW_BATTERY,
    }
    if scenario in static_scenarios:
        return

    for _ in range(max_steps):
        if update.status != ScenarioStatus.RUNNING:
            break

        update = executor.advance(time_step)
        display_update(update)

    if update.status == ScenarioStatus.RUNNING:
        logger.warning(
            "Scenario did not complete within %s steps.",
            max_steps,
        )
        update = executor.stop()
        display_update(update)

def build_parser() -> argparse.ArgumentParser:
    """Build command-line arguments for the simulator."""

    parser = argparse.ArgumentParser(
        description="XEV 9S Vehicle Simulator"
    )

    parser.add_argument(
        "--scenario",
        required=True,
        choices=[scenario.value for scenario in ScenarioType],
        help="Vehicle scenario to execute.",
    )
    parser.add_argument(
        "--vehicle-id",
        default="XEV-001",
        help="Unique simulated vehicle identifier.",
    )
    parser.add_argument(
        "--time-step",
        type=float,
        default=10.0,
        help="Simulated seconds per execution step.",
    )
    parser.add_argument(
        "--max-steps",
        type=int,
        default=30,
        help="Maximum number of execution steps.",
    )

    return parser

def main(argv: Sequence[str] | None = None) -> int:
    """Run the XEV 9S vehicle simulator."""

    parser = build_parser()
    args = parser.parse_args(argv)

    if not math.isfinite(args.time_step) or args.time_step <= 0:
        parser.error("--time-step must be a finite number greater than zero")

    if args.max_steps <= 0:
        parser.error("--max-steps must be greater than zero")

    scenario = ScenarioType(args.scenario)
    config = build_scenario_config(scenario)

    executor = create_simulator(
        vehicle_id=args.vehicle_id,
        scenario=scenario,
        config=config,
    )

    print(f"Starting XEV 9S simulator: {scenario.value}")
    run_scenario(
        executor=executor,
        scenario=scenario,
        time_step=args.time_step,
        max_steps=args.max_steps,
    )

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
