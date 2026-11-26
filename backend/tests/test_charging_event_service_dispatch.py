from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import ChargingSessionNotFoundError
from backend.app.schemas.charging_event import ChargingEvent, ChargingEventType
from backend.app.services.charging_event_service import ChargingEventService


@pytest.fixture
def dependencies():
    event_repo = MagicMock()
    session_repo = MagicMock()
    mongo_client = MagicMock()
    mongo_session = MagicMock()

    mongo_client.start_session.return_value.__enter__.return_value = mongo_session

    service = ChargingEventService(event_repo, session_repo, mongo_client)
    return service, session_repo, mongo_session


@pytest.mark.parametrize(
    ("event_type", "handler_name", "status"),
    [
        (ChargingEventType.CHARGING_PROGRESS, "update_progress", "active"),
        (ChargingEventType.PAUSED, "pause", "paused"),
        (ChargingEventType.RESUMED, "resume", "active"),
        (ChargingEventType.INTERRUPTED, "finish", "interrupted"),
        (ChargingEventType.COMPLETED, "finish", "completed"),
        (ChargingEventType.DISCONNECTED, "disconnect", "interrupted"),
    ],
)
def test_event_dispatch(dependencies, event_type, handler_name, status):
    service, repository, mongo_session = dependencies
    active = {"session_id": "session-001"}
    repository.get_active_session.return_value = active

    event = ChargingEvent(
        event_id="event-001",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=event_type,
        timestamp=datetime.now(UTC),
        battery_percentage=40,
        charging_power_kw=7.2,
    )

    handler = MagicMock(return_value={"status": status})
    setattr(service.lifecycle, handler_name, handler)

    assert service.process_event(event) == {"status": status}
    handler.assert_called_once_with(event, active, mongo_session)


def test_session_id_mismatch(dependencies):
    service, repository, _ = dependencies
    repository.get_active_session.return_value = {
        "session_id": "different-session"
    }

    event = ChargingEvent(
        event_id="event-002",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.PAUSED,
        timestamp=datetime.now(UTC),
    )

    with pytest.raises(ChargingSessionNotFoundError):
        service.process_event(event)


def test_unsupported_event_type(dependencies):
    service, repository, _ = dependencies
    repository.get_active_session.return_value = {
        "session_id": "session-001"
    }

    event = ChargingEvent.model_construct(
        event_id="event-003",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type="unsupported",
        timestamp=datetime.now(UTC),
    )

    with pytest.raises(ValueError, match="Unsupported charging event type"):
        service.process_event(event)