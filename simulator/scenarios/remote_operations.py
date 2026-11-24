
from simulator.vehicle.state import VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


def execute_remote_operation(
    state: VehicleState,
    state_manager: VehicleStateManager,
    operation: str,
) -> tuple[str, dict[str, str | bool]]:
    """Execute a remote operation and report its result."""

    actions = {
        "LOCK": state_manager.lock_vehicle,
        "UNLOCK": state_manager.unlock_vehicle,
        "START_CABIN_PRECONDITIONING": (
            state_manager.start_cabin_preconditioning
        ),
        "STOP_CABIN_PRECONDITIONING": (
            state_manager.stop_cabin_preconditioning
        ),
    }

    if operation not in actions:
        return (
            "REMOTE_OPERATION_FAILED",
            {
                "operation": operation,
                "reason": "Unsupported remote operation",
            },
        )

    try:
        actions[operation]()
    except ValueError as error:
        return (
            "REMOTE_OPERATION_FAILED",
            {
                "operation": operation,
                "reason": str(error),
            },
        )

    return (
        "REMOTE_OPERATION_SUCCEEDED",
        {
            "operation": operation,
            "is_locked": state.is_locked,
            "cabin_preconditioning_active": (
                state.cabin_preconditioning_active
            ),
        },
    )
