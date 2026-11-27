from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import ChargingSessionNotFoundError
from backend.app.routes import charging as charging_routes
from fastapi import FastAPI
from fastapi.testclient import TestClient


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


def test_get_charging_session_history(api):
    client, service, _app = api
    timestamp = datetime.now(UTC)

    service.get_session_history.return_value = (
        [
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
        ],
        1,
    )

    response = client.get(
        "/vehicles/XEV-DEMO-001/charging/sessions",
        params={"status": "active", "page": 1, "page_size": 10},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert body["sessions"][0]["session_id"] == "session-001"
    assert body["pagination"] == {
        "page": 1,
        "page_size": 10,
        "total_items": 1,
        "total_pages": 1,
    }


def test_invalid_session_pagination(api):
    client, service, _app = api

    response = client.get(
        "/vehicles/XEV-DEMO-001/charging/sessions",
        params={"limit": 101},
    )

    assert response.status_code == 422
    service.get_session_history.assert_not_called()


def test_get_charging_session_detail(api):
    client, service, _app = api
    timestamp = datetime.now(UTC)
    service.get_session_detail.return_value = {
        "session_id": "session-001",
        "vehicle_id": "XEV-DEMO-001",
        "started_at": timestamp,
        "ended_at": None,
        "starting_battery_percentage": 30.0,
        "ending_battery_percentage": 50.0,
        "target_percentage": 90.0,
        "final_target_percentage": 90.0,
        "charging_power_kw": 7.2,
        "average_charging_power_kw": 7.0,
        "peak_charging_power_kw": 7.2,
        "duration_seconds": 120.0,
        "status": "active",
        "interruption_reason": None,
    }

    response = client.get("/vehicles/XEV-DEMO-001/charging/sessions/session-001")

    assert response.status_code == 200
    assert response.json()["session_id"] == "session-001"


def test_get_charging_session_detail_not_found(api):
    client, service, _app = api
    service.get_session_detail.side_effect = ChargingSessionNotFoundError(
        "Session not found"
    )

    response = client.get("/vehicles/XEV-DEMO-001/charging/sessions/missing")

    assert response.status_code == 404
