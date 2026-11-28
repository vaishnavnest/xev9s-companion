from concurrent.futures import Future
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.services.geocoding_service import GeocodingService
from backend.app.services.location_service import LocationService


class _ImmediateExecutor:
    def submit(self, fn, *args, **kwargs):
        future: Future = Future()
        future.set_result(fn(*args, **kwargs))
        return future


@pytest.fixture
def mock_repos():
    vehicle_repo = MagicMock()
    telemetry_repo = MagicMock()
    return vehicle_repo, telemetry_repo


def test_get_location_online_vehicle_fresh_gps(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo, online_timeout_seconds=30)
    now = datetime.now(UTC)

    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    telemetry_repo.get_latest_telemetry.return_value = {
        "vehicle_id": "XEV-001",
        "timestamp": now - timedelta(seconds=5),
        "operating_state": "driving",
    }
    telemetry_repo.get_latest_valid_location.return_value = {
        "vehicle_id": "XEV-001",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "timestamp": now - timedelta(seconds=5),
    }

    result = service.get_vehicle_location("user-1", "XEV-001")

    assert result.vehicle_id == "XEV-001"
    assert result.latitude == 12.9716
    assert result.longitude == 77.5946
    assert result.is_current is True
    assert result.connectivity_status == "online"
    assert result.operating_state == "driving"


def test_get_location_online_vehicle_stale_gps(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo, online_timeout_seconds=30)
    now = datetime.now(UTC)

    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    telemetry_repo.get_latest_telemetry.return_value = {
        "vehicle_id": "XEV-001",
        "timestamp": now - timedelta(seconds=2),
    }
    telemetry_repo.get_latest_valid_location.return_value = {
        "vehicle_id": "XEV-001",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "timestamp": now - timedelta(seconds=45),
    }

    result = service.get_vehicle_location("user-1", "XEV-001")

    assert result.is_current is False
    assert result.connectivity_status == "online"
    assert result.latitude == 12.9716


def test_get_location_offline_vehicle_retains_last_known(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo, online_timeout_seconds=30)
    now = datetime.now(UTC)
    last_known_time = now - timedelta(minutes=15)

    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    telemetry_repo.get_latest_telemetry.return_value = {
        "vehicle_id": "XEV-001",
        "timestamp": last_known_time,
    }
    telemetry_repo.get_latest_valid_location.return_value = {
        "vehicle_id": "XEV-001",
        "latitude": 13.0827,
        "longitude": 80.2707,
        "timestamp": last_known_time,
    }

    result = service.get_vehicle_location("user-1", "XEV-001")

    assert result.is_current is False
    assert result.connectivity_status == "offline"
    assert result.latitude == 13.0827
    assert result.longitude == 80.2707
    assert result.timestamp == last_known_time


def test_get_location_no_gps_history_ever(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo, online_timeout_seconds=30)
    now = datetime.now(UTC)

    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    telemetry_repo.get_latest_telemetry.return_value = {
        "vehicle_id": "XEV-001",
        "timestamp": now - timedelta(seconds=5),
    }
    telemetry_repo.get_latest_valid_location.return_value = None

    result = service.get_vehicle_location("user-1", "XEV-001")

    assert result.latitude is None
    assert result.longitude is None
    assert result.timestamp is None
    assert result.is_current is False
    assert result.connectivity_status == "online"
    assert result.description is None


def _setup_vehicle(vehicle_repo, telemetry_repo, lat, lon, vehicle_id="XEV-001"):
    now = datetime.now(UTC)
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": vehicle_id,
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True
    telemetry_repo.get_latest_telemetry.return_value = {
        "vehicle_id": vehicle_id,
        "timestamp": now,
        "operating_state": "driving",
    }
    telemetry_repo.get_latest_valid_location.return_value = {
        "vehicle_id": vehicle_id,
        "latitude": lat,
        "longitude": lon,
        "timestamp": now,
    }


def test_get_location_returns_cached_description_and_lazy_pending(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    _setup_vehicle(vehicle_repo, telemetry_repo, 12.9716, 77.5946)

    geocoder = MagicMock(spec=GeocodingService)
    geocoder.get_cached.side_effect = [None, "MG Road, Bengaluru"]

    service = LocationService(vehicle_repo, telemetry_repo, geocoding_service=geocoder)

    first = service.get_vehicle_location("user-1", "XEV-001")
    second = service.get_vehicle_location("user-1", "XEV-001")

    assert first.description is None
    geocoder.schedule_lookup.assert_called_once()
    assert second.description == "MG Road, Bengaluru"
