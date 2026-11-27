from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.routes import location as location_routes
from backend.app.schemas.location import VehicleLocationResponse
from fastapi import FastAPI
from fastapi.testclient import TestClient


@pytest.fixture
def api(monkeypatch):
    service = MagicMock()
    app = FastAPI()
    app.include_router(location_routes.router)

    user = {"id": "507f1f77bcf86cd799439011"}

    monkeypatch.setattr(
        location_routes,
        "get_location_service",
        lambda request: service,
    )
    app.dependency_overrides[get_current_user] = lambda: user

    yield TestClient(app), service, app


def test_get_location_success(api):
    client, service, _app = api
    timestamp = datetime.now(UTC)
    service.get_vehicle_location.return_value = VehicleLocationResponse(
        vehicle_id="XEV-DEMO-001",
        latitude=12.9716,
        longitude=77.5946,
        timestamp=timestamp,
        is_current=True,
        connectivity_status="online",
        operating_state="parked",
    )

    response = client.get("/vehicles/XEV-DEMO-001/location")

    assert response.status_code == 200
    data = response.json()
    assert data["vehicle_id"] == "XEV-DEMO-001"
    assert data["latitude"] == 12.9716
    assert data["longitude"] == 77.5946
    assert data["is_current"] is True
    assert data["connectivity_status"] == "online"
    assert data["operating_state"] == "parked"


def test_get_location_no_gps_history_200(api):
    client, service, _app = api
    service.get_vehicle_location.return_value = VehicleLocationResponse(
        vehicle_id="XEV-DEMO-001",
        latitude=None,
        longitude=None,
        timestamp=None,
        is_current=False,
        connectivity_status="online",
    )

    response = client.get("/vehicles/XEV-DEMO-001/location")

    assert response.status_code == 200
    data = response.json()
    assert data["latitude"] is None
    assert data["longitude"] is None
    assert data["timestamp"] is None
    assert data["is_current"] is False
    assert data["connectivity_status"] == "online"


def test_get_location_access_denied_403(api):
    client, service, _app = api
    service.get_vehicle_location.side_effect = VehicleAccessDeniedError(
        "You do not have access to this vehicle"
    )

    response = client.get("/vehicles/XEV-FORBIDDEN/location")

    assert response.status_code == 403
    assert "You do not have access" in response.json()["detail"]


def test_get_location_unknown_vehicle_404(api):
    client, service, _app = api
    service.get_vehicle_location.side_effect = VehicleNotActiveError(
        "Vehicle is not registered or active"
    )

    response = client.get("/vehicles/UNKNOWN/location")

    assert response.status_code == 404
    assert "not registered or active" in response.json()["detail"]


def test_get_location_value_error_400(api):
    client, service, _app = api
    service.get_vehicle_location.side_effect = ValueError(
        "Vehicle identifier cannot be empty"
    )

    response = client.get("/vehicles/invalid/location")

    assert response.status_code == 400
    assert "cannot be empty" in response.json()["detail"]


def test_get_location_service_fallback():
    mock_app = FastAPI()
    mock_app.state.database = {
        "vehicles": MagicMock(),
        "user_vehicles": MagicMock(),
        "vehicle_telemetry": MagicMock(),
    }
    request = MagicMock()
    request.app = mock_app

    service = location_routes.get_location_service(request)
    assert service is not None


def test_get_location_service_from_state():
    mock_app = FastAPI()
    expected_service = MagicMock()
    mock_app.state.location_service = expected_service
    request = MagicMock()
    request.app = mock_app

    service = location_routes.get_location_service(request)
    assert service == expected_service


def test_get_location_unauthenticated():
    app = FastAPI()
    app.include_router(location_routes.router)

    client = TestClient(app)

    response = client.get("/vehicles/XEV-DEMO-001/location")

    assert response.status_code == 401
