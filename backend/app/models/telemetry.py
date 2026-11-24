
from datetime import UTC, datetime

from backend.app.schemas.telemetry import TelemetryPayload


def create_telemetry_document(
    telemetry: TelemetryPayload,
) -> dict:
    """Build a MongoDB document from validated vehicle telemetry."""

    document = telemetry.model_dump()
    document["received_at"] = datetime.now(UTC)

    return document
