from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

from backend.app.repositories.trip_repository import TripRepository
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.trip_lifecycle import TripLifecycleManager


def make_tel(**kwargs):
    defaults = {
        "vehicle_id": "XEV-E2E-001",
        "timestamp": datetime.now(UTC),
        "battery_percentage": 90.0,
        "estimated_range_km": 350.0,
        "speed_kph": 50.0,
        "odometer_km": 2000.0,
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


def test_trip_survives_backend_restart():
    # Simulate database with an ongoing trip from before restart
    collection = MagicMock()
    start_time = datetime.now(UTC) - timedelta(minutes=15)
    existing_trip = {
        "trip_id": "trp_pre_restart",
        "vehicle_id": "XEV-E2E-001",
        "status": "ongoing",
        "started_at": start_time,
        "start_odometer_km": 2000.0,
        "battery": {"start_percent": 90.0, "end_percent": None},
        "last_telemetry_at": start_time,
    }
    collection.find_one.return_value = existing_trip

    # New instance of TripRepository & LifecycleManager created upon restart
    repo = TripRepository(collection)
    manager = TripLifecycleManager(repo)

    # 1. Driving telemetry arrives after restart -> associates with ongoing trip
    tel_driving = make_tel(
        odometer_km=2010.0,
        timestamp=start_time + timedelta(minutes=5),
    )
    res_driving = manager.process_telemetry(tel_driving)
    assert res_driving["trip_id"] == "trp_pre_restart"
    collection.insert_one.assert_not_called()

    # 2. Parked telemetry arrives -> completes the ongoing trip
    completed_doc = {**existing_trip, "status": "completed"}
    collection.find_one_and_update.return_value = completed_doc
    tel_parked = make_tel(
        operating_state="parked",
        speed_kph=0.0,
        odometer_km=2020.0,
        battery_percentage=85.0,
        timestamp=start_time + timedelta(minutes=15),
    )
    res_parked = manager.process_telemetry(tel_parked)
    assert res_parked["status"] == "completed"
    collection.find_one_and_update.assert_called_once()


def test_missing_gps_values_creates_and_completes_trip():
    collection = MagicMock()
    collection.find_one.return_value = None
    repo = TripRepository(collection)
    manager = TripLifecycleManager(repo)

    # Trip started with None GPS
    tel_start = make_tel(latitude=None, longitude=None)
    created = manager.process_telemetry(tel_start)
    assert created["start_location"]["latitude"] is None
    assert created["route"] == []

    # Trip completed with None GPS
    active = {
        "trip_id": created["trip_id"],
        "vehicle_id": "XEV-E2E-001",
        "status": "ongoing",
        "started_at": tel_start.timestamp,
        "start_odometer_km": 2000.0,
        "battery": {"start_percent": 90.0, "end_percent": None},
    }
    collection.find_one.return_value = active
    collection.find_one_and_update.return_value = {**active, "status": "completed"}

    tel_end = make_tel(
        operating_state="parked",
        latitude=None,
        longitude=None,
        odometer_km=2015.0,
        battery_percentage=86.0,
        timestamp=tel_start.timestamp + timedelta(minutes=10),
    )
    res_end = manager.process_telemetry(tel_end)
    assert res_end["status"] == "completed"
    assert (
        collection.find_one_and_update.call_args[0][1]["$set"]["end_location"][
            "latitude"
        ]
        is None
    )
