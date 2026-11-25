
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any

from backend.app.core.command_config import (
    VEHICLE_ONLINE_TIMEOUT_SECONDS,
)
from backend.app.core.exceptions import (
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
    VehicleOfflineError,
)
from backend.app.repositories.command_repository import (
    CommandRepository,
)
from backend.app.repositories.telemetry_repository import (
    TelemetryRepository,
)
from backend.app.repositories.vehicle_repository import (
    VehicleRepository,
)
from backend.app.schemas.command import (
    CommandRequest,
    CommandStatus,
)
from backend.app.services.command_timeout_manager import (
    CommandTimeoutManager,
)


class CommandService:
    """Manage remote vehicle command submission and retrieval."""

    def __init__(
        self,
        command_repository: CommandRepository,
        vehicle_repository: VehicleRepository,
        telemetry_repository: TelemetryRepository,
        publish_command: Callable[[str, dict[str, Any]], None],
        timeout_manager: CommandTimeoutManager | None = None,
    ) -> None:
        self.command_repository = command_repository
        self.vehicle_repository = vehicle_repository
        self.telemetry_repository = telemetry_repository
        self.publish_command = publish_command
        self.timeout_manager = timeout_manager

    def _validate_vehicle_access(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> str:
        """Validate vehicle identity, ownership and active status."""

        normalized_id = vehicle_id.strip()

        if not normalized_id:
            raise ValueError("Vehicle identifier cannot be empty")

        if not self.vehicle_repository.is_vehicle_associated_with_user(
            user_id,
            normalized_id,
        ):
            raise VehicleAccessDeniedError(
                "You do not have access to this vehicle"
            )

        if self.vehicle_repository.get_active_vehicle_by_id(
            normalized_id
        ) is None:
            raise VehicleNotActiveError(
                "Vehicle is not registered or active"
            )

        return normalized_id

    def _ensure_vehicle_online(self, vehicle_id: str) -> None:
        """Reject vehicles without sufficiently recent telemetry."""

        telemetry = self.telemetry_repository.get_latest_telemetry(
            vehicle_id
        )

        if telemetry is None:
            raise VehicleOfflineError(
                "Vehicle has no recorded telemetry"
            )

        timestamp = telemetry.get("timestamp")

        if not isinstance(timestamp, datetime):
            raise VehicleOfflineError(
                "Vehicle telemetry timestamp is invalid"
            )

        if timestamp.tzinfo is None or timestamp.utcoffset() is None:
            # PyMongo returns naive UTC datetimes by default.
            timestamp = timestamp.replace(tzinfo=UTC)

        now = datetime.now(UTC)
        age = now - timestamp

        if age < timedelta(0):
            raise VehicleOfflineError(
                "Vehicle telemetry timestamp is in the future"
            )

        if age > timedelta(
            seconds=VEHICLE_ONLINE_TIMEOUT_SECONDS
        ):
            raise VehicleOfflineError(
                "Vehicle is offline because telemetry is stale"
            )

    def submit_command(
        self,
        user_id: str,
        vehicle_id: str,
        request: CommandRequest,
    ) -> dict:
        """Validate, persist and dispatch a remote vehicle command."""

        normalized_id = self._validate_vehicle_access(
            user_id,
            vehicle_id,
        )
        self._ensure_vehicle_online(normalized_id)

        command = self.command_repository.create_command(
            user_id,
            normalized_id,
            request,
        )

        payload = {
            "command_id": command["command_id"],
            "vehicle_id": normalized_id,
            "operation": request.operation.value.upper(),
        }

        if self.timeout_manager is not None:
            self.timeout_manager.start(
                command["command_id"],
                normalized_id,
            )

        try:
            self.publish_command(normalized_id, payload)
        except MQTTUnavailableError:
            if self.timeout_manager is not None:
                self.timeout_manager.cancel(command["command_id"])

            self.command_repository.update_command_result(
                command["command_id"],
                normalized_id,
                CommandStatus.FAILED,
                datetime.now(UTC),
                "Command could not be dispatched",
            )
            raise

        return command

    def get_commands(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> list[dict]:
        """Retrieve command history after verifying vehicle access."""

        normalized_id = self._validate_vehicle_access(
            user_id,
            vehicle_id,
        )

        return self.command_repository.get_vehicle_commands(
            normalized_id,
            user_id,
        )

    def get_command(
        self,
        user_id: str,
        vehicle_id: str,
        command_id: str,
    ) -> dict | None:
        """Retrieve one command after verifying vehicle access."""

        normalized_id = self._validate_vehicle_access(
            user_id,
            vehicle_id,
        )

        return self.command_repository.get_command(
            normalized_id,
            command_id,
            user_id,
        )
