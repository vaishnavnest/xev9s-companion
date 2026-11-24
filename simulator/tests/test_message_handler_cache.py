
import json
from concurrent.futures import ThreadPoolExecutor

from simulator.communication.message_handler import MQTTMessageHandler
from simulator.vehicle.state import VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


def test_reused_command_id_with_different_operation_fails() -> None:
    state = VehicleState(vehicle_id="XEV-001", is_locked=False)
    handler = MQTTMessageHandler(state, VehicleStateManager(state))

    first = handler.handle_message(
        b'{"command_id":"cmd-1","operation":"LOCK"}'
    )
    second = handler.handle_message(
        b'{"command_id":"cmd-1","operation":"UNLOCK"}'
    )

    assert first["status"] == "SUCCESS"
    assert second["status"] == "FAILED"
    assert "different operation" in second["details"]["reason"]
    assert state.is_locked is True


def test_command_cache_respects_maximum_size() -> None:
    state = VehicleState(vehicle_id="XEV-001")
    handler = MQTTMessageHandler(state, VehicleStateManager(state))
    handler.MAX_PROCESSED_COMMANDS = 2

    for command_id in ("cmd-1", "cmd-2", "cmd-3"):
        payload = json.dumps({
            "command_id": command_id,
            "operation": "LOCK",
        }).encode()
        handler.handle_message(payload)

    assert len(handler._processed_commands) == 2
    assert "cmd-1" not in handler._processed_commands
    assert "cmd-2" in handler._processed_commands
    assert "cmd-3" in handler._processed_commands


def test_returned_response_cannot_modify_cached_response() -> None:
    state = VehicleState(vehicle_id="XEV-001", is_locked=False)
    handler = MQTTMessageHandler(state, VehicleStateManager(state))
    payload = b'{"command_id":"cmd-1","operation":"LOCK"}'

    first = handler.handle_message(payload)
    first["details"]["is_locked"] = False

    second = handler.handle_message(payload)

    assert second["details"]["is_locked"] is True


def test_concurrent_duplicate_commands_execute_once() -> None:
    state = VehicleState(vehicle_id="XEV-001", is_locked=False)
    handler = MQTTMessageHandler(state, VehicleStateManager(state))
    payload = b'{"command_id":"cmd-concurrent","operation":"LOCK"}'

    with ThreadPoolExecutor(max_workers=8) as executor:
        responses = list(
            executor.map(
                handler.handle_message,
                [payload] * 8,
            )
        )

    assert all(response == responses[0] for response in responses)
    assert responses[0]["status"] == "SUCCESS"
    assert state.is_locked is True
