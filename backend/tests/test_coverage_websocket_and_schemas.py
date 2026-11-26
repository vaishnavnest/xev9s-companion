from datetime import datetime
from unittest.mock import patch

import pytest
from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.routes.websocket import router as websocket_router
from backend.app.schemas.telemetry import TelemetryPayload
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from starlette.websockets import WebSocketDisconnect


@pytest.fixture
def ws_app():
    application = FastAPI()
    application.include_router(websocket_router)
    application.state.database = {
        "users": object(),
        "vehicles": object(),
        "user_vehicles": object(),
    }
    application.state.websocket_manager = WebSocketManager()
    return application


def test_websocket_rejects_non_dict_credentials(ws_app):
    with (
        TestClient(ws_app) as client,
        client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
        pytest.raises(WebSocketDisconnect) as error,
    ):
        websocket.send_json(["not_a_dictionary"])
        websocket.receive_text()

    assert error.value.code == 1008


def test_websocket_rejects_missing_sub_claim(ws_app):
    with (
        patch(
            "backend.app.routes.websocket.decode_access_token",
            return_value={"sub": None},
        ),
        TestClient(ws_app) as client,
        client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
        pytest.raises(WebSocketDisconnect) as error,
    ):
        websocket.send_json({"token": "token_without_sub"})
        websocket.receive_text()

    assert error.value.code == 1008


def test_telemetry_payload_rejects_naive_timestamp():
    naive_dt = datetime(2026, 11, 26, 12, 0, 0)

    with pytest.raises(
        ValidationError,
        match="Telemetry timestamp must include a timezone",
    ):
        TelemetryPayload(
            vehicle_id="XEV-001",
            timestamp=naive_dt,
            battery_percentage=80.0,
            estimated_range_km=300.0,
            speed_kph=0.0,
            odometer_km=1000.0,
            operating_state="parked",
            is_locked=True,
            charging_status="disconnected",
            charging_power_kw=0.0,
            cabin_preconditioning_active=False,
        )
