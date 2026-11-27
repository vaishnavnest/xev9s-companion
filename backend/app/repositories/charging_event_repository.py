
from backend.app.models.charging_event import (
    create_charging_event_document,
)
from backend.app.schemas.charging_event import ChargingEvent
from pymongo import DESCENDING
from pymongo.client_session import ClientSession
from pymongo.collection import Collection


class ChargingEventRepository:
    """Handles MongoDB operations for charging lifecycle events."""

    def __init__(self, collection: Collection):
        self.collection = collection

    def save_event(
        self,
        event: ChargingEvent,
        session: ClientSession | None = None,
    ) -> None:
        """Persist an event within an optional transaction."""

        document = create_charging_event_document(event)
        self.collection.insert_one(document, session=session)

    def get_event(self, event_id: str) -> dict | None:
        """Retrieve an event by its identifier."""

        return self.collection.find_one(
            {"event_id": event_id},
            {"_id": 0},
        )

    def get_vehicle_events(
        self,
        vehicle_id: str,
        limit: int = 100,
    ) -> list[dict]:
        """Retrieve recent events for a vehicle."""

        cursor = (
            self.collection.find(
                {"vehicle_id": vehicle_id},
                {"_id": 0},
            )
            .sort("timestamp", DESCENDING)
            .limit(limit)
        )

        return list(cursor)
