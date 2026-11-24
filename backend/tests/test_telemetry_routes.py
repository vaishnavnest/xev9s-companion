
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import VehicleAccessDeniedError
from backend.app.routes import telemetry as telemetry_routes
from fastapi import FastAPI
from fastapi.testclient import TestClient


@pytest.fixture
def telemetry_record():
    timestamp = datetime.now(UTC)
    return {
        "_id": "internal-database-id",
        "vehicle_id": "XEV-DEMO-001",
        "timestamp": timestamp,
        "battery_percentage": 80.0,
        "estimated_range_km": 300.0,
        "speed_kph": 0.0,
        "odometer_km": 0.0,
        "latitude": None,
        "longitude": None,
        "operating_state": "parked",
        "is_locked": True,
        "charging_status": "disconnected",
        "charging_power_kw": 0.0,
        "cabin_preconditioning_active": False,
        "received_at": timestamp,
    }


@pytest.fixture
def api(monkeypatch):
    service = MagicMock()
    app = FastAPI()
    app.include_router(telemetry_routes.router)

    user = {"id": "507f1f77bcf86cd799439011"}

    monkeypatch.setattr(
        telemetry_routes,
        "get_telemetry_service",
        lambda request: service,
    )
    app.dependency_overrides[get_current_user] = lambda: user

    yield TestClient(app), service, app


def test_get_latest_telemetry(api, telemetry_record):
    client, service, _app = api
    service.get_latest_telemetry.return_value = telemetry_record

    response = client.get(
        "/vehicles/XEV-DEMO-001/telemetry/latest"
    )

    assert response.status_code == 200
    assert response.json()["vehicle_id"] == "XEV-DEMO-001"
    assert response.json()["battery_percentage"] == 80.0
    assert "_id" not in response.json()


def test_latest_telemetry_not_found(api):
    client, service, _app = api
    service.get_latest_telemetry.return_value = None

    response = client.get(
        "/vehicles/XEV-DEMO-001/telemetry/latest"
    )

    assert response.status_code == 404


def test_latest_telemetry_access_denied(api):
    client, service, _app = api
    service.get_latest_telemetry.side_effect = VehicleAccessDeniedError(
        "You do not have access to this vehicle"
    )

    response = client.get(
        "/vehicles/XEV-DEMO-001/telemetry/latest"
    )

    assert response.status_code == 403


def test_get_telemetry_history(api, telemetry_record):
    client, service, _app = api
    service.get_telemetry_history.return_value = [telemetry_record]

    response = client.get(
        "/vehicles/XEV-DEMO-001/telemetry/history",
        params={
            "start_time": "2026-11-23T00:00:00+00:00",
            "end_time": "2026-11-24T00:00:00+00:00",
            "limit": 50,
        },
    )

    assert response.status_code == 200
    assert response.json()["count"] == 1
    assert len(response.json()["telemetry"]) == 1
    assert response.json()["telemetry"][0]["vehicle_id"] == (
        "XEV-DEMO-001"
    )


def test_telemetry_history_invalid_time_range(api):
    client, service, _app = api
    service.get_telemetry_history.side_effect = ValueError(
        "Start time must be before end time"
    )

    response = client.get(
        "/vehicles/XEV-DEMO-001/telemetry/history",
        params={
            "start_time": "2026-11-24T00:00:00+00:00",
            "end_time": "2026-11-23T00:00:00+00:00",
        },
    )

    assert response.status_code == 422


def test_telemetry_history_invalid_limit(api):
    client, service, _app = api

    response = client.get(
        "/vehicles/XEV-DEMO-001/telemetry/history",
        params={
            "start_time": "2026-11-23T00:00:00+00:00",
            "end_time": "2026-11-24T00:00:00+00:00",
            "limit": 1001,
        },
    )

    assert response.status_code == 422
    service.get_telemetry_history.assert_not_called()


def test_unauthenticated_telemetry_request(api):
    client, service, app = api
    app.dependency_overrides.pop(get_current_user)

    response = client.get(
        "/vehicles/XEV-DEMO-001/telemetry/latest"
    )

    assert response.status_code == 401
    service.get_latest_telemetry.assert_not_called()
