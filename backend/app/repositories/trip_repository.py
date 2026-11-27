from datetime import UTC, datetime

from backend.app.core.exceptions import TripAlreadyActiveError
from backend.app.models.trip import create_trip_document
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.schemas.trip import TripStatus
from pymongo import ASCENDING, DESCENDING, ReturnDocument
from pymongo.collection import Collection
from pymongo.errors import DuplicateKeyError

TRIP_SORT_FIELD_MAP = {
    "startedAt": "started_at",
    "endedAt": "ended_at",
    "distanceKm": "distance_km",
    "durationSeconds": "duration_seconds",
}

ALLOWED_TRIP_SORT_FIELDS = frozenset({
    "started_at",
    "ended_at",
    "distance_km",
    "duration_seconds",
    "energy_consumed_kwh",
})


class TripRepository:
    """Handles MongoDB persistence operations for vehicle trips."""

    def __init__(self, collection: Collection) -> None:
        self.collection = collection

    def create_trip(
        self,
        telemetry: TelemetryPayload,
        trip_id: str | None = None,
    ) -> dict:
        """Create a new active trip record for a vehicle."""
        document = create_trip_document(telemetry, trip_id=trip_id)
        try:
            self.collection.insert_one(document)
        except DuplicateKeyError as exc:
            raise TripAlreadyActiveError(
                f"Vehicle {telemetry.vehicle_id} already has an active trip"
            ) from exc
        return document

    def get_active_trip(self, vehicle_id: str) -> dict | None:
        """Retrieve the currently active trip for a vehicle, if any."""
        return self.collection.find_one(
            {
                "vehicle_id": vehicle_id,
                "status": TripStatus.ONGOING.value,
            }
        )

    def get_trip_by_id(self, trip_id: str) -> dict | None:
        """Retrieve a trip document by its unique identifier."""
        return self.collection.find_one({"trip_id": trip_id})

    def append_route_point(
        self,
        trip_id: str,
        point: dict,
        telemetry_timestamp: datetime,
    ) -> bool:
        """Append a route sample to an active trip's route array."""
        now = datetime.now(UTC)
        result = self.collection.update_one(
            {
                "trip_id": trip_id,
                "status": TripStatus.ONGOING.value,
                "last_telemetry_at": {"$lt": telemetry_timestamp},
            },
            {
                "$push": {"route": point},
                "$set": {
                    "last_telemetry_at": telemetry_timestamp,
                    "updated_at": now,
                },
            },
        )
        modified = getattr(result, "modified_count", 0)
        return bool(modified > 0) if isinstance(modified, (int, float)) else True

    def complete_trip(self, trip_id: str, updates: dict) -> dict | None:
        """Finalize an active trip with closing metrics."""
        now = datetime.now(UTC)
        return self.collection.find_one_and_update(
            {"trip_id": trip_id, "status": TripStatus.ONGOING.value},
            {
                "$set": {
                    **updates,
                    "status": TripStatus.COMPLETED.value,
                    "updated_at": now,
                }
            },
            return_document=ReturnDocument.AFTER,
        )

    def list_trips(
        self,
        vehicle_id: str,
        page: int = 1,
        page_size: int = 20,
        sort: str = "-started_at",
        from_time: datetime | None = None,
        to_time: datetime | None = None,
        status: str | None = None,
    ) -> tuple[list[dict], int]:
        """Query paginated trip history for an associated vehicle."""
        query: dict = {"vehicle_id": vehicle_id}
        if status is not None:
            query["status"] = status

        time_filter: dict = {}
        if from_time is not None:
            time_filter["$gte"] = from_time
        if to_time is not None:
            time_filter["$lte"] = to_time
        if time_filter:
            query["started_at"] = time_filter

        sort_direction = DESCENDING if sort.startswith("-") else ASCENDING
        raw_field = sort.lstrip("+-")
        sort_field = TRIP_SORT_FIELD_MAP.get(raw_field, raw_field)
        if sort_field not in ALLOWED_TRIP_SORT_FIELDS:
            sort_field = "started_at"

        total_items = self.collection.count_documents(query)
        cursor = (
            self.collection.find(query, {"route": 0})
            .sort([(sort_field, sort_direction)])
            .skip((page - 1) * page_size)
            .limit(page_size)
        )
        return list(cursor), total_items
