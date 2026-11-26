
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    ChargingSessionAlreadyActiveError,
    InvalidChargingTransitionError,
)
from backend.app.schemas.charging_event import (
    ChargingEvent,
    ChargingEventType,
)
from backend.app.schemas.charging_session import ChargingSessionStatus
from backend.app.services.charging_session_lifecycle import (
    ChargingSessionLifecycle,
)


@pytest.fixture
def session_repository():
    return MagicMock()


@pytest.fixture
def lifecycle(session_repository):
    return ChargingSessionLifecycle(session_repository)


@pytest.fixture
def start_event():
    return ChargingEvent(
        event_id="event-001",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.CHARGING_STARTED,
        timestamp=datetime.now(UTC),
        battery_percentage=30,
        charging_power_kw=7.2,
        target_percentage=80,
    )


def test_start_creates_session(
    lifecycle,
    session_repository,
    start_event,
):
    session_repository.get_active_session.return_value = None
    transaction = MagicMock()

    result = lifecycle.start(start_event, transaction)

    assert result["session_id"] == "session-001"
    assert result["status"] == ChargingSessionStatus.ACTIVE.value
    session_repository.create_session.assert_called_once()


def test_start_rejects_existing_active_session(
    lifecycle,
    session_repository,
    start_event,
):
    session_repository.get_active_session.return_value = {
        "session_id": "existing-session",
    }

    with pytest.raises(ChargingSessionAlreadyActiveError):
        lifecycle.start(start_event, MagicMock())

    session_repository.create_session.assert_not_called()


def test_progress_updates_session(
    lifecycle,
    session_repository,
):

    started_at = datetime.now(UTC)

    event = ChargingEvent(
        event_id="event-002",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.CHARGING_PROGRESS,
        timestamp=started_at,
        battery_percentage=45,
        charging_power_kw=7.2,
    )

    active_session = {
        "session_id": "session-001",
        "started_at": started_at,
        "status": ChargingSessionStatus.ACTIVE.value,
        "charging_power_kw": 7.0,
        "average_charging_power_kw": 7.0,
        "peak_charging_power_kw": 7.2,
        "power_sample_count": 1,
    }

    result = lifecycle.update_progress(
        event,
        active_session,
        MagicMock(),
    )

    assert result["status"] == "active"
    session_repository.update_session.assert_called_once()


def test_progress_rejects_missing_power(
    lifecycle,
):
    event = ChargingEvent(
        event_id="event-003",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.CHARGING_PROGRESS,
        timestamp=datetime.now(UTC),
        battery_percentage=45,
    )

    with pytest.raises(InvalidChargingTransitionError):
        lifecycle.update_progress(
            event,
            {"started_at": datetime.now(UTC)},
            MagicMock(),
        )


def test_pause_updates_session(
    lifecycle,
    session_repository,
):
    event = ChargingEvent(
        event_id="event-004",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.PAUSED,
        timestamp=datetime.now(UTC),
    )
    active_session = {
        "status": ChargingSessionStatus.ACTIVE.value,
    }

    result = lifecycle.pause(event, active_session, MagicMock())

    assert result["status"] == "paused"
    session_repository.update_session.assert_called_once()


def test_resume_updates_session(
    lifecycle,
    session_repository,
):
    event = ChargingEvent(
        event_id="event-005",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.RESUMED,
        timestamp=datetime.now(UTC),
    )
    active_session = {
        "status": ChargingSessionStatus.PAUSED.value,
    }

    result = lifecycle.resume(event, active_session, MagicMock())

    assert result["status"] == "active"
    session_repository.update_session.assert_called_once()
