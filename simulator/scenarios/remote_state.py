
from simulator.scenarios.models import (
    RemoteOperation,
    ScenarioConfig,
    ScenarioType,
)
from simulator.vehicle.state import VehicleState


def prepare_remote_operation_state(
    state: VehicleState,
    scenario: ScenarioType,
    config: ScenarioConfig,
) -> None:
    """Prepare vehicle state for a remote-operation scenario."""

    operation = config.remote_operation

    if operation is None:
        operation = (
            RemoteOperation.UNLOCK
            if scenario == ScenarioType.REMOTE_OP_SUCCESS
            else RemoteOperation.LOCK
        )

    should_succeed = scenario == ScenarioType.REMOTE_OP_SUCCESS

    if operation == RemoteOperation.LOCK:
        state.is_locked = not should_succeed

    elif operation == RemoteOperation.UNLOCK:
        state.is_locked = should_succeed

    elif operation == RemoteOperation.START_CABIN_PRECONDITIONING:
        state.cabin_preconditioning_active = not should_succeed

    elif operation == RemoteOperation.STOP_CABIN_PRECONDITIONING:
        state.cabin_preconditioning_active = should_succeed
