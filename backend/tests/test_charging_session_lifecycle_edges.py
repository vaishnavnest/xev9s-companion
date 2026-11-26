from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import InvalidChargingTransitionError
from backend.app.schemas.charging_event import ChargingEventType
from backend.app.schemas.charging_session import ChargingSessionStatus
from backend.app.services.charging_session_lifecycle import (
    ChargingSessionLifecycle,
)


@pytest.fixture
def lifecycle():
    repository = MagicMock()
    service = ChargingSessionLifecycle(repository)
    service.transitions = MagicMock()
    return service


def test_start_rejects_missing_session_id(lifecycle):
    event = SimpleNamespace(
        session_id=None,
        battery_percentage=50,
    )

    with pytest.raises(InvalidChargingTransitionError):
        lifecycle.start(event, MagicMock())


def test_progress_rejects_timestamp_before_session_start(lifecycle):
    started_at = datetime.now(UTC)
    event = SimpleNamespace(
        timestamp=started_at - timedelta(seconds=1),
        battery_percentage=50,
        charging_power_kw=7.2,
    )
    active_session = {"started_at": started_at}

    with pytest.raises(InvalidChargingTransitionError):
        lifecycle.update_progress(event, active_session, MagicMock())


def test_finish_completed_session(lifecycle):
    event = SimpleNamespace(
        event_type=ChargingEventType.COMPLETED,
        battery_percentage=100,
    )
    active_session = {"session_id": "session-001"}
    transaction = MagicMock()
    lifecycle.transitions.close.return_value = {"status": "completed"}

    result = lifecycle.finish(event, active_session, transaction)

    assert result == {"status": "completed"}
    lifecycle.transitions.close.assert_called_once_with(
        event,
        active_session,
        ChargingSessionStatus.COMPLETED,
        transaction,
    )


def test_finish_rejects_missing_battery_percentage(lifecycle):
    event = SimpleNamespace(
        event_type=ChargingEventType.INTERRUPTED,
        battery_percentage=None,
    )

    with pytest.raises(InvalidChargingTransitionError):
        lifecycle.finish(event, {}, MagicMock())


def test_disconnect_closes_session_as_interrupted(lifecycle):
    event = SimpleNamespace()
    active_session = {"session_id": "session-001"}
    transaction = MagicMock()
    lifecycle.transitions.close.return_value = {"status": "interrupted"}

    result = lifecycle.disconnect(event, active_session, transaction)

    assert result == {"status": "interrupted"}
    lifecycle.transitions.close.assert_called_once_with(
        event,
        active_session,
        ChargingSessionStatus.INTERRUPTED,
        transaction,
    )