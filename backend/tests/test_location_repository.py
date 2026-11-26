from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

from backend.app.repositories.telemetry_repository import TelemetryRepository


def test_get_latest_valid_location_returns_record_with_coords():
    collection = MagicMock()
    repo = TelemetryRepository(collection)
    expected = {
        "vehicle_id": "XEV-001",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "timestamp": datetime.now(UTC),
    }
    collection.find_one.return_value = expected

    result = repo.get_latest_valid_location("XEV-001")

    assert result == expected
    collection.find_one.assert_called_once_with(
        {
            "vehicle_id": "XEV-001",
            "latitude": {"$exists": True, "$ne": None},
            "longitude": {"$exists": True, "$ne": None},
        },
        sort=[("timestamp", -1)],
    )


def test_get_latest_valid_location_returns_none_when_empty():
    collection = MagicMock()
    repo = TelemetryRepository(collection)
    collection.find_one.return_value = None

    result = repo.get_latest_valid_location("XEV-999")

    assert result is None
    collection.find_one.assert_called_once_with(
        {
            "vehicle_id": "XEV-999",
            "latitude": {"$exists": True, "$ne": None},
            "longitude": {"$exists": True, "$ne": None},
        },
        sort=[("timestamp", -1)],
    )


def test_get_latest_valid_location_preserves_original_timestamp():
    collection = MagicMock()
    repo = TelemetryRepository(collection)
    gps_time = datetime.now(UTC) - timedelta(minutes=10)
    expected = {
        "vehicle_id": "XEV-001",
        "latitude": 13.0827,
        "longitude": 80.2707,
        "timestamp": gps_time,
    }
    collection.find_one.return_value = expected

    result = repo.get_latest_valid_location("XEV-001")

    assert result is not None
    assert result["timestamp"] == gps_time
    assert result["latitude"] == 13.0827
    assert result["longitude"] == 80.2707
