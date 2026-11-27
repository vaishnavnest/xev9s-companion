from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import TripAlreadyActiveError
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.trip_lifecycle import TripLifecycleManager


def make_telemetry(**kwargs):
    defaults = {
        "vehicle_id": "XEV-001",
        "timestamp": datetime.now(UTC),
        "battery_percentage": 80.0,
        "estimated_range_km": 300.0,
        "speed_kph": 40.0,
        "odometer_km": 1000.0,
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


def test_start_trip_on_driving_transition():
    repo = MagicMock()
    repo.get_active_trip.return_value = None
    repo.create_trip.return_value = {"trip_id": "trp_1", "status": "ongoing"}

    manager = TripLifecycleManager(repo)
    tel = make_telemetry(operating_state="driving")
    result = manager.process_telemetry(tel)

    assert result["trip_id"] == "trp_1"
    repo.get_active_trip.assert_called_once_with("XEV-001")
    repo.create_trip.assert_called_once_with(tel)


def test_in_transit_updates_associated_with_active_trip():
    repo = MagicMock()
    repo.get_active_trip.return_value = {
        "trip_id": "trp_1",
        "status": "ongoing",
        "last_telemetry_at": datetime.now(UTC) - timedelta(seconds=10),
    }

    manager = TripLifecycleManager(repo)
    tel = make_telemetry(operating_state="driving", speed_kph=60.0)
    result = manager.process_telemetry(tel)

    assert result["trip_id"] == "trp_1"
    repo.create_trip.assert_not_called()
    repo.append_route_point.assert_called_once()


def test_concurrent_start_duplicate_key_error_recovery():
    repo = MagicMock()
    repo.get_active_trip.side_effect = [
        None,
        {"trip_id": "trp_winner", "status": "ongoing"},
    ]
    repo.create_trip.side_effect = TripAlreadyActiveError("Already active")

    manager = TripLifecycleManager(repo)
    tel = make_telemetry(operating_state="driving")
    result = manager.process_telemetry(tel)

    assert result["trip_id"] == "trp_winner"
    repo.append_route_point.assert_called_once()


def test_complete_trip_on_parked_transition():
    start_time = datetime.now(UTC) - timedelta(minutes=30)
    repo = MagicMock()
    repo.get_active_trip.return_value = {
        "trip_id": "trp_1",
        "status": "ongoing",
        "started_at": start_time,
        "start_odometer_km": 1000.0,
        "battery": {"start_percent": 80.0, "end_percent": None},
    }
    repo.complete_trip.return_value = {
        "trip_id": "trp_1",
        "vehicle_id": "XEV-001",
        "status": "completed",
        "started_at": start_time,
        "ended_at": datetime.now(UTC),
        "distance_km": 25.0,
        "duration_seconds": 1800,
        "average_speed_kmh": 50.0,
        "energy_consumed_kwh": 4.2,
    }

    on_completed = MagicMock()
    manager = TripLifecycleManager(repo, on_trip_completed=on_completed)

    end_time = datetime.now(UTC)
    tel = make_telemetry(
        operating_state="parked",
        speed_kph=0.0,
        odometer_km=1025.0,
        battery_percentage=73.0,
        timestamp=end_time,
    )

    result = manager.process_telemetry(tel)

    assert result["status"] == "completed"
    repo.complete_trip.assert_called_once()
    on_completed.assert_called_once()


def test_complete_trip_broadcast_error_does_not_fail_completion():
    start_time = datetime.now(UTC) - timedelta(minutes=10)
    repo = MagicMock()
    repo.get_active_trip.return_value = {
        "trip_id": "trp_1",
        "status": "ongoing",
        "started_at": start_time.isoformat(),
        "start_odometer_km": 500.0,
        "battery": {"start_percent": 90.0, "end_percent": None},
    }
    repo.complete_trip.return_value = {
        "trip_id": "trp_1",
        "vehicle_id": "XEV-001",
        "status": "completed",
        "started_at": start_time,
        "ended_at": datetime.now(UTC),
    }

    failing_callback = MagicMock(side_effect=RuntimeError("WebSocket failure"))
    manager = TripLifecycleManager(repo, on_trip_completed=failing_callback)

    tel = make_telemetry(
        operating_state="parked",
        speed_kph=0.0,
        odometer_km=510.0,
        battery_percentage=85.0,
        timestamp=datetime.now(UTC),
    )
    result = manager.process_telemetry(tel)
    assert result["status"] == "completed"


def test_parked_telemetry_when_already_parked_is_noop():
    repo = MagicMock()
    repo.get_active_trip.return_value = None
    manager = TripLifecycleManager(repo)

    tel = make_telemetry(operating_state="parked", speed_kph=0.0)
    result = manager.process_telemetry(tel)
    assert result is None
    repo.create_trip.assert_not_called()
    repo.complete_trip.assert_not_called()


def test_charging_telemetry_without_active_trip_is_noop():
    repo = MagicMock()
    repo.get_active_trip.return_value = None
    manager = TripLifecycleManager(repo)
    tel = make_telemetry(operating_state="charging")
    assert manager.process_telemetry(tel) is None
    repo.complete_trip.assert_not_called()


@pytest.mark.parametrize("end_state", ["charging", "interrupted"])
def test_complete_trip_on_non_driving_transition(end_state):
    start_time = datetime.now(UTC) - timedelta(minutes=15)
    repo = MagicMock()
    repo.get_active_trip.return_value = {
        "trip_id": "trp_2",
        "status": "ongoing",
        "started_at": start_time,
        "start_odometer_km": 200.0,
        "battery": {"start_percent": 80.0, "end_percent": None},
    }
    repo.complete_trip.return_value = {
        "trip_id": "trp_2",
        "vehicle_id": "XEV-001",
        "status": "completed",
    }

    manager = TripLifecycleManager(repo)
    tel = make_telemetry(
        operating_state=end_state,
        charging_status="charging" if end_state == "charging" else "interrupted",
        speed_kph=0.0,
        odometer_km=210.0,
        battery_percentage=76.0,
    )
    result = manager.process_telemetry(tel)

    assert result["status"] == "completed"
    repo.complete_trip.assert_called_once()
