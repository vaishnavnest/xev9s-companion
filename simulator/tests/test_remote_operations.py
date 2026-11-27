
import pytest
from simulator.scenarios.executor import ScenarioExecutor
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import (
    RemoteOperation,
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState


@pytest.mark.parametrize(
    ("operation", "should_succeed"),
    [
        (operation, result)
        for operation in RemoteOperation
        for result in (True, False)
    ],
)
def test_remote_operation_execution(
    operation: RemoteOperation,
    should_succeed: bool,
) -> None:
    scenario = (
        ScenarioType.REMOTE_OP_SUCCESS
        if should_succeed
        else ScenarioType.REMOTE_OP_FAILURE
    )

    state = VehicleState(vehicle_id="XEV-001")
    manager = ScenarioManager(state)
    manager.select_scenario(
        scenario,
        ScenarioConfig(remote_operation=operation),
    )

    executor = ScenarioExecutor(manager, SimulationEngine(state))
    update = executor.start()

    expected_event = (
        "REMOTE_OPERATION_SUCCEEDED"
        if should_succeed
        else "REMOTE_OPERATION_FAILED"
    )

    event = next(
        event
        for event in update.events
        if event.event_type in (
            "REMOTE_OPERATION_SUCCEEDED",
            "REMOTE_OPERATION_FAILED",
        )
    )

    assert event.event_type == expected_event
    assert event.details["operation"] == operation.value
    assert update.status == ScenarioStatus.COMPLETED

    if not should_succeed:
        assert event.details["reason"]

    expected_states = {
    RemoteOperation.LOCK: (True, False),
    RemoteOperation.UNLOCK: (False, False),
    RemoteOperation.START_CABIN_PRECONDITIONING: (True, True),
    RemoteOperation.STOP_CABIN_PRECONDITIONING: (True, False),
     }

    expected_locked, expected_preconditioning = expected_states[operation]

    assert update.telemetry["is_locked"] is expected_locked
    assert (
        update.telemetry["cabin_preconditioning_active"]
        is expected_preconditioning
    )
