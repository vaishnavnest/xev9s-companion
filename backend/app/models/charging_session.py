
from datetime import UTC, datetime
from uuid import uuid4

from backend.app.schemas.charging_event import ChargingEvent
from backend.app.schemas.charging_session import ChargingSessionStatus


def create_charging_session_document(
    event: ChargingEvent,
    target_percentage: float,
) -> dict:
    """Build a MongoDB document for a newly started charging session."""

    now = datetime.now(UTC)

    return {
        "session_id": event.session_id or str(uuid4()),
        "vehicle_id": event.vehicle_id,
        "started_at": event.timestamp,
        "ended_at": None,
        "starting_battery_percentage": event.battery_percentage,
        "ending_battery_percentage": None,
        "target_percentage": target_percentage,
        "final_target_percentage": target_percentage,
        "charging_power_kw": event.charging_power_kw or 0.0,
        "average_charging_power_kw": None,
        "peak_charging_power_kw": event.charging_power_kw or 0.0,
        "duration_seconds": 0.0,
        "status": ChargingSessionStatus.ACTIVE.value,
        "interruption_reason": None,
        "created_at": now,
        "updated_at": now,
    }
