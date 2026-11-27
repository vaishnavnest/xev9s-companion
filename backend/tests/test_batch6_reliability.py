from datetime import UTC, datetime
from unittest.mock import MagicMock, patch

import pytest
from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.core import security
from backend.app.routes import websocket as ws_routes
from backend.app.services.auth_service import AuthService
from backend.app.services.command_timeout_manager import CommandTimeoutManager
from backend.app.services.geocoding_service import GeocodingService
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pymongo.errors import PyMongoError
from starlette.websockets import WebSocketDisconnect


@pytest.mark.parametrize("minutes", [5, 15, 30])
def test_auth_expires_in_matches_configured_minutes(monkeypatch, minutes):
    monkeypatch.setattr(security, "ACCESS_TOKEN_EXPIRE_MINUTES", minutes)
    service = AuthService(users=MagicMock(), sessions=MagicMock())
    tokens = service._token_response({"_id": "507f1f77bcf86cd799439011"}, "ref")
    assert tokens["expires_in"] == minutes * 60


def test_websocket_auth_timeout_closes_with_1008(monkeypatch):
    monkeypatch.setattr(ws_routes, "WS_AUTH_TIMEOUT_SECONDS", 0.05)
    app = FastAPI()
    app.include_router(ws_routes.router)
    app.state.database = {
        "users": object(),
        "vehicles": object(),
        "user_vehicles": object(),
    }
    app.state.websocket_manager = WebSocketManager()

    with (
        TestClient(app) as client,
        client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
        pytest.raises(WebSocketDisconnect) as exc,
    ):
        websocket.receive_text()

    assert exc.value.code == 1008


def test_websocket_database_error_closes_with_1011():
    app = FastAPI()
    app.include_router(ws_routes.router)
    app.state.database = {
        "users": object(),
        "vehicles": object(),
        "user_vehicles": object(),
    }
    app.state.websocket_manager = WebSocketManager()

    with (
        patch(
            "backend.app.routes.websocket.decode_access_token",
            return_value={"sub": "user123"},
        ),
        patch("backend.app.routes.websocket.UserRepository") as user_repo,
        TestClient(app) as client,
    ):
        user_repo.return_value.get_user_by_id.side_effect = PyMongoError("down")
        with (
            client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
            pytest.raises(WebSocketDisconnect) as exc,
        ):
            websocket.send_json({"token": "valid"})
            websocket.receive_text()

    assert exc.value.code == 1011


def test_geocoding_service_shutdown_closes_owned_executor():
    service = GeocodingService()
    assert service._executor._shutdown is False
    service.shutdown(wait=True)
    assert service._executor._shutdown is True

    external_executor = MagicMock()
    borrowed = GeocodingService(executor=external_executor)
    borrowed.shutdown(wait=True)
    external_executor.shutdown.assert_not_called()


def test_command_timeout_manager_notifies_only_once_on_transition():
    repo = MagicMock()
    repo.mark_command_timed_out.side_effect = [True, False]
    repo.get_command_for_response.return_value = {
        "command_id": "cmd-1",
        "vehicle_id": "XEV-001",
        "operation": "lock",
        "requested_at": datetime.now(UTC),
        "failure_reason": "Command execution timed out",
    }
    notifications = []
    manager = CommandTimeoutManager(repo, on_command_timed_out=notifications.append)

    manager._expire("cmd-1", "XEV-001")
    manager._expire("cmd-1", "XEV-001")

    assert len(notifications) == 1
    assert notifications[0]["event"] == "command_updated"
    assert notifications[0]["status"] == "timed_out"
