from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.services.location_service import LocationService


@pytest.fixture
def mock_repos():
    vehicle_repo = MagicMock()
    telemetry_repo = MagicMock()
    return vehicle_repo, telemetry_repo


def test_get_location_unknown_vehicle(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo)
    vehicle_repo.get_vehicle_by_id.return_value = None

    with pytest.raises(
        VehicleNotActiveError, match="Vehicle is not registered or active"
    ):
        service.get_vehicle_location("user-1", "UNKNOWN-001")


def test_get_location_inactive_vehicle(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo)
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": False,
    }

    with pytest.raises(
        VehicleNotActiveError, match="Vehicle is not registered or active"
    ):
        service.get_vehicle_location("user-1", "XEV-001")


def test_get_location_unassociated_vehicle(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo)
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = False

    with pytest.raises(
        VehicleAccessDeniedError, match="You do not have access to this vehicle"
    ):
        service.get_vehicle_location("user-1", "XEV-001")


def test_get_location_empty_id(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo)

    with pytest.raises(ValueError, match="Vehicle identifier cannot be empty"):
        service.get_vehicle_location("user-1", "   ")


def test_normalize_datetime():
    assert LocationService._normalize_datetime(None) is None
    assert LocationService._normalize_datetime("not-a-datetime") is None

    naive = datetime(2026, 11, 26, 12, 0, 0)
    normalized = LocationService._normalize_datetime(naive)
    assert normalized is not None
    assert normalized.tzinfo == UTC


def test_get_location_invalid_timestamp_in_location_record(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    service = LocationService(vehicle_repo, telemetry_repo)
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True
    telemetry_repo.get_latest_telemetry.return_value = None
    telemetry_repo.get_latest_valid_location.return_value = {
        "vehicle_id": "XEV-001",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "timestamp": "invalid-timestamp",
    }
    result = service.get_vehicle_location("user-1", "XEV-001")
    assert result.is_current is False
    assert result.timestamp is None
    assert result.operating_state is None
