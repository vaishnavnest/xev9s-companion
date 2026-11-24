
import pytest

from simulator.scenarios.execution_models import ConnectivityStatus
from simulator.scenarios.executor import ScenarioExecutor
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import ScenarioConfig, ScenarioStatus, ScenarioType
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState


def create_executor(
    scenario: ScenarioType,
    config: ScenarioConfig | None = None,
) -> ScenarioExecutor:
    state = VehicleState(vehicle_id="XEV-001")
    manager = ScenarioManager(state)
    manager.select_scenario(scenario, config)
    return ScenarioExecutor(manager, SimulationEngine(state))


def test_multisegment_route_progresses_across_updates() -> None:
    route = ((0, 0), (0, 0.005), (0, 0.01))
    executor = create_executor(
        ScenarioType.DRIVING_ROUTE,
        ScenarioConfig(route=route),
    )

    executor.start()
    first_update = executor.advance(40)
    first_longitude = first_update.telemetry["longitude"]

    second_update = executor.advance(10)
    second_longitude = second_update.telemetry["longitude"]

    assert 0.005 < first_longitude < 0.01
    assert first_longitude < second_longitude < 0.01
    assert second_update.status == ScenarioStatus.RUNNING


def test_completed_scenario_requires_reset_before_restart() -> None:
    executor = create_executor(ScenarioType.REMOTE_OP_SUCCESS)
    executor.start()

    with pytest.raises(ValueError, match="Reset the scenario"):
        executor.start()


def test_stopped_scenario_requires_reset_before_restart() -> None:
    executor = create_executor(ScenarioType.PARKED_BATTERY_LEVEL)
    executor.start()
    executor.stop()

    with pytest.raises(ValueError, match="Reset the scenario"):
        executor.start()


def test_stopping_offline_scenario_restores_connectivity() -> None:
    executor = create_executor(
        ScenarioType.CONNECTIVITY_LOSS_RESTORE,
        ScenarioConfig(offline_duration_seconds=10),
    )

    executor.start()
    offline_update = executor.advance(2)

    assert offline_update.connectivity == ConnectivityStatus.OFFLINE

    stopped_update = executor.stop()

    assert stopped_update.status == ScenarioStatus.STOPPED
    assert stopped_update.connectivity == ConnectivityStatus.ONLINE

def test_zero_distance_route_completes_immediately() -> None:
    executor = create_executor(
        ScenarioType.DRIVING_ROUTE,
        ScenarioConfig(route=((0, 0), (0, 0))),
    )

    executor.start()
    update = executor.advance(1)

    assert update.status == ScenarioStatus.COMPLETED
    assert any(
        event.event_type == "JOURNEY_COMPLETED"
        for event in update.events
    )


def test_driving_with_empty_battery_ends_journey() -> None:
    executor = create_executor(
        ScenarioType.DRIVING_ROUTE,
        ScenarioConfig(
            initial_battery_percentage=0,
            route=((0, 0), (0, 0.01)),
        ),
    )

    executor.start()
    update = executor.advance(1)

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["battery_percentage"] == 0
    assert any(
        event.event_type == "JOURNEY_ENDED"
        and event.details["reason"] == "BATTERY_DEPLETED"
        for event in update.events
    )



def test_charging_completes_when_target_already_reached() -> None:
    executor = create_executor(
        ScenarioType.CHARGING_TO_TARGET,
        ScenarioConfig(
            initial_battery_percentage=70,
            charging_target_percentage=80,
        ),
    )

    executor.start()

    executor.state.battery_percentage = 80
    update = executor.advance(1)

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["charging_status"] == "disconnected"
    assert any(
        event.event_type == "CHARGING_TARGET_REACHED"
        for event in update.events
    )
