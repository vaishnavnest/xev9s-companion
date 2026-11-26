
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any

from backend.app.core.exceptions import InvalidCommandResponseError
from backend.app.repositories.command_repository import CommandRepository
from backend.app.schemas.command import CommandStatus
from backend.app.services.command_timeout_manager import CommandTimeoutManager


class CommandResponseService:
    """Process and validate remote vehicle command responses."""

    def __init__(
        self,
        command_repository: CommandRepository,
        timeout_manager: CommandTimeoutManager,
        on_command_updated: Callable[[dict[str, Any]], None] | None = None,
    ) -> None:
        self.command_repository = command_repository
        self.timeout_manager = timeout_manager
        self.on_command_updated = on_command_updated

    def handle_response(self, response: dict[str, Any]) -> bool:
        """Apply a valid simulator response without overwriting final states."""

        command_id = response.get("command_id")
        vehicle_id = response.get("vehicle_id")
        operation = response.get("operation")
        status = response.get("status")
        timestamp = response.get("timestamp")
        details = response.get("details")

        if not all(
            isinstance(value, str) and value.strip()
            for value in (
                command_id,
                vehicle_id,
                operation,
                status,
                timestamp,
            )
        ):
            raise InvalidCommandResponseError(
                "Command response contains missing or invalid fields"
            )

        command = self.command_repository.get_command_for_response(
            command_id,
            vehicle_id,
        )

        if command is None:
            raise InvalidCommandResponseError(
                "Command response does not match an existing command"
            )

        if operation != command["operation"].upper():
            raise InvalidCommandResponseError(
                "Command response operation does not match"
            )

        status_mapping = {
            "SUCCESS": CommandStatus.SUCCEEDED,
            "FAILED": CommandStatus.FAILED,
        }
        command_status = status_mapping.get(status)

        if command_status is None:
            raise InvalidCommandResponseError(
                "Unsupported simulator response status"
            )

        if details is not None and not isinstance(details, dict):
            raise InvalidCommandResponseError(
                "Command response details must be an object"
            )

        try:
            completed_at = datetime.fromisoformat(timestamp)
        except ValueError as exc:
            raise InvalidCommandResponseError(
                "Command response timestamp is invalid"
            ) from exc

        if completed_at.tzinfo is None or completed_at.utcoffset() is None:
            raise InvalidCommandResponseError(
                "Command response timestamp must include a timezone"
            )

        completed_at = completed_at.astimezone(UTC)
        failure_reason = None

        if command_status == CommandStatus.FAILED:
            reason = details.get("reason") if details else None
            failure_reason = (
                reason
                if isinstance(reason, str) and reason.strip()
                else "Vehicle rejected the command"
            )

        updated = self.command_repository.update_command_result(
            command_id,
            vehicle_id,
            command_status,
            completed_at,
            failure_reason,
        )

        self.timeout_manager.cancel(command_id)

        if updated and self.on_command_updated is not None:
            notification = {
                "event": "command_updated",
                "command_id": command_id,
                "vehicle_id": vehicle_id,
                "operation": command["operation"],
                "status": command_status.value,
                "requested_at": command["requested_at"],
                "completed_at": completed_at,
                "failure_reason": failure_reason,
            }
            self.on_command_updated(notification)

        return updated
