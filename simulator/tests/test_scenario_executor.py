import pytest

from simulator.scenarios.execution_models import ConnectivityStatus
from simulator.scenarios.executor import ScenarioExecutor
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import (
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState


def create_executor(
    scenario: ScenarioType,
    config: ScenarioConfig | None = None,
) -> ScenarioExecutor:
    state = VehicleState(vehicle_id="XEV-001")
    manager = ScenarioManager(state)
    manager.select_scenario(scenario, config)
    engine = SimulationEngine(state)
    return ScenarioExecutor(manager, engine)


def test_parked_scenario_generates_initial_telemetry() -> None:
    executor = create_executor(ScenarioType.PARKED_BATTERY_LEVEL)

    update = executor.start()

    assert update.status == ScenarioStatus.RUNNING
    assert update.telemetry["vehicle_id"] == "XEV-001"
    assert update.telemetry["operating_state"] == "parked"


def test_low_battery_scenario_emits_alert() -> None:
    executor = create_executor(
        ScenarioType.LOW_BATTERY,
        ScenarioConfig(
            initial_battery_percentage=80,
            battery_alert_threshold=20,
        ),
    )

    update = executor.start()

    assert update.telemetry["battery_percentage"] == 19
    assert any(event.event_type == "LOW_BATTERY" for event in update.events)


def test_driving_route_completes_journey() -> None:
    executor = create_executor(
        ScenarioType.DRIVING_ROUTE,
        ScenarioConfig(route=((0, 0), (0, 0.01))),
    )

    executor.start()
    update = executor.advance(120)

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["operating_state"] == "parked"
    assert any(
        event.event_type == "JOURNEY_COMPLETED"
        for event in update.events
    )


def test_charging_reaches_target() -> None:
    executor = create_executor(
        ScenarioType.CHARGING_TO_TARGET,
        ScenarioConfig(
            initial_battery_percentage=50,
            charging_target_percentage=51,
        ),
    )

    executor.start()
    update = executor.advance(300)

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["battery_percentage"] == pytest.approx(51)
    assert update.telemetry["charging_status"] == "disconnected"


def test_charging_interruption_changes_state() -> None:
    executor = create_executor(ScenarioType.CHARGING_INTERRUPTION)

    executor.start()
    update = executor.advance(1)

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["operating_state"] == "interrupted"


def test_remote_success_confirms_state_transition() -> None:
    executor = create_executor(ScenarioType.REMOTE_OP_SUCCESS)

    update = executor.start()

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["is_locked"] is False
    assert any(
        event.event_type == "REMOTE_OPERATION_SUCCEEDED"
        for event in update.events
    )


def test_remote_failure_contains_reason() -> None:
    executor = create_executor(ScenarioType.REMOTE_OP_FAILURE)

    update = executor.start()

    failure = next(
        event for event in update.events
        if event.event_type == "REMOTE_OPERATION_FAILED"
    )
    assert failure.details["reason"]
    assert update.telemetry["is_locked"] is True


def test_connectivity_is_restored_after_duration() -> None:
    executor = create_executor(
        ScenarioType.CONNECTIVITY_LOSS_RESTORE,
        ScenarioConfig(offline_duration_seconds=10),
    )

    executor.start()
    offline_update = executor.advance(4)
    restored_update = executor.advance(6)

    assert offline_update.connectivity == ConnectivityStatus.OFFLINE
    assert restored_update.connectivity == ConnectivityStatus.ONLINE
    assert restored_update.status == ScenarioStatus.COMPLETED


def test_completed_journey_uses_route() -> None:
    executor = create_executor(
        ScenarioType.COMPLETED_JOURNEY,
        ScenarioConfig(route=((0, 0), (0, 0.01))),
    )

    executor.start()
    update = executor.advance(120)

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["operating_state"] == "parked"


def test_reset_restores_initial_scenario_state() -> None:
    executor = create_executor(
        ScenarioType.REMOTE_OP_SUCCESS,
    )

    executor.start()
    update = executor.reset()

    assert update.status == ScenarioStatus.IDLE
    assert update.telemetry["is_locked"] is True
    assert update.connectivity == ConnectivityStatus.ONLINE


def test_executor_rejects_different_state_instances() -> None:
    state = VehicleState(vehicle_id="XEV-001")
    manager = ScenarioManager(state)
    engine = SimulationEngine(VehicleState(vehicle_id="XEV-002"))

    with pytest.raises(ValueError, match="must share state"):
        ScenarioExecutor(manager, engine)


def test_advance_rejects_invalid_elapsed_time() -> None:
    executor = create_executor(ScenarioType.PARKED_BATTERY_LEVEL)
    executor.start()

    with pytest.raises(ValueError, match="finite and positive"):
        executor.advance(0)


def test_advance_requires_running_scenario() -> None:
    executor = create_executor(ScenarioType.PARKED_BATTERY_LEVEL)

    with pytest.raises(ValueError, match="running scenario"):
        executor.advance(1)


def test_driving_scenario_requires_route() -> None:
    executor = create_executor(ScenarioType.DRIVING_ROUTE)

    with pytest.raises(ValueError, match="route is required"):
        executor.start()