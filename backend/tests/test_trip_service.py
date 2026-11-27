from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    TripNotFoundError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.schemas.trip import TripStatus
from backend.app.services.trip_service import TripService


@pytest.fixture
def service():
    trip_repo = MagicMock()
    vehicle_repo = MagicMock()
    lifecycle = MagicMock()
    return (
        TripService(trip_repo, vehicle_repo, lifecycle),
        trip_repo,
        vehicle_repo,
        lifecycle,
    )


def test_list_trips_success(service):
    svc, trip_repo, vehicle_repo, _ = service
    now = datetime.now(UTC)

    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    trip_repo.list_trips.return_value = (
        [
            {
                "trip_id": "trp_1",
                "status": "completed",
                "started_at": now,
                "ended_at": now,
                "start_location": {"latitude": 12.97, "longitude": 77.59},
                "end_location": {"latitude": 13.08, "longitude": 80.27},
                "distance_km": 15.0,
                "duration_seconds": 900,
                "energy_consumed_kwh": 2.5,
            }
        ],
        1,
    )

    res = svc.list_trips(user_id="user-1", vehicle_id="XEV-001", page=1, page_size=20)
    assert len(res.trips) == 1
    assert res.trips[0].trip_id == "trp_1"
    assert res.pagination.total_items == 1
    assert res.pagination.total_pages == 1


def test_list_trips_access_denied(service):
    svc, _, vehicle_repo, _ = service
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = False

    with pytest.raises(VehicleAccessDeniedError, match="do not have access"):
        svc.list_trips(user_id="user-1", vehicle_id="XEV-001")


def test_list_trips_vehicle_not_active(service):
    svc, _, vehicle_repo, _ = service
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": False,
    }

    with pytest.raises(VehicleNotActiveError, match="not registered or active"):
        svc.list_trips(user_id="user-1", vehicle_id="XEV-001")


def test_list_trips_invalid_time_range(service):
    svc, _, vehicle_repo, _ = service
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    now = datetime.now(UTC)
    with pytest.raises(ValueError, match="Start filter timestamp cannot be after"):
        svc.list_trips(
            user_id="user-1",
            vehicle_id="XEV-001",
            from_time=now,
            to_time=now - timedelta(hours=1),
        )


def test_get_trip_detail_success(service):
    svc, trip_repo, vehicle_repo, _ = service
    now = datetime.now(UTC)

    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    trip_repo.get_trip_by_id.return_value = {
        "trip_id": "trp_1",
        "vehicle_id": "XEV-001",
        "status": TripStatus.COMPLETED.value,
        "started_at": now,
        "ended_at": now,
        "start_location": {"latitude": 12.97, "longitude": 77.59},
        "end_location": {"latitude": 13.08, "longitude": 80.27},
        "distance_km": 15.0,
        "duration_seconds": 900,
        "average_speed_kmh": 60.0,
        "battery": {"start_percent": 80.0, "end_percent": 75.0},
        "route": [{"latitude": 12.97, "longitude": 77.59, "speed_kmh": 60.0}],
    }

    detail = svc.get_trip_detail(
        user_id="user-1", vehicle_id="XEV-001", trip_id="trp_1"
    )
    assert detail.trip_id == "trp_1"
    assert detail.average_speed_kmh == 60.0
    assert len(detail.route) == 1


def test_get_trip_detail_not_found(service):
    svc, trip_repo, vehicle_repo, _ = service
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    trip_repo.get_trip_by_id.return_value = None

    with pytest.raises(TripNotFoundError, match="not found"):
        svc.get_trip_detail(
            user_id="user-1", vehicle_id="XEV-001", trip_id="trp_unknown"
        )


def test_get_trip_detail_wrong_vehicle(service):
    svc, trip_repo, vehicle_repo, _ = service
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True

    trip_repo.get_trip_by_id.return_value = {
        "trip_id": "trp_1",
        "vehicle_id": "OTHER-VEHICLE",
    }

    with pytest.raises(TripNotFoundError, match="not found for vehicle"):
        svc.get_trip_detail(user_id="user-1", vehicle_id="XEV-001", trip_id="trp_1")
