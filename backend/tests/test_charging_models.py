
from datetime import UTC, datetime
from uuid import UUID

import pytest
from backend.app.models.charging import (
    create_charging_preferences_document,
)
from backend.app.models.charging_event import (
    create_charging_event_document,
)
from backend.app.models.charging_session import (
    create_charging_session_document,
)
from backend.app.schemas.charging import ChargingPreferencesUpdate
from backend.app.schemas.charging_event import ChargingEvent
from backend.app.schemas.charging_session import ChargingSessionStatus


def test_create_charging_preferences_document():
    preferences = ChargingPreferencesUpdate.model_construct()

    result = create_charging_preferences_document(
        " vehicle-123 ",
        preferences,
    )

    assert result["vehicle_id"] == "vehicle-123"
    assert result["created_at"].tzinfo == UTC
    assert result["updated_at"].tzinfo == UTC

    expected = preferences.model_dump(mode="json")
    for key, value in expected.items():
        assert result[key] == value

    assert result["created_at"] == result["updated_at"]


@pytest.mark.parametrize(
    ("session_id", "charging_power"),
    [
        (None, None),
        ("session-123", 7.2),
    ],
)
def test_create_charging_session_document(session_id, charging_power):
    timestamp = datetime.now(UTC)
    event = ChargingEvent.model_construct(
        session_id=session_id,
        vehicle_id="vehicle-123",
        timestamp=timestamp,
        battery_percentage=35.0,
        charging_power_kw=charging_power,
    )

    result = create_charging_session_document(event, 80.0)

    if session_id is None:
        UUID(result["session_id"])
    else:
        assert result["session_id"] == session_id

    assert result["vehicle_id"] == "vehicle-123"
    assert result["started_at"] == timestamp
    assert result["starting_battery_percentage"] == 35.0
    assert result["target_percentage"] == 80.0
    assert result["final_target_percentage"] == 80.0
    assert result["charging_power_kw"] == (charging_power or 0.0)
    assert result["peak_charging_power_kw"] == (charging_power or 0.0)
    assert result["status"] == ChargingSessionStatus.ACTIVE.value
    assert result["ended_at"] is None
    assert result["ending_battery_percentage"] is None
    assert result["average_charging_power_kw"] is None
    assert result["duration_seconds"] == 0.0
    assert result["interruption_reason"] is None
    assert result["created_at"].tzinfo == UTC
    assert result["updated_at"].tzinfo == UTC


def test_create_charging_event_document():
    event = ChargingEvent.model_construct(
        event_id="event-123",
        session_id="session-123",
        vehicle_id="vehicle-123",
        timestamp=datetime.now(UTC),
        battery_percentage=50.0,
        charging_power_kw=7.2,
    )

    result = create_charging_event_document(event)

    for key, value in event.model_dump().items():
        assert result[key] == value

    assert result["processed_at"].tzinfo == UTC
    assert result["processed_at"] <= datetime.now(UTC)
