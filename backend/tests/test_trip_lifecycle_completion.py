from datetime import UTC, datetime
from unittest.mock import MagicMock

from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.trip_lifecycle import TripLifecycleManager


def test_trip_completion_with_naive_mongo_start_and_aware_telemetry_end():
    """Verify TripLifecycleManager completes a trip when Mongo returns naive UTC."""
    naive_start = datetime(2026, 11, 26, 10, 0, 0)
    aware_end = datetime(2026, 11, 26, 10, 30, 0, tzinfo=UTC)

    repo = MagicMock()
    repo.get_active_trip.return_value = {
        "trip_id": "trp_mixed_tz",
        "status": "ongoing",
        "started_at": naive_start,
        "start_odometer_km": 1000.0,
        "battery": {"start_percent": 80.0, "end_percent": None},
    }
    repo.complete_trip.side_effect = lambda trip_id, updates: {
        "trip_id": trip_id,
        "status": "completed",
        **updates,
    }

    manager = TripLifecycleManager(repo)
    telemetry = TelemetryPayload(
        vehicle_id="XEV-001",
        timestamp=aware_end,
        battery_percentage=74.0,
        estimated_range_km=280.0,
        speed_kph=0.0,
        odometer_km=1025.0,
        latitude=12.9716,
        longitude=77.5946,
        operating_state="parked",
        is_locked=True,
        charging_status="disconnected",
        charging_power_kw=0.0,
        cabin_preconditioning_active=False,
    )

    result = manager.process_telemetry(telemetry)

    assert result is not None
    assert result["status"] == "completed"
    assert result["duration_seconds"] == 1800
    assert result["distance_km"] == 25.0
    assert result["average_speed_kmh"] == 50.0
    repo.complete_trip.assert_called_once()
