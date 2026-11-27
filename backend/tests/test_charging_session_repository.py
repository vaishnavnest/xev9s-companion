
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.schemas.charging_session import ChargingSessionStatus
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError


@pytest.fixture
def collection():
    return MagicMock()


@pytest.fixture
def repository(collection):
    return ChargingSessionRepository(collection)


@pytest.fixture
def event():
    return MagicMock()


@pytest.fixture
def session_document():
    return {
        "session_id": "session-123",
        "vehicle_id": "vehicle-123",
        "status": ChargingSessionStatus.ACTIVE.value,
    }


@pytest.mark.parametrize("session", [None, MagicMock()])
def test_create_session(
    repository,
    collection,
    event,
    session_document,
    session,
):
    with patch(
        "backend.app.repositories.charging_session_repository."
        "create_charging_session_document",
        return_value=session_document,
    ) as create_document:
        result = repository.create_session(event, 80, session)

    create_document.assert_called_once_with(event, 80)
    collection.insert_one.assert_called_once_with(
        session_document,
        session=session,
    )
    assert result == session_document


def test_create_session_duplicate(repository, collection, event):
    collection.insert_one.side_effect = DuplicateKeyError("duplicate")

    with patch(
        "backend.app.repositories.charging_session_repository."
        "create_charging_session_document",
        return_value={},
    ), pytest.raises(
        ValueError,
        match="Charging session already exists",
    ) as error:
        repository.create_session(event, 80)

    assert isinstance(error.value.__cause__, DuplicateKeyError)


def test_get_session(repository, collection):
    expected = {"session_id": "session-123"}
    collection.find_one.return_value = expected

    result = repository.get_session("session-123")

    collection.find_one.assert_called_once_with(
        {"session_id": "session-123"},
        {"_id": 0},
    )
    assert result == expected


@pytest.mark.parametrize(
    "status",
    [
        ChargingSessionStatus.ACTIVE.value,
        ChargingSessionStatus.PAUSED.value,
    ],
)
@pytest.mark.parametrize("session", [None, MagicMock()])
def test_get_active_session(
    repository,
    collection,
    session,
    status,
):
    expected = {"vehicle_id": "vehicle-123", "status": status}
    collection.find_one.return_value = expected

    result = repository.get_active_session("vehicle-123", session)

    collection.find_one.assert_called_once_with(
        {
            "vehicle_id": "vehicle-123",
            "status": {
                "$in": [
                    ChargingSessionStatus.ACTIVE.value,
                    ChargingSessionStatus.PAUSED.value,
                ]
            },
        },
        {"_id": 0},
        session=session,
    )
    assert result == expected


@pytest.mark.parametrize("session", [None, MagicMock()])
def test_update_session(repository, collection, session):
    expected = {"session_id": "session-123", "status": "completed"}
    collection.find_one_and_update.return_value = expected

    result = repository.update_session(
        "session-123",
        {"status": "completed"},
        session,
    )

    args, kwargs = collection.find_one_and_update.call_args

    assert args[0] == {"session_id": "session-123"}
    assert args[1]["$set"]["status"] == "completed"
    assert isinstance(args[1]["$set"]["updated_at"], datetime)
    assert kwargs["return_document"] == ReturnDocument.AFTER
    assert kwargs["projection"] == {"_id": 0}
    assert kwargs["session"] is session
    assert result == expected
