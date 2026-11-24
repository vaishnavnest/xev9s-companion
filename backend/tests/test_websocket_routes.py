
from unittest.mock import patch

import pytest
from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.routes.websocket import router
from fastapi import FastAPI
from fastapi.testclient import TestClient
from jwt import InvalidTokenError
from starlette.websockets import WebSocketDisconnect


@pytest.fixture
def app():
    application = FastAPI()
    application.include_router(router)
    application.state.database = {
        "users": object(),
        "vehicles": object(),
        "user_vehicles": object(),
    }
    application.state.websocket_manager = WebSocketManager()
    return application


def test_websocket_rejects_invalid_token(app):
    with (
        patch(
            "backend.app.routes.websocket.decode_access_token",
            side_effect=InvalidTokenError,
        ),
        TestClient(app) as client,
        client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
        pytest.raises(WebSocketDisconnect) as error,
    ):
        websocket.send_json({"token": "invalid"})
        websocket.receive_text()

    assert error.value.code == 1008

def test_websocket_rejects_missing_token(app):
    with (
        TestClient(app) as client,
        client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
        pytest.raises(WebSocketDisconnect) as error,
    ):
        websocket.send_json({})
        websocket.receive_text()

    assert error.value.code == 1008


def test_websocket_rejects_inactive_user(app):
    with (
        patch(
            "backend.app.routes.websocket.decode_access_token",
            return_value={"sub": "user123"},
        ),
        patch(
            "backend.app.routes.websocket.UserRepository"
        ) as user_repository,
        TestClient(app) as client,
    ):
        user_repository.return_value.get_user_by_id.return_value = {
            "is_active": False,
        }

        with (
            client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
            pytest.raises(WebSocketDisconnect) as error,
        ):
            websocket.send_json({"token": "valid"})
            websocket.receive_text()

    assert error.value.code == 1008


def test_websocket_rejects_unassociated_vehicle(app):
    with (
        patch(
            "backend.app.routes.websocket.decode_access_token",
            return_value={"sub": "user123"},
        ),
        patch(
            "backend.app.routes.websocket.UserRepository"
        ) as user_repository,
        patch(
            "backend.app.routes.websocket.VehicleRepository"
        ) as vehicle_repository,
        TestClient(app) as client,
    ):
        user_repository.return_value.get_user_by_id.return_value = {
            "is_active": True,
        }
        vehicle_repository.return_value.is_vehicle_associated_with_user.return_value = False

        with (
            client.websocket_connect("/ws/vehicles/XEV-001") as websocket,
            pytest.raises(WebSocketDisconnect) as error,
        ):
            websocket.send_json({"token": "valid"})
            websocket.receive_text()

    assert error.value.code == 1008


def test_websocket_registers_authenticated_user(app):
    with (
        patch(
            "backend.app.routes.websocket.decode_access_token",
            return_value={"sub": "user123"},
        ),
        patch(
            "backend.app.routes.websocket.UserRepository"
        ) as user_repository,
        patch(
            "backend.app.routes.websocket.VehicleRepository"
        ) as vehicle_repository,
        TestClient(app) as client,
    ):
        user_repository.return_value.get_user_by_id.return_value = {
            "is_active": True,
        }
        vehicle_repository.return_value.is_vehicle_associated_with_user.return_value = True

        manager = app.state.websocket_manager

        with client.websocket_connect(
            "/ws/vehicles/XEV-001"
        ) as websocket:
            websocket.send_json({"token": "valid"})
            websocket.send_text("keepalive")

        assert not manager._connections
