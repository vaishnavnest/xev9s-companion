
from datetime import UTC, datetime
from unittest.mock import MagicMock

from backend.app.repositories.telemetry_repository import (
    TelemetryRepository,
)
from backend.app.schemas.telemetry import TelemetryPayload
from bson import ObjectId


def create_valid_telemetry() -> TelemetryPayload:
    """Build a valid telemetry payload for repository tests."""

    return TelemetryPayload(
        vehicle_id="XEV9S-001",
        timestamp=datetime.now(UTC),
        battery_percentage=80.0,
        estimated_range_km=300.0,
        speed_kph=0.0,
        odometer_km=1200.5,
        latitude=8.5241,
        longitude=76.9366,
        operating_state="parked",
        is_locked=True,
        charging_status="disconnected",
        charging_power_kw=0.0,
        cabin_preconditioning_active=False,
    )


def test_save_telemetry():
    collection = MagicMock()
    inserted_id = ObjectId()
    collection.insert_one.return_value.inserted_id = inserted_id
    repository = TelemetryRepository(collection)

    result = repository.save_telemetry(create_valid_telemetry())

    collection.insert_one.assert_called_once()
    assert result["_id"] == inserted_id
    assert result["vehicle_id"] == "XEV9S-001"
    assert result["battery_percentage"] == 80.0
    assert "received_at" in result


def test_get_latest_telemetry():
    collection = MagicMock()
    expected_record = {"vehicle_id": "XEV9S-001"}
    collection.find_one.return_value = expected_record
    repository = TelemetryRepository(collection)

    result = repository.get_latest_telemetry("XEV9S-001")

    assert result == expected_record
    collection.find_one.assert_called_once_with(
        {"vehicle_id": "XEV9S-001"},
        sort=[("timestamp", -1)],
    )


def test_get_latest_telemetry_not_found():
    collection = MagicMock()
    collection.find_one.return_value = None
    repository = TelemetryRepository(collection)

    result = repository.get_latest_telemetry("XEV9S-001")

    assert result is None


def test_get_telemetry_history():
    collection = MagicMock()
    start_time = datetime(2026, 11, 23, tzinfo=UTC)
    end_time = datetime(2026, 11, 24, tzinfo=UTC)
    expected_records = [
        {"vehicle_id": "XEV9S-001", "battery_percentage": 80.0},
        {"vehicle_id": "XEV9S-001", "battery_percentage": 79.0},
    ]

    cursor = collection.find.return_value
    cursor.sort.return_value.limit.return_value = expected_records
    repository = TelemetryRepository(collection)

    result = repository.get_telemetry_history(
        "XEV9S-001",
        start_time,
        end_time,
    )

    assert result == expected_records
    collection.find.assert_called_once_with(
        {
            "vehicle_id": "XEV9S-001",
            "timestamp": {
                "$gte": start_time,
                "$lte": end_time,
            },
        }
    )
    cursor.sort.assert_called_once_with("timestamp", -1)
    cursor.sort.return_value.limit.assert_called_once_with(100)


def test_get_telemetry_history_with_custom_limit():
    collection = MagicMock()
    cursor = collection.find.return_value
    cursor.sort.return_value.limit.return_value = []
    repository = TelemetryRepository(collection)

    result = repository.get_telemetry_history(
        "XEV9S-001",
        datetime(2026, 11, 23, tzinfo=UTC),
        datetime(2026, 11, 24, tzinfo=UTC),
        limit=25,
    )

    assert result == []
    cursor.sort.return_value.limit.assert_called_once_with(25)
