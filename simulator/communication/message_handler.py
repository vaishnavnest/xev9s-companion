
import json
from collections import OrderedDict
from copy import deepcopy
from datetime import UTC, datetime
from threading import Lock
from typing import Any

from simulator.scenarios.models import RemoteOperation
from simulator.scenarios.remote_operations import execute_remote_operation
from simulator.vehicle.state import VehicleState
from simulator.vehicle.state_manager import VehicleStateManager

SUPPORTED_OPERATIONS = frozenset(
    operation.value for operation in RemoteOperation
)


class MQTTMessageHandler:
    """Validate and process commands received through MQTT."""

    MAX_PROCESSED_COMMANDS = 1000

    def __init__(
        self,
        state: VehicleState,
        state_manager: VehicleStateManager,
    ) -> None:
        if state_manager.state is not state:
            raise ValueError(
                "State manager must manage the supplied vehicle state"
            )

        self.state = state
        self.state_manager = state_manager
        self._processed_commands: OrderedDict[
            str, tuple[str, dict[str, Any]]
        ] = OrderedDict()
        self._command_lock = Lock()

    def handle_message(self, payload: bytes) -> dict[str, Any]:
        """Process a command payload and return its execution response."""

        try:
            message = json.loads(payload)
        except (json.JSONDecodeError, UnicodeDecodeError):
            return self._failure_response(
                None, None, "Invalid JSON payload"
            )

        if not isinstance(message, dict):
            return self._failure_response(
                None, None, "Command payload must be a JSON object"
            )

        command_id = message.get("command_id")
        operation = message.get("operation")

        if not isinstance(command_id, str) or not command_id.strip():
            return self._failure_response(
                None, operation, "A valid command_id is required"
            )

        command_id = command_id.strip()

        if not isinstance(operation, str):
            return self._failure_response(
                command_id, None, "A valid operation is required"
            )

        with self._command_lock:
            return self._process_command(command_id, operation)

    def _process_command(
        self,
        command_id: str,
        operation: str,
    ) -> dict[str, Any]:
        """Execute commands safely and prevent duplicate processing."""

        cached = self._processed_commands.get(command_id)

        if cached is not None:
            previous_operation, previous_response = cached

            if operation != previous_operation:
                return self._failure_response(
                    command_id,
                    operation,
                    "Command ID was already used for a different operation",
                )

            self._processed_commands.move_to_end(command_id)
            return deepcopy(previous_response)

        if operation not in SUPPORTED_OPERATIONS:
            response = self._failure_response(
                command_id,
                operation,
                "Unsupported remote operation",
            )
        else:
            event_type, details = execute_remote_operation(
                self.state,
                self.state_manager,
                operation,
            )
            response = self._build_response(
                command_id,
                operation,
                event_type == "REMOTE_OPERATION_SUCCEEDED",
                details,
            )

        self._processed_commands[command_id] = (
            operation,
            deepcopy(response),
        )

        if len(self._processed_commands) > self.MAX_PROCESSED_COMMANDS:
            self._processed_commands.popitem(last=False)

        return deepcopy(response)

    def _failure_response(
        self,
        command_id: str | None,
        operation: Any,
        reason: str,
    ) -> dict[str, Any]:
        """Build a failure response for an invalid command."""

        return self._build_response(
            command_id,
            operation,
            False,
            {"reason": reason},
        )

    def _build_response(
        self,
        command_id: str | None,
        operation: Any,
        succeeded: bool,
        details: dict[str, Any],
    ) -> dict[str, Any]:
        """Build a consistent command response."""

        return {
            "command_id": command_id,
            "vehicle_id": self.state.vehicle_id,
            "operation": operation,
            "status": "SUCCESS" if succeeded else "FAILED",
            "details": details,
            "timestamp": datetime.now(UTC).isoformat(),
        }
