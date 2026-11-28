from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    ChargingSessionAlreadyActiveError,
    InvalidChargingTransitionError,
)
from backend.app.models.charging_session import create_charging_session_document
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.schemas.charging_event import ChargingEvent, ChargingEventType
from backend.app.schemas.charging_session import (
    ChargingSessionResponse,
    ChargingSessionStatus,
)
from backend.app.services.charging_session_lifecycle import ChargingSessionLifecycle
from backend.app.services.charging_session_transitions import (
    ChargingSessionTransitions,
)


def test_first_progress_handles_null_and_missing_average():
    repo = MagicMock()
    lifecycle = ChargingSessionLifecycle(repo)
    started_at = datetime.now(UTC)
    start_event = ChargingEvent(
        event_id="e1",
        vehicle_id="XEV-1",
        session_id="s1",
        event_type=ChargingEventType.CHARGING_STARTED,
        timestamp=started_at,
        battery_percentage=30.0,
        charging_power_kw=7.2,
    )
    active_session = create_charging_session_document(start_event, 80.0)
    assert active_session["average_charging_power_kw"] is None

    progress = ChargingEvent(
        event_id="e2",
        vehicle_id="XEV-1",
        session_id="s1",
        event_type=ChargingEventType.CHARGING_PROGRESS,
        timestamp=started_at + timedelta(seconds=30),
        battery_percentage=35.0,
        charging_power_kw=6.0,
    )
    lifecycle.update_progress(progress, active_session, MagicMock())
    updates = repo.update_session.call_args[0][1]
    assert updates["average_charging_power_kw"] == 6.0
    assert updates["power_sample_count"] == 1
    assert updates["peak_charging_power_kw"] == 7.2


def test_multiple_progress_samples_and_zero_power():
    repo = MagicMock()
    lifecycle = ChargingSessionLifecycle(repo)
    started_at = datetime.now(UTC)
    active = {
        "session_id": "s1",
        "started_at": started_at,
        "status": ChargingSessionStatus.ACTIVE.value,
        "average_charging_power_kw": 6.0,
        "peak_charging_power_kw": 6.0,
        "power_sample_count": 1,
    }
    p2 = ChargingEvent(
        event_id="e3",
        vehicle_id="XEV-1",
        session_id="s1",
        event_type=ChargingEventType.CHARGING_PROGRESS,
        timestamp=started_at + timedelta(seconds=60),
        battery_percentage=40.0,
        charging_power_kw=0.0,
    )
    lifecycle.update_progress(p2, active, MagicMock())
    updates = repo.update_session.call_args[0][1]
    assert updates["average_charging_power_kw"] == 3.0
    assert updates["power_sample_count"] == 2


def test_progress_rejects_invalid_negative_power():
    lifecycle = ChargingSessionLifecycle(MagicMock())
    event = SimpleNamespace(
        battery_percentage=50.0,
        charging_power_kw=-1.0,
        timestamp=datetime.now(UTC),
    )
    with pytest.raises(InvalidChargingTransitionError):
        lifecycle.update_progress(event, {"started_at": datetime.now(UTC)}, MagicMock())


def test_naive_started_at_normalized_in_lifecycle_and_transitions():
    repo = MagicMock()
    lifecycle = ChargingSessionLifecycle(repo)
    transitions = ChargingSessionTransitions(repo)
    naive_start = datetime(2026, 11, 27, 8, 0, 0)
    aware_event_time = datetime(2026, 11, 27, 8, 5, 0, tzinfo=UTC)

    active = {
        "session_id": "s1",
        "started_at": naive_start,
        "status": ChargingSessionStatus.ACTIVE.value,
        "average_charging_power_kw": None,
        "peak_charging_power_kw": None,
    }
    progress = ChargingEvent(
        event_id="e4",
        vehicle_id="XEV-1",
        session_id="s1",
        event_type=ChargingEventType.CHARGING_PROGRESS,
        timestamp=aware_event_time,
        battery_percentage=55.0,
        charging_power_kw=7.2,
    )
    lifecycle.update_progress(progress, active, MagicMock())
    assert repo.update_session.call_args[0][1]["duration_seconds"] == 300.0

    close_event = ChargingEvent(
        event_id="e5",
        vehicle_id="XEV-1",
        session_id="s1",
        event_type=ChargingEventType.COMPLETED,
        timestamp=aware_event_time,
        battery_percentage=80.0,
    )
    transitions.close(close_event, active, ChargingSessionStatus.COMPLETED, MagicMock())
    assert repo.update_session.call_args[0][1]["duration_seconds"] == 300.0


def test_repository_normalizes_legacy_naive_session_for_api_schema():
    collection = MagicMock()
    collection.find_one.return_value = {
        "session_id": "s1",
        "vehicle_id": "XEV-1",
        "started_at": datetime(2026, 11, 27, 8, 0, 0),
        "ended_at": datetime(2026, 11, 27, 8, 10, 0),
        "starting_battery_percentage": 40.0,
        "ending_battery_percentage": 80.0,
        "target_percentage": 80.0,
        "charging_power_kw": 0.0,
        "duration_seconds": 600.0,
        "status": "completed",
    }
    repo = ChargingSessionRepository(collection)
    doc = repo.get_session("s1")
    validated = ChargingSessionResponse.model_validate(doc)
    assert validated.started_at.tzinfo == UTC
    assert validated.ended_at is not None and validated.ended_at.tzinfo == UTC


def test_concurrent_start_duplicate_index_maps_to_already_active():
    repo = MagicMock()
    repo.get_active_session.side_effect = [None, {"session_id": "existing"}]
    repo.create_session.side_effect = ValueError("Charging session already exists")
    lifecycle = ChargingSessionLifecycle(repo)
    event = ChargingEvent(
        event_id="e6",
        vehicle_id="XEV-1",
        session_id="s2",
        event_type=ChargingEventType.CHARGING_STARTED,
        timestamp=datetime.now(UTC),
        battery_percentage=30.0,
        charging_power_kw=7.2,
    )
    with pytest.raises(ChargingSessionAlreadyActiveError):
        lifecycle.start(event, MagicMock())
