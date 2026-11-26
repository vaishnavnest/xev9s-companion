
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    ChargingSessionNotFoundError,
    DuplicateChargingEventError,
)
from backend.app.schemas.charging_event import (
    ChargingEvent,
    ChargingEventType,
)
from backend.app.services.charging_event_service import (
    ChargingEventService,
)
from pymongo.errors import DuplicateKeyError


@pytest.fixture
def dependencies():
    event_repository = MagicMock()
    session_repository = MagicMock()
    mongo_client = MagicMock()

    mongo_session = MagicMock()
    mongo_client.start_session.return_value.__enter__.return_value = (
        mongo_session
    )
    mongo_session.start_transaction.return_value.__enter__.return_value = (
        None
    )

    service = ChargingEventService(
        event_repository,
        session_repository,
        mongo_client,
    )

    return service, event_repository, session_repository, mongo_session


@pytest.fixture
def connected_event():
    return ChargingEvent(
        event_id="event-001",
        vehicle_id="vehicle-001",
        event_type=ChargingEventType.CONNECTED,
        timestamp=datetime.now(UTC),
    )


def test_connected_event_is_saved(dependencies, connected_event):
    service, event_repository, _, mongo_session = dependencies

    result = service.process_event(connected_event)

    assert result == {"status": "connected"}
    event_repository.save_event.assert_called_once_with(
        connected_event,
        session=mongo_session,
    )


def test_duplicate_event_raises_error(dependencies, connected_event):
    service, event_repository, _, _ = dependencies
    event_repository.save_event.side_effect = DuplicateKeyError(
        "Duplicate event"
    )

    with pytest.raises(DuplicateChargingEventError):
        service.process_event(connected_event)


def test_started_event_dispatches_to_lifecycle(dependencies):
    service, _, _, _ = dependencies
    event = ChargingEvent(
        event_id="event-002",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.CHARGING_STARTED,
        timestamp=datetime.now(UTC),
        battery_percentage=30,
        target_percentage=80,
    )
    service.lifecycle.start = MagicMock(
        return_value={"session_id": "session-001", "status": "active"}
    )

    result = service.process_event(event)

    assert result["status"] == "active"
    service.lifecycle.start.assert_called_once()


def test_progress_event_requires_active_session(dependencies):
    service, _, session_repository, _ = dependencies
    event = ChargingEvent(
        event_id="event-003",
        vehicle_id="vehicle-001",
        session_id="session-001",
        event_type=ChargingEventType.CHARGING_PROGRESS,
        timestamp=datetime.now(UTC),
        battery_percentage=40,
        charging_power_kw=7.2,
    )
    session_repository.get_active_session.return_value = None

    with pytest.raises(ChargingSessionNotFoundError):
        service.process_event(event)
