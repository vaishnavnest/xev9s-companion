
from datetime import UTC, datetime

from backend.app.schemas.charging import ChargingPreferencesUpdate


def create_charging_preferences_document(
    vehicle_id: str,
    preferences: ChargingPreferencesUpdate,
) -> dict:
    """Build a MongoDB document for vehicle charging preferences."""

    now = datetime.now(UTC)

    document = preferences.model_dump(mode="json")
    document.update(
        {
            "vehicle_id": vehicle_id.strip(),
            "created_at": now,
            "updated_at": now,
        }
    )

    return document
