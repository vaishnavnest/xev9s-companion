import logging
from datetime import datetime

from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.repositories.telemetry_repository import (
    TelemetryRepository,
)
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.schemas.telemetry import TelemetryPayload

logger = logging.getLogger(__name__)


class TelemetryService:
    """Implements telemetry ingestion and retrieval operations."""

    def __init__(
        self,
        telemetry_repository: TelemetryRepository,
        vehicle_repository: VehicleRepository,
        trip_service: object | None = None,
    ):
        self.telemetry_repository = telemetry_repository
        self.vehicle_repository = vehicle_repository
        self.trip_service = trip_service

    def ingest_telemetry(self, telemetry: TelemetryPayload) -> dict:
        """Validate vehicle status and persist incoming telemetry."""

        vehicle_id = telemetry.vehicle_id.strip()

        if not vehicle_id:
            raise ValueError("Vehicle identifier cannot be empty")

        vehicle = self.vehicle_repository.get_active_vehicle_by_id(vehicle_id)

        if vehicle is None:
            raise VehicleNotActiveError("Vehicle is not registered or active")

        normalized_telemetry = telemetry.model_copy(update={"vehicle_id": vehicle_id})

        saved = self.telemetry_repository.save_telemetry(normalized_telemetry)

        if self.trip_service is not None and hasattr(
            self.trip_service, "process_telemetry"
        ):
            try:
                self.trip_service.process_telemetry(normalized_telemetry)
            except Exception:
                logger.exception(
                    "Trip processing failed for vehicle %s",
                    vehicle_id,
                )

        return saved

    def get_latest_telemetry(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> dict | None:
        """Retrieve latest telemetry after verifying vehicle ownership."""

        normalized_vehicle_id = vehicle_id.strip()

        if not normalized_vehicle_id:
            raise ValueError("Vehicle identifier cannot be empty")

        if not self.vehicle_repository.is_vehicle_associated_with_user(
            user_id,
            normalized_vehicle_id,
        ):
            raise VehicleAccessDeniedError("You do not have access to this vehicle")

        return self.telemetry_repository.get_latest_telemetry(normalized_vehicle_id)

    def get_telemetry_history(
        self,
        user_id: str,
        vehicle_id: str,
        start_time: datetime,
        end_time: datetime,
        limit: int = 100,
    ) -> list[dict]:
        """Retrieve historical telemetry after verifying ownership."""

        normalized_vehicle_id = vehicle_id.strip()

        if not normalized_vehicle_id:
            raise ValueError("Vehicle identifier cannot be empty")

        if start_time > end_time:
            raise ValueError("Start time must be before end time")

        if not 1 <= limit <= 1000:
            raise ValueError("Limit must be between 1 and 1000")

        if not self.vehicle_repository.is_vehicle_associated_with_user(
            user_id,
            normalized_vehicle_id,
        ):
            raise VehicleAccessDeniedError("You do not have access to this vehicle")

        return self.telemetry_repository.get_telemetry_history(
            normalized_vehicle_id,
            start_time,
            end_time,
            limit,
        )
