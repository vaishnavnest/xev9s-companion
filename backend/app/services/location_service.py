from datetime import UTC, datetime
from typing import Literal

from backend.app.core.command_config import (
    VEHICLE_ONLINE_TIMEOUT_SECONDS,
)
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.repositories.telemetry_repository import TelemetryRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.schemas.location import VehicleLocationResponse


class LocationService:
    """Orchestrates vehicle location retrieval and connectivity analysis."""

    def __init__(
        self,
        vehicle_repository: VehicleRepository,
        telemetry_repository: TelemetryRepository,
        online_timeout_seconds: int = VEHICLE_ONLINE_TIMEOUT_SECONDS,
    ) -> None:
        self.vehicle_repository = vehicle_repository
        self.telemetry_repository = telemetry_repository
        self.online_timeout_seconds = online_timeout_seconds

    @staticmethod
    def _normalize_datetime(timestamp: object) -> datetime | None:
        """Ensure datetimes are timezone-aware in UTC."""
        if not isinstance(timestamp, datetime):
            return None
        if timestamp.tzinfo is None or timestamp.utcoffset() is None:
            return timestamp.replace(tzinfo=UTC)
        return timestamp.astimezone(UTC)

    def _validate_access(self, user_id: str, vehicle_id: str) -> str:
        """Validate vehicle identity, active status, and user ownership."""

        normalized_id = vehicle_id.strip()
        if not normalized_id:
            raise ValueError("Vehicle identifier cannot be empty")

        vehicle = self.vehicle_repository.get_vehicle_by_id(normalized_id)
        if vehicle is None or not vehicle.get("is_active", False):
            raise VehicleNotActiveError("Vehicle is not registered or active")

        if not self.vehicle_repository.is_vehicle_associated_with_user(
            user_id, normalized_id
        ):
            raise VehicleAccessDeniedError("You do not have access to this vehicle")

        return normalized_id

    def get_vehicle_location(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> VehicleLocationResponse:
        """Retrieve latest valid location and evaluate freshness."""

        normalized_id = self._validate_access(user_id, vehicle_id)

        # 1. Evaluate connectivity from the most recent telemetry record
        latest_telemetry = self.telemetry_repository.get_latest_telemetry(normalized_id)
        connectivity_status: Literal["online", "offline"] = "offline"
        operating_state = None

        if latest_telemetry is not None:
            operating_state = latest_telemetry.get("operating_state")
            tel_timestamp = self._normalize_datetime(latest_telemetry.get("timestamp"))
            if tel_timestamp is not None:
                now = datetime.now(UTC)
                age = (now - tel_timestamp).total_seconds()
                if 0 <= age <= self.online_timeout_seconds:
                    connectivity_status = "online"

        # 2. Retrieve latest valid coordinates
        latest_loc = self.telemetry_repository.get_latest_valid_location(normalized_id)

        if latest_loc is None:
            return VehicleLocationResponse(
                vehicle_id=normalized_id,
                latitude=None,
                longitude=None,
                timestamp=None,
                is_current=False,
                connectivity_status=connectivity_status,
                operating_state=operating_state,
            )

        latitude = latest_loc.get("latitude")
        longitude = latest_loc.get("longitude")
        loc_timestamp = self._normalize_datetime(latest_loc.get("timestamp"))

        if loc_timestamp is not None:
            now = datetime.now(UTC)
            loc_age = (now - loc_timestamp).total_seconds()
            is_current = (
                connectivity_status == "online"
                and 0 <= loc_age <= self.online_timeout_seconds
            )
        else:
            is_current = False

        return VehicleLocationResponse(
            vehicle_id=normalized_id,
            latitude=latitude,
            longitude=longitude,
            timestamp=loc_timestamp,
            is_current=is_current,
            connectivity_status=connectivity_status,
            operating_state=operating_state,
        )
