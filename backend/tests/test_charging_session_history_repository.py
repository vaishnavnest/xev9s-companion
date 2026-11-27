from datetime import datetime
from unittest.mock import MagicMock

import pytest
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.schemas.charging_session import ChargingSessionStatus
from pymongo import DESCENDING


@pytest.fixture
def collection():
    return MagicMock()


@pytest.fixture
def repository(collection):
    return ChargingSessionRepository(collection)


def test_get_session_history(repository, collection):
    cursor = MagicMock()
    collection.find.return_value = cursor
    collection.count_documents.return_value = 1
    cursor.sort.return_value = cursor
    cursor.skip.return_value = cursor
    cursor.limit.return_value = cursor
    cursor.__iter__.return_value = iter([{"session_id": "session-123"}])

    sessions, total = repository.get_session_history(
        "vehicle-123",
        limit=10,
        offset=5,
    )

    collection.count_documents.assert_called_once_with({"vehicle_id": "vehicle-123"})
    collection.find.assert_called_once_with(
        {"vehicle_id": "vehicle-123"},
        {"_id": 0},
    )
    cursor.sort.assert_called_once_with("started_at", DESCENDING)
    cursor.skip.assert_called_once_with(5)
    cursor.limit.assert_called_once_with(10)
    assert sessions == [{"session_id": "session-123"}]
    assert total == 1


def test_get_session_history_with_filters_and_sort(repository, collection):
    cursor = MagicMock()
    collection.find.return_value = cursor
    collection.count_documents.return_value = 0
    cursor.sort.return_value = cursor
    cursor.skip.return_value = cursor
    cursor.limit.return_value = cursor
    cursor.__iter__.return_value = iter([])

    start = datetime(2026, 11, 1)
    end = datetime(2026, 11, 2)
    sessions, total = repository.get_session_history(
        "vehicle-123",
        status=ChargingSessionStatus.COMPLETED,
        from_time=start,
        to_time=end,
        sort="durationSeconds",
    )

    expected_query = {
        "vehicle_id": "vehicle-123",
        "status": "completed",
        "started_at": {"$gte": start, "$lte": end},
    }
    collection.count_documents.assert_called_once_with(expected_query)
    collection.find.assert_called_once_with(expected_query, {"_id": 0})
    cursor.sort.assert_called_once_with("duration_seconds", 1)
    assert sessions == []
    assert total == 0
