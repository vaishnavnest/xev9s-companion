
from datetime import UTC, datetime

from backend.app.models.charging import (
    create_charging_preferences_document,
)
from backend.app.schemas.charging import ChargingPreferencesUpdate
from pymongo import ReturnDocument
from pymongo.client_session import ClientSession
from pymongo.collection import Collection


class ChargingRepository:
    """Handles MongoDB operations for vehicle charging preferences."""

    def __init__(self, collection: Collection):
        self.collection = collection

    def save_preferences(
        self,
        vehicle_id: str,
        preferences: ChargingPreferencesUpdate,
        session: ClientSession | None = None,
    ) -> dict:
        """Create or update charging preferences for a vehicle."""

        normalized_vehicle_id = vehicle_id.strip()
        document = create_charging_preferences_document(
            normalized_vehicle_id,
            preferences,
        )
        now = datetime.now(UTC)

        result = self.collection.find_one_and_update(
            {"vehicle_id": normalized_vehicle_id},
            {
                "$set": {
                    key: value
                    for key, value in document.items()
                    if key not in {"vehicle_id", "created_at"}
                },
                "$setOnInsert": {
                    "vehicle_id": normalized_vehicle_id,
                    "created_at": now,
                },
            },
            upsert=True,
            return_document=ReturnDocument.AFTER,
            session=session,
        )

        return result

    def get_preferences(self, vehicle_id: str) -> dict | None:
        """Retrieve charging preferences for a vehicle."""

        return self.collection.find_one(
            {"vehicle_id": vehicle_id.strip()},
            {"_id": 0},
        )
