
from datetime import UTC, datetime, time

import pytest
from backend.app.schemas.charging import (
    ChargingPreferencesUpdate,
    Weekday,
)
from backend.app.schemas.charging_event import (
    ChargingEvent,
    ChargingEventType,
)
from backend.app.schemas.charging_session import (
    ChargingSessionResponse,
    ChargingSessionStatus,
)
from pydantic import ValidationError


def valid_preferences(**overrides):
    data = {
        "target_percentage": 80,
        "timezone": "Asia/Kolkata",
    }
    return ChargingPreferencesUpdate.model_validate(data | overrides)


@pytest.mark.parametrize(
    "timezone",
    ["Invalid/Timezone", "   "],
)
def test_invalid_timezone(timezone):
    with pytest.raises(ValidationError):
        valid_preferences(timezone=timezone)


def test_duplicate_scheduled_days():
    with pytest.raises(ValidationError, match="Scheduled days must be unique"):
        valid_preferences(
            scheduled_days=[Weekday.MONDAY, Weekday.MONDAY],
        )


@pytest.mark.parametrize(
    ("overrides", "message"),
    [
        (
            {
                "scheduled_end_time": time(6, 0),
                "scheduled_days": [Weekday.MONDAY],
            },
            "Scheduled start time is required",
        ),
        (
            {
                "scheduled_start_time": time(22, 0),
                "scheduled_days": [Weekday.MONDAY],
            },
            "Scheduled end time is required",
        ),
        (
            {
                "scheduled_start_time": time(22, 0),
                "scheduled_end_time": time(22, 0),
                "scheduled_days": [Weekday.MONDAY],
            },
            "Schedule start and end times must differ",
        ),
        (
            {
                "scheduled_start_time": time(22, 0),
                "scheduled_end_time": time(6, 0),
            },
            "Select at least one scheduled day",
        ),
    ],
)
def test_invalid_enabled_schedule(overrides, message):
    with pytest.raises(ValidationError, match=message):
        valid_preferences(schedule_enabled=True, **overrides)


def valid_event(**overrides):
    data = {
        "event_id": "event-123",
        "vehicle_id": "vehicle-123",
        "event_type": ChargingEventType.CONNECTED,
        "timestamp": datetime.now(UTC),
    }
    return ChargingEvent.model_validate(data | overrides)


@pytest.mark.parametrize(
    "field",
    ["event_id", "vehicle_id", "session_id"],
)
def test_blank_event_identifiers(field):
    with pytest.raises(ValidationError, match="Identifier cannot be empty"):
        valid_event(**{field: "   "})


def test_optional_session_id_can_be_none():
    event = valid_event(session_id=None)
    assert event.session_id is None


def test_event_requires_timezone_aware_timestamp():
    with pytest.raises(ValidationError, match="must include a timezone"):
        valid_event(timestamp=datetime(2026, 1, 1))


def test_blank_interruption_reason_becomes_none():
    event = valid_event(interruption_reason="   ")
    assert event.interruption_reason is None


def test_none_interruption_reason_is_allowed():
    event = valid_event(interruption_reason=None)
    assert event.interruption_reason is None


def test_zero_charging_power_is_allowed():
    event = valid_event(charging_power_kw=0)
    assert event.charging_power_kw == 0


def test_session_with_no_end_timestamp():
    session = ChargingSessionResponse(
        session_id="session-123",
        vehicle_id="vehicle-123",
        started_at=datetime.now(UTC),
        ended_at=None,
        starting_battery_percentage=30,
        target_percentage=80,
        charging_power_kw=7.2,
        duration_seconds=0,
        status=ChargingSessionStatus.ACTIVE,
    )

    assert session.ended_at is None

def test_session_rejects_naive_started_at():
    with pytest.raises(
        ValidationError,
        match="Session timestamps must include a timezone",
    ):
        ChargingSessionResponse(
            session_id="session-123",
            vehicle_id="vehicle-123",
            started_at=datetime(2026, 1, 1),
            starting_battery_percentage=30,
            target_percentage=80,
            charging_power_kw=7.2,
            duration_seconds=0,
            status=ChargingSessionStatus.ACTIVE,
        )
