from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import InvalidChargingTransitionError
from backend.app.schemas.charging_session import ChargingSessionStatus
from backend.app.services.charging_session_transitions import (
    ChargingSessionTransitions,
)


@pytest.fixture
def transitions():
    return ChargingSessionTransitions(MagicMock())


def test_require_status_rejects_invalid_state(transitions):
    with pytest.raises(
        InvalidChargingTransitionError,
        match="Expected session status: active",
    ):
        transitions.require_status(
            {"status": "paused"},
            ChargingSessionStatus.ACTIVE,
        )


def test_close_rejects_timestamp_before_session_start(transitions):
    started_at = datetime.now(UTC)
    event = MagicMock()
    event.timestamp = started_at - timedelta(seconds=1)

    with pytest.raises(
        InvalidChargingTransitionError,
        match="Event timestamp cannot precede session start",
    ):
        transitions.close(
            event,
            {"started_at": started_at},
            ChargingSessionStatus.COMPLETED,
            MagicMock(),
        )


def test_close_updates_session_and_returns_status(transitions):
    started_at = datetime.now(UTC) - timedelta(minutes=5)
    event = MagicMock()
    event.session_id = "session-001"
    event.timestamp = datetime.now(UTC)
    event.battery_percentage = 85
    event.interruption_reason = None
    transaction = MagicMock()

    result = transitions.close(
        event,
        {"started_at": started_at},
        ChargingSessionStatus.COMPLETED,
        transaction,
    )

    assert result == {
        "session_id": "session-001",
        "status": "completed",
    }

    transitions.session_repository.update_session.assert_called_once()
    args, kwargs = (
        transitions.session_repository.update_session.call_args
    )
    assert args[0] == "session-001"
    assert args[1]["status"] == "completed"
    assert args[1]["ending_battery_percentage"] == 85
    assert args[1]["duration_seconds"] > 0
    assert kwargs["session"] is transaction