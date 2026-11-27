import math
from datetime import datetime

from backend.app.core.exceptions import (
    TripNotFoundError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.repositories.trip_repository import TripRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.schemas.trip import (
    Pagination,
    Trip,
    TripDetail,
    TripListResponse,
)
from backend.app.services.trip_lifecycle import TripLifecycleManager


class TripService:
    """Coordinates trip lifecycle management and API data retrieval."""

    def __init__(
        self,
        trip_repository: TripRepository,
        vehicle_repository: VehicleRepository,
        lifecycle_manager: TripLifecycleManager,
    ) -> None:
        self.trip_repository = trip_repository
        self.vehicle_repository = vehicle_repository
        self.lifecycle = lifecycle_manager

    def process_telemetry(self, telemetry: TelemetryPayload) -> dict | None:
        """Process incoming vehicle telemetry for trip tracking."""
        return self.lifecycle.process_telemetry(telemetry)

    def _validate_vehicle_access(self, user_id: str, vehicle_id: str) -> str:
        """Validate vehicle identity and user association."""
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

    def list_trips(
        self,
        user_id: str,
        vehicle_id: str,
        page: int = 1,
        page_size: int = 20,
        sort: str = "-started_at",
        from_time: datetime | None = None,
        to_time: datetime | None = None,
        status: str | None = None,
    ) -> TripListResponse:
        """Retrieve paginated trips for an associated vehicle."""
        normalized_id = self._validate_vehicle_access(user_id, vehicle_id)

        if from_time is not None and to_time is not None and from_time > to_time:
            raise ValueError("Start filter timestamp cannot be after end timestamp")

        trips_data, total_items = self.trip_repository.list_trips(
            vehicle_id=normalized_id,
            page=page,
            page_size=page_size,
            sort=sort,
            from_time=from_time,
            to_time=to_time,
            status=status,
        )

        total_pages = math.ceil(total_items / page_size) if total_items > 0 else 0

        trips = [Trip.model_validate(item) for item in trips_data]
        pagination = Pagination(
            page=page,
            page_size=page_size,
            total_items=total_items,
            total_pages=total_pages,
        )

        return TripListResponse(trips=trips, pagination=pagination)

    def get_trip_detail(
        self,
        user_id: str,
        vehicle_id: str,
        trip_id: str,
    ) -> TripDetail:
        """Retrieve full details of a specific trip including GPS route."""
        normalized_id = self._validate_vehicle_access(user_id, vehicle_id)

        normalized_trip_id = trip_id.strip()
        if not normalized_trip_id:
            raise ValueError("Trip identifier cannot be empty")

        trip_data = self.trip_repository.get_trip_by_id(normalized_trip_id)
        if trip_data is None or trip_data.get("vehicle_id") != normalized_id:
            raise TripNotFoundError(
                f"Trip {normalized_trip_id} not found for vehicle {normalized_id}"
            )

        return TripDetail.model_validate(trip_data)
