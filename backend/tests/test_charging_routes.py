
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    MQTTUnavailableError,
    VehicleAccessDeniedError,
)
from backend.app.routes import charging as charging_routes
from fastapi import FastAPI
from fastapi.testclient import TestClient


@pytest.fixture
def preferences():
    return {
        "vehicle_id": "XEV-DEMO-001",
        "target_percentage": 90.0,
        "schedule_enabled": False,
        "scheduled_start_time": None,
        "scheduled_end_time": None,
        "scheduled_days": [],
        "timezone": "Asia/Kolkata",
        "stop_charging_at_target": True,
    }


@pytest.fixture
def api(monkeypatch):
    service = MagicMock()
    app = FastAPI()
    app.include_router(charging_routes.router)

    user = {"id": "507f1f77bcf86cd799439011"}

    monkeypatch.setattr(
        charging_routes,
        "get_charging_service",
        lambda request: service,
    )
    app.dependency_overrides[get_current_user] = lambda: user

    yield TestClient(app), service, app


def test_get_charging_preferences(api, preferences):
    client, service, _app = api
    service.get_preferences.return_value = preferences

    response = client.get("/vehicles/XEV-DEMO-001/charging")

    assert response.status_code == 200
    assert response.json()["target_percentage"] == 90.0
    assert response.json()["vehicle_id"] == "XEV-DEMO-001"


def test_get_preferences_when_not_configured(api):
    client, service, _app = api
    service.get_preferences.return_value = None

    response = client.get("/vehicles/XEV-DEMO-001/charging")

    assert response.status_code == 200
    assert response.json() is None


def test_update_charging_preferences(api, preferences):
    client, service, _app = api
    service.update_preferences.return_value = preferences

    response = client.put(
        "/vehicles/XEV-DEMO-001/charging/preferences",
        json={key: value for key, value in preferences.items() if key != "vehicle_id"},
    )

    assert response.status_code == 200
    assert response.json()["target_percentage"] == 90.0
    service.update_preferences.assert_called_once()


def test_update_preferences_access_denied(api, preferences):
    client, service, _app = api
    service.update_preferences.side_effect = VehicleAccessDeniedError(
        "You do not have access to this vehicle"
    )

    response = client.put(
        "/vehicles/XEV-DEMO-001/charging/preferences",
        json={key: value for key, value in preferences.items() if key != "vehicle_id"},
    )

    assert response.status_code == 403


def test_update_preferences_mqtt_unavailable(api, preferences):
    client, service, _app = api
    service.update_preferences.side_effect = MQTTUnavailableError(
        "MQTT broker is disconnected"
    )

    response = client.put(
        "/vehicles/XEV-DEMO-001/charging/preferences",
        json={key: value for key, value in preferences.items() if key != "vehicle_id"},
    )

    assert response.status_code == 503


def test_get_charging_session_history(api):
    client, service, _app = api
    timestamp = datetime.now(UTC)

    service.get_session_history.return_value = [
        {
            "session_id": "session-001",
            "vehicle_id": "XEV-DEMO-001",
            "started_at": timestamp,
            "ended_at": None,
            "starting_battery_percentage": 30.0,
            "ending_battery_percentage": None,
            "target_percentage": 90.0,
            "final_target_percentage": 90.0,
            "charging_power_kw": 7.2,
            "average_charging_power_kw": 7.0,
            "peak_charging_power_kw": 7.2,
            "duration_seconds": 120.0,
            "status": "active",
            "interruption_reason": None,
        }
    ]

    response = client.get("/vehicles/XEV-DEMO-001/charging/sessions")

    assert response.status_code == 200
    assert response.json()["count"] == 1
    assert response.json()["sessions"][0]["session_id"] == "session-001"


def test_invalid_session_pagination(api):
    client, service, _app = api

    response = client.get(
        "/vehicles/XEV-DEMO-001/charging/sessions",
        params={"limit": 101},
    )

    assert response.status_code == 422
    service.get_session_history.assert_not_called()


def test_unauthenticated_charging_request(api):
    client, service, app = api
    app.dependency_overrides.pop(get_current_user)

    response = client.get("/vehicles/XEV-DEMO-001/charging")

    assert response.status_code == 401
    service.get_preferences.assert_not_called()
