from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    TripNotFoundError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.routes import trips as trip_routes
from backend.app.schemas.trip import (
    NamedLocation,
    Pagination,
    Trip,
    TripDetail,
    TripListResponse,
    TripStatus,
)
from fastapi import FastAPI
from fastapi.testclient import TestClient


@pytest.fixture
def api(monkeypatch):
    service = MagicMock()
    app = FastAPI()
    app.include_router(trip_routes.router)

    user = {"id": "507f1f77bcf86cd799439011"}
    monkeypatch.setattr(trip_routes, "get_trip_service", lambda request: service)
    app.dependency_overrides[get_current_user] = lambda: user

    with TestClient(app) as client:
        yield client, service, app


def test_list_trips_route_success(api):
    client, service, _ = api
    now = datetime.now(UTC)
    service.list_trips.return_value = TripListResponse(
        trips=[
            Trip(
                trip_id="trp_1",
                status=TripStatus.COMPLETED,
                started_at=now,
                start_location=NamedLocation(latitude=12.97, longitude=77.59),
            )
        ],
        pagination=Pagination(page=1, page_size=20, total_items=1, total_pages=1),
    )

    res = client.get("/vehicles/XEV-001/trips?page=1&page_size=20")
    assert res.status_code == 200
    data = res.json()
    assert len(data["trips"]) == 1
    assert data["trips"][0]["trip_id"] == "trp_1"


def test_list_trips_route_403(api):
    client, service, _ = api
    service.list_trips.side_effect = VehicleAccessDeniedError("Access denied")
    res = client.get("/vehicles/XEV-FORBIDDEN/trips")
    assert res.status_code == 403


def test_list_trips_route_404(api):
    client, service, _ = api
    service.list_trips.side_effect = VehicleNotActiveError("Not active")
    res = client.get("/vehicles/XEV-UNKNOWN/trips")
    assert res.status_code == 404


def test_list_trips_route_400(api):
    client, service, _ = api
    service.list_trips.side_effect = ValueError("Bad date range")
    res = client.get("/vehicles/XEV-001/trips")
    assert res.status_code == 400


def test_get_trip_detail_route_success(api):
    client, service, _ = api
    now = datetime.now(UTC)
    service.get_trip_detail.return_value = TripDetail(
        trip_id="trp_1",
        status=TripStatus.COMPLETED,
        started_at=now,
        start_location=NamedLocation(latitude=12.97, longitude=77.59),
        route=[],
    )
    res = client.get("/vehicles/XEV-001/trips/trp_1")
    assert res.status_code == 200
    assert res.json()["trip_id"] == "trp_1"


def test_get_trip_detail_route_404(api):
    client, service, _ = api
    service.get_trip_detail.side_effect = TripNotFoundError("Trip not found")
    res = client.get("/vehicles/XEV-001/trips/trp_missing")
    assert res.status_code == 404


def test_get_trip_service_fallback():
    request = MagicMock()
    del request.app.state.trip_service
    mock_db = MagicMock()
    request.app.state.database = mock_db
    svc = trip_routes.get_trip_service(request)
    assert svc is not None
