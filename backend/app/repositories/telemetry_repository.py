from datetime import datetime

from backend.app.models.telemetry import create_telemetry_document
from backend.app.schemas.telemetry import TelemetryPayload
from pymongo import DESCENDING
from pymongo.collection import Collection


class TelemetryRepository:
    """Handles MongoDB operations for vehicle telemetry."""

    def __init__(self, collection: Collection):
        self.collection = collection

    def save_telemetry(self, telemetry: TelemetryPayload) -> dict:
        """Persist a validated telemetry record."""

        document = create_telemetry_document(telemetry)
        result = self.collection.insert_one(document)
        document["_id"] = result.inserted_id

        return document

    def get_latest_telemetry(self, vehicle_id: str) -> dict | None:
        """Retrieve the latest telemetry record for a vehicle."""

        return self.collection.find_one(
            {"vehicle_id": vehicle_id},
            sort=[("timestamp", DESCENDING)],
        )

    def get_telemetry_history(
        self,
        vehicle_id: str,
        start_time: datetime,
        end_time: datetime,
        limit: int = 100,
    ) -> list[dict]:
        """Retrieve telemetry records within a time range."""

        cursor = (
            self.collection.find(
                {
                    "vehicle_id": vehicle_id,
                    "timestamp": {
                        "$gte": start_time,
                        "$lte": end_time,
                    },
                }
            )
            .sort("timestamp", DESCENDING)
            .limit(limit)
        )

        return list(cursor)

    def get_latest_valid_location(self, vehicle_id: str) -> dict | None:
        """Retrieve the latest telemetry record with valid GPS coordinates."""

        return self.collection.find_one(
            {
                "vehicle_id": vehicle_id,
                "latitude": {"$exists": True, "$ne": None},
                "longitude": {"$exists": True, "$ne": None},
            },
            sort=[("timestamp", DESCENDING)],
        )
