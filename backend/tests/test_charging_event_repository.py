
from unittest.mock import MagicMock, patch

import pytest
from backend.app.repositories.charging_event_repository import (
    ChargingEventRepository,
)
from pymongo import DESCENDING


@pytest.fixture
def collection():
    return MagicMock()


@pytest.fixture
def repository(collection):
    return ChargingEventRepository(collection)


@pytest.fixture
def event():
    return MagicMock()


@pytest.fixture
def event_document():
    return {
        "event_id": "event-123",
        "vehicle_id": "vehicle-123",
        "event_type": "charging_started",
    }


@pytest.mark.parametrize("session", [None, MagicMock()])
def test_save_event(
    repository,
    collection,
    event,
    event_document,
    session,
):
    with patch(
        "backend.app.repositories.charging_event_repository."
        "create_charging_event_document",
        return_value=event_document,
    ) as create_document:
        result = repository.save_event(event, session)

    create_document.assert_called_once_with(event)
    collection.insert_one.assert_called_once_with(
        event_document,
        session=session,
    )
    assert result is None


@pytest.mark.parametrize(
    "stored_event",
    [
        {"event_id": "event-123", "event_type": "charging_started"},
        None,
    ],
)
def test_get_event(repository, collection, stored_event):
    collection.find_one.return_value = stored_event

    result = repository.get_event("event-123")

    collection.find_one.assert_called_once_with(
        {"event_id": "event-123"},
        {"_id": 0},
    )
    assert result == stored_event


def test_get_vehicle_events(repository, collection):
    cursor = MagicMock()
    collection.find.return_value = cursor
    cursor.sort.return_value = cursor
    cursor.limit.return_value = cursor
    expected = [{"event_id": "event-123"}]
    cursor.__iter__.return_value = iter(expected)

    result = repository.get_vehicle_events(
        "vehicle-123",
        limit=25,
    )

    collection.find.assert_called_once_with(
        {"vehicle_id": "vehicle-123"},
        {"_id": 0},
    )
    cursor.sort.assert_called_once_with("timestamp", DESCENDING)
    cursor.limit.assert_called_once_with(25)
    assert result == expected
