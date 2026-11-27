from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import TripAlreadyActiveError
from backend.app.repositories.trip_repository import TripRepository
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.schemas.trip import TripStatus
from pymongo.errors import DuplicateKeyError


def make_telemetry(**kwargs):
    defaults = {
        "vehicle_id": "XEV-001",
        "timestamp": datetime.now(UTC),
        "battery_percentage": 80.0,
        "estimated_range_km": 300.0,
        "speed_kph": 30.0,
        "odometer_km": 100.0,
        "latitude": 12.9716,
        "longitude": 77.5946,
        "operating_state": "driving",
        "is_locked": False,
        "charging_status": "disconnected",
        "charging_power_kw": 0.0,
        "cabin_preconditioning_active": False,
    }
    defaults.update(kwargs)
    return TelemetryPayload(**defaults)


def test_create_trip_success():
    collection = MagicMock()
    repo = TripRepository(collection)
    tel = make_telemetry()
    trip = repo.create_trip(tel, trip_id="trp_001")
    assert trip["trip_id"] == "trp_001"
    collection.insert_one.assert_called_once_with(trip)


def test_create_trip_duplicate_key_error():
    collection = MagicMock()
    collection.insert_one.side_effect = DuplicateKeyError("E11000 duplicate key error")
    repo = TripRepository(collection)
    tel = make_telemetry()
    with pytest.raises(TripAlreadyActiveError, match="already has an active trip"):
        repo.create_trip(tel)


def test_get_active_trip():
    collection = MagicMock()
    repo = TripRepository(collection)
    collection.find_one.return_value = {"trip_id": "trp_1", "status": "ongoing"}
    res = repo.get_active_trip("XEV-001")
    assert res["trip_id"] == "trp_1"
    collection.find_one.assert_called_once_with(
        {"vehicle_id": "XEV-001", "status": TripStatus.ONGOING.value}
    )


def test_get_trip_by_id():
    collection = MagicMock()
    repo = TripRepository(collection)
    collection.find_one.return_value = {"trip_id": "trp_1"}
    res = repo.get_trip_by_id("trp_1")
    assert res["trip_id"] == "trp_1"
    collection.find_one.assert_called_once_with({"trip_id": "trp_1"})


def test_append_route_point():
    collection = MagicMock()
    update_res = MagicMock()
    update_res.modified_count = 1
    collection.update_one.return_value = update_res
    repo = TripRepository(collection)

    point = {"latitude": 12.98, "longitude": 77.60, "speed_kmh": 40.0}
    timestamp = datetime.now(UTC)
    success = repo.append_route_point("trp_1", point, timestamp)
    assert success is True
    collection.update_one.assert_called_once()


def test_complete_trip():
    collection = MagicMock()
    collection.find_one_and_update.return_value = {
        "trip_id": "trp_1",
        "status": "completed",
    }
    repo = TripRepository(collection)
    updates = {"distance_km": 15.0, "duration_seconds": 900}
    res = repo.complete_trip("trp_1", updates)
    assert res["status"] == "completed"
    collection.find_one_and_update.assert_called_once()


def test_list_trips_pagination_and_sorting():
    collection = MagicMock()
    cursor = MagicMock()
    cursor.sort.return_value = cursor
    cursor.skip.return_value = cursor
    cursor.limit.return_value = [{"trip_id": "trp_1"}]
    collection.find.return_value = cursor
    collection.count_documents.return_value = 1

    repo = TripRepository(collection)
    from_time = datetime.now(UTC) - timedelta(hours=2)
    to_time = datetime.now(UTC)
    trips, total = repo.list_trips(
        vehicle_id="XEV-001",
        page=2,
        page_size=10,
        sort="-started_at",
        from_time=from_time,
        to_time=to_time,
        status="completed",
    )
    assert trips == [{"trip_id": "trp_1"}]
    assert total == 1
    cursor.skip.assert_called_once_with(10)
    cursor.limit.assert_called_once_with(10)


def test_list_trips_default_sort_field():
    collection = MagicMock()
    cursor = MagicMock()
    cursor.sort.return_value = cursor
    cursor.skip.return_value = cursor
    cursor.limit.return_value = []
    collection.find.return_value = cursor
    collection.count_documents.return_value = 0

    repo = TripRepository(collection)
    repo.list_trips(vehicle_id="XEV-001", sort="+")
    cursor.sort.assert_called_once_with([("started_at", 1)])


@pytest.mark.parametrize(
    ("sort_arg", "expected_field", "expected_dir"),
    [
        ("-startedAt", "started_at", -1),
        ("endedAt", "ended_at", 1),
        ("-distanceKm", "distance_km", -1),
        ("durationSeconds", "duration_seconds", 1),
        ("-unknownField", "started_at", -1),
    ],
)
def test_list_trips_normalizes_and_validates_sort_keys(
    sort_arg, expected_field, expected_dir
):
    collection = MagicMock()
    cursor = MagicMock()
    cursor.sort.return_value = cursor
    cursor.skip.return_value = cursor
    cursor.limit.return_value = []
    collection.find.return_value = cursor
    collection.count_documents.return_value = 0

    repo = TripRepository(collection)
    repo.list_trips(vehicle_id="XEV-001", sort=sort_arg)
    cursor.sort.assert_called_once_with([(expected_field, expected_dir)])
