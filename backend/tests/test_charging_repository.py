
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest
from backend.app.repositories.charging_repository import ChargingRepository
from pymongo import ReturnDocument


@pytest.fixture
def collection():
    return MagicMock()


@pytest.fixture
def repository(collection):
    return ChargingRepository(collection)


@pytest.fixture
def preferences():
    return MagicMock()


@pytest.fixture
def charging_document():
    return {
        "vehicle_id": "vehicle-123",
        "target_percentage": 80,
        "created_at": datetime(2026, 1, 1),
        "updated_at": datetime(2026, 1, 2),
    }


@pytest.mark.parametrize("session", [None, MagicMock()])
def test_save_preferences(
    repository,
    collection,
    preferences,
    charging_document,
    session,
):
    collection.find_one_and_update.return_value = charging_document

    with patch(
        "backend.app.repositories.charging_repository."
        "create_charging_preferences_document",
        return_value=charging_document,
    ) as create_document:
        result = repository.save_preferences(
            " vehicle-123 ",
            preferences,
            session,
        )

    create_document.assert_called_once_with("vehicle-123", preferences)
    collection.find_one_and_update.assert_called_once()

    args, kwargs = collection.find_one_and_update.call_args

    assert args[0] == {"vehicle_id": "vehicle-123"}
    assert kwargs["upsert"] is True
    assert kwargs["return_document"] == ReturnDocument.AFTER
    assert kwargs["session"] is session

    update = args[1]
    assert "vehicle_id" not in update["$set"]
    assert "created_at" not in update["$set"]
    assert update["$set"]["target_percentage"] == 80
    assert update["$setOnInsert"]["vehicle_id"] == "vehicle-123"
    assert isinstance(update["$setOnInsert"]["created_at"], datetime)
    assert result == charging_document


def test_get_preferences(repository, collection):
    expected = {"vehicle_id": "vehicle-123", "target_percentage": 80}
    collection.find_one.return_value = expected

    result = repository.get_preferences(" vehicle-123 ")

    collection.find_one.assert_called_once_with(
        {"vehicle_id": "vehicle-123"},
        {"_id": 0},
    )
    assert result == expected


def test_get_preferences_returns_none(repository, collection):
    collection.find_one.return_value = None

    result = repository.get_preferences("vehicle-123")

    assert result is None
