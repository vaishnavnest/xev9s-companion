
from datetime import UTC, datetime

from backend.app.schemas.charging_event import ChargingEvent


def create_charging_event_document(event: ChargingEvent) -> dict:
    """Build a MongoDB document for a processed charging event."""

    document = event.model_dump()
    document["processed_at"] = datetime.now(UTC)

    return document
