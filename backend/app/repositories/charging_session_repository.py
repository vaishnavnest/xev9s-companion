
from datetime import UTC, datetime

from backend.app.models.charging_session import (
    create_charging_session_document,
)
from backend.app.schemas.charging_event import ChargingEvent
from backend.app.schemas.charging_session import ChargingSessionStatus
from pymongo import DESCENDING, ReturnDocument
from pymongo.client_session import ClientSession
from pymongo.collection import Collection
from pymongo.errors import DuplicateKeyError


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
            raise ValueError(
                "Charging session already exists"
            ) from exc

        return document

    def get_session(self, session_id: str) -> dict | None:
        """Retrieve a charging session by its identifier."""

        return self.collection.find_one(
            {"session_id": session_id},
            {"_id": 0},
        )

    def get_active_session(
        self,
        vehicle_id: str,
        session: ClientSession | None = None,
    ) -> dict | None:
        """Retrieve the active or paused session for a vehicle."""

        return self.collection.find_one(
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

        return self.collection.find_one_and_update(
            {"session_id": session_id},
            {"$set": update_fields},
            return_document=ReturnDocument.AFTER,
            projection={"_id": 0},
            session=session,
        )

    def get_session_history(
        self,
        vehicle_id: str,
        limit: int = 20,
        offset: int = 0,
    ) -> list[dict]:
        """Retrieve paginated charging history for a vehicle."""

        cursor = (
            self.collection.find(
                {"vehicle_id": vehicle_id},
                {"_id": 0},
            )
            .sort("started_at", DESCENDING)
            .skip(offset)
            .limit(limit)
        )

        return list(cursor)
