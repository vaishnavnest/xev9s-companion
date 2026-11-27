from datetime import UTC, datetime

from backend.app.models.charging_session import (
    create_charging_session_document,
)
from backend.app.schemas.charging_event import ChargingEvent
from backend.app.schemas.charging_session import ChargingSessionStatus
from pymongo import ASCENDING, DESCENDING, ReturnDocument
from pymongo.client_session import ClientSession
from pymongo.collection import Collection
from pymongo.errors import DuplicateKeyError

CHARGING_SESSION_SORT_FIELD_MAP = {
    "startedAt": "started_at",
    "endedAt": "ended_at",
    "durationSeconds": "duration_seconds",
    "chargingPowerKw": "charging_power_kw",
}

ALLOWED_CHARGING_SESSION_SORT_FIELDS = frozenset(
    {
        "started_at",
        "ended_at",
        "duration_seconds",
        "charging_power_kw",
        "starting_battery_percentage",
        "ending_battery_percentage",
    }
)


def _normalize_session_timestamps(document: dict | None) -> dict | None:
    """Normalize naive UTC datetimes in stored charging session documents."""
    if document is None:
        return None
    for field in ("started_at", "ended_at", "created_at", "updated_at"):
        value = document.get(field)
        if isinstance(value, datetime) and (
            value.tzinfo is None or value.utcoffset() is None
        ):
            document[field] = value.replace(tzinfo=UTC)
    return document


class ChargingSessionRepository:
    """Handles MongoDB operations for charging sessions."""

    def __init__(self, collection: Collection):
        self.collection = collection

    def create_session(
        self,
        event: ChargingEvent,
        target_percentage: float,
        session: ClientSession | None = None,
    ) -> dict:
        """Create a new charging session."""

        document = create_charging_session_document(
            event,
            target_percentage,
        )

        try:
            self.collection.insert_one(document, session=session)
        except DuplicateKeyError as exc:
            raise ValueError("Charging session already exists") from exc

        return document

    def get_session(self, session_id: str) -> dict | None:
        """Retrieve a charging session by its identifier."""

        doc = self.collection.find_one(
            {"session_id": session_id},
            {"_id": 0},
        )
        return _normalize_session_timestamps(doc)

    def get_active_session(
        self,
        vehicle_id: str,
        session: ClientSession | None = None,
    ) -> dict | None:
        """Retrieve the active or paused session for a vehicle."""

        doc = self.collection.find_one(
            {
                "vehicle_id": vehicle_id,
                "status": {
                    "$in": [
                        ChargingSessionStatus.ACTIVE.value,
                        ChargingSessionStatus.PAUSED.value,
                    ]
                },
            },
            {"_id": 0},
            session=session,
        )
        return _normalize_session_timestamps(doc)

    def update_session(
        self,
        session_id: str,
        updates: dict,
        session: ClientSession | None = None,
    ) -> dict | None:
        """Update a charging session."""

        update_fields = {
            **updates,
            "updated_at": datetime.now(UTC),
        }

        doc = self.collection.find_one_and_update(
            {"session_id": session_id},
            {"$set": update_fields},
            return_document=ReturnDocument.AFTER,
            projection={"_id": 0},
            session=session,
        )
        return _normalize_session_timestamps(doc)

    def get_session_history(
        self,
        vehicle_id: str,
        limit: int = 20,
        offset: int = 0,
        status: ChargingSessionStatus | str | None = None,
        from_time: datetime | None = None,
        to_time: datetime | None = None,
        sort: str = "-started_at",
    ) -> tuple[list[dict], int]:
        """Retrieve filtered, paginated charging history for a vehicle."""

        query: dict = {"vehicle_id": vehicle_id}
        if status is not None:
            query["status"] = (
                status.value if isinstance(status, ChargingSessionStatus) else status
            )

        time_filter: dict = {}
        if from_time is not None:
            time_filter["$gte"] = from_time
        if to_time is not None:
            time_filter["$lte"] = to_time
        if time_filter:
            query["started_at"] = time_filter

        sort_direction = DESCENDING if sort.startswith("-") else ASCENDING
        raw_field = sort.lstrip("+-")
        sort_field = CHARGING_SESSION_SORT_FIELD_MAP.get(raw_field, raw_field)
        if sort_field not in ALLOWED_CHARGING_SESSION_SORT_FIELDS:
            sort_field = "started_at"

        total_items = self.collection.count_documents(query)
        cursor = (
            self.collection.find(
                query,
                {"_id": 0},
            )
            .sort(sort_field, sort_direction)
            .skip(offset)
            .limit(limit)
        )

        sessions = [_normalize_session_timestamps(doc) for doc in cursor]
        return [doc for doc in sessions if doc is not None], total_items
