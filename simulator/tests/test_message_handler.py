
import json

import pytest

from simulator.communication.message_handler import MQTTMessageHandler
from simulator.scenarios.models import RemoteOperation
from simulator.vehicle.state import VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


@pytest.mark.parametrize(
    (
        "operation",
        "initial_locked",
        "initial_preconditioning",
        "expected_locked",
        "expected_preconditioning",
    ),
    [
        (RemoteOperation.LOCK, False, False, True, False),
        (RemoteOperation.UNLOCK, True, False, False, False),
        (RemoteOperation.START_CABIN_PRECONDITIONING, True, False, True, True),
        (RemoteOperation.STOP_CABIN_PRECONDITIONING, True, True, True, False),
    ],
)
def test_successful_command_execution(
    operation: RemoteOperation,
    initial_locked: bool,
    initial_preconditioning: bool,
    expected_locked: bool,
    expected_preconditioning: bool,
) -> None:
    state = VehicleState(
        vehicle_id="XEV-001",
        is_locked=initial_locked,
        cabin_preconditioning_active=initial_preconditioning,
    )
    handler = MQTTMessageHandler(state, VehicleStateManager(state))

    payload = json.dumps({
        "command_id": "cmd-1",
        "operation": operation.value,
    }).encode()

    response = handler.handle_message(payload)

    assert response["status"] == "SUCCESS"
    assert response["command_id"] == "cmd-1"
    assert response["vehicle_id"] == "XEV-001"
    assert state.is_locked is expected_locked
    assert (
        state.cabin_preconditioning_active
        is expected_preconditioning
    )


def test_invalid_json_returns_failure() -> None:
    state = VehicleState(vehicle_id="XEV-001")
    handler = MQTTMessageHandler(state, VehicleStateManager(state))

    response = handler.handle_message(b"invalid-json")

    assert response["status"] == "FAILED"
    assert response["details"]["reason"] == "Invalid JSON payload"


def test_missing_command_id_returns_failure() -> None:
    state = VehicleState(vehicle_id="XEV-001")
    handler = MQTTMessageHandler(state, VehicleStateManager(state))

    response = handler.handle_message(b'{"operation":"LOCK"}')

    assert response["status"] == "FAILED"
    assert response["details"]["reason"] == "A valid command_id is required"


def test_missing_operation_returns_failure() -> None:
    state = VehicleState(vehicle_id="XEV-001")
    handler = MQTTMessageHandler(state, VehicleStateManager(state))

    response = handler.handle_message(b'{"command_id":"cmd-1"}')

    assert response["status"] == "FAILED"
    assert response["details"]["reason"] == "A valid operation is required"


def test_unsupported_operation_returns_failure() -> None:
    state = VehicleState(vehicle_id="XEV-001")
    handler = MQTTMessageHandler(state, VehicleStateManager(state))

    response = handler.handle_message(
        b'{"command_id":"cmd-1","operation":"FLY"}'
    )

    assert response["status"] == "FAILED"
    assert response["details"]["reason"] == "Unsupported remote operation"


def test_invalid_state_transition_returns_failure() -> None:
    state = VehicleState(vehicle_id="XEV-001", is_locked=True)
    handler = MQTTMessageHandler(state, VehicleStateManager(state))

    response = handler.handle_message(
        b'{"command_id":"cmd-1","operation":"LOCK"}'
    )

    assert response["status"] == "FAILED"
    assert response["details"]["reason"] == "Vehicle is already locked"


def test_duplicate_command_returns_cached_response() -> None:
    state = VehicleState(vehicle_id="XEV-001", is_locked=False)
    handler = MQTTMessageHandler(state, VehicleStateManager(state))
    payload = b'{"command_id":"cmd-1","operation":"LOCK"}'

    first = handler.handle_message(payload)
    second = handler.handle_message(payload)

    assert first == second
    assert first["status"] == "SUCCESS"
