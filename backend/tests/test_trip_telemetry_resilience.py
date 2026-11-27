from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

from backend.app.communication.mqtt_subscriber import MQTTSubscriber
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.telemetry_service import TelemetryService
from backend.app.services.trip_lifecycle import TripLifecycleManager


def _payload(
    *,
    timestamp: datetime,
    odometer_km: float,
    operating_state: str = "parked",
    speed_kph: float = 0.0,
    battery_percentage: float = 75.0,
) -> TelemetryPayload:
    return TelemetryPayload(
        vehicle_id="XEV-001",
        timestamp=timestamp,
        battery_percentage=battery_percentage,
        estimated_range_km=250.0,
        speed_kph=speed_kph,
        odometer_km=odometer_km,
        latitude=12.9716,
        longitude=77.5946,
        operating_state=operating_state,
        is_locked=True,
        charging_status="disconnected",
        charging_power_kw=0.0,
        cabin_preconditioning_active=False,
    )


def test_odometer_reset_finalizes_trip_and_unblocks_future_trips():
    start = datetime.now(UTC) - timedelta(minutes=5)
    repo = MagicMock()
    repo.get_active_trip.return_value = {
        "trip_id": "trp_reset",
        "status": "ongoing",
        "started_at": start,
        "start_odometer_km": 120.0,
        "battery": {"start_percent": 80.0, "end_percent": None},
    }
    repo.complete_trip.side_effect = lambda tid, upd: {
        "trip_id": tid,
        "status": "completed",
        **upd,
    }
    manager = TripLifecycleManager(repo)

    result = manager.process_telemetry(
        _payload(timestamp=datetime.now(UTC), odometer_km=0.0)
    )

    assert result is not None
    assert result["status"] == "completed"
    assert result["distance_km"] is None
    assert result["average_speed_kmh"] is None
    assert result["duration_seconds"] >= 300
    repo.complete_trip.assert_called_once()


def test_out_of_order_parked_telemetry_does_not_corrupt_active_trip():
    start = datetime.now(UTC)
    repo = MagicMock()
    repo.get_active_trip.return_value = {
        "trip_id": "trp_active",
        "status": "ongoing",
        "started_at": start,
        "start_odometer_km": 100.0,
        "battery": {"start_percent": 80.0, "end_percent": None},
    }
    manager = TripLifecycleManager(repo)

    result = manager.process_telemetry(
        _payload(timestamp=start - timedelta(seconds=10), odometer_km=105.0)
    )

    assert result is None
    repo.complete_trip.assert_not_called()


def test_repeated_parked_messages_are_noop_without_active_trip():
    repo = MagicMock()
    repo.get_active_trip.return_value = None
    manager = TripLifecycleManager(repo)

    result = manager.process_telemetry(
        _payload(timestamp=datetime.now(UTC), odometer_km=105.0)
    )

    assert result is None
    repo.complete_trip.assert_not_called()


def test_telemetry_persists_once_and_broadcasts_when_trip_service_fails():
    telemetry_repo = MagicMock()
    vehicle_repo = MagicMock()
    vehicle_repo.get_active_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    saved_doc = {"vehicle_id": "XEV-001", "received_at": datetime.now(UTC)}
    telemetry_repo.save_telemetry.return_value = saved_doc

    trip_service = MagicMock()
    trip_service.process_telemetry.side_effect = RuntimeError("db glitch")

    service = TelemetryService(telemetry_repo, vehicle_repo, trip_service=trip_service)
    broadcasts = []
    subscriber = MQTTSubscriber(service, on_telemetry=broadcasts.append)

    payload = _payload(timestamp=datetime.now(UTC), odometer_km=10.0)
    msg = MagicMock()
    msg.topic = "xev9s/vehicles/XEV-001/telemetry"
    msg.payload = payload.model_dump_json().encode("utf-8")

    subscriber._handle_telemetry(msg)

    telemetry_repo.save_telemetry.assert_called_once()
    assert broadcasts == [saved_doc]
