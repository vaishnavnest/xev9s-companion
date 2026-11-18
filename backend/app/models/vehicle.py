
from datetime import UTC, datetime

from bson import ObjectId


def create_vehicle_document(
    vehicle_id: str,
    model: str,
    pairing_code_hash: str,
    pairing_expires_at: datetime,
) -> dict:
    """Build a trusted vehicle registry document."""

    now = datetime.now(UTC)

    return {
        "vehicle_id": vehicle_id.strip(),
        "model": model.strip(),
        "pairing_code_hash": pairing_code_hash,
        "pairing_expires_at": pairing_expires_at,
        "is_active": True,
        "created_at": now,
        "updated_at": now,
    }


def create_user_vehicle_document(
    user_id: ObjectId,
    vehicle_id: str,
) -> dict:
    """Build a vehicle association document for a user."""

    return {
        "user_id": user_id,
        "vehicle_id": vehicle_id,
        "association_status": "active",
        "associated_at": datetime.now(UTC),
    }
