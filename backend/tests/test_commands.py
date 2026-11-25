from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
    VehicleOfflineError,
)
from backend.app.routes import commands as command_routes
from fastapi import FastAPI
from fastapi.testclient import TestClient

USER_ID = "507f1f77bcf86cd799439011"
VEHICLE_ID = "XEV9S-001"
COMMAND_ID = "command-123"


@pytest.fixture
def api(monkeypatch):
    service = MagicMock()
    app = FastAPI()
    app.include_router(command_routes.router)

    user = {"id": USER_ID}

    monkeypatch.setattr(
        command_routes,
        "get_command_service",
        lambda request: service,
    )
    app.dependency_overrides[get_current_user] = lambda: user

    with TestClient(app) as client:
        yield client, service, app


def sample_command():
    return {
        "command_id": COMMAND_ID,
        "vehicle_id": VEHICLE_ID,
        "operation": "lock",
        "status": "submitted",
        "requested_at": datetime.now(UTC).isoformat(),
        "completed_at": None,
        "failure_reason": None,
    }


def test_submit_command_success(api):
    client, service, _app = api
    service.submit_command.return_value = sample_command()

    response = client.post(
        f"/vehicles/{VEHICLE_ID}/commands",
        json={"operation": "lock"},
    )

    assert response.status_code == 202
    assert response.json()["command_id"] == COMMAND_ID
    service.submit_command.assert_called_once()


@pytest.mark.parametrize(
    ("error", "expected_status"),
    [
        (VehicleAccessDeniedError("Access denied"), 403),
        (VehicleNotActiveError("Vehicle inactive"), 404),
        (VehicleOfflineError("Vehicle offline"), 409),
        (MQTTUnavailableError("MQTT unavailable"), 503),
    ],
)
def test_submit_command_errors(api, error, expected_status):
    client, service, _app = api
    service.submit_command.side_effect = error

    response = client.post(
        f"/vehicles/{VEHICLE_ID}/commands",
        json={"operation": "lock"},
    )

    assert response.status_code == expected_status
    assert response.json()["detail"] == str(error)


def test_submit_command_invalid_request(api):
    client, service, _app = api

    response = client.post(
        f"/vehicles/{VEHICLE_ID}/commands",
        json={"operation": "invalid"},
    )

    assert response.status_code == 422
    service.submit_command.assert_not_called()


def test_get_command_history(api):
    client, service, _app = api
    service.get_commands.return_value = [sample_command()]

    response = client.get(f"/vehicles/{VEHICLE_ID}/commands")

    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["command_id"] == COMMAND_ID
    service.get_commands.assert_called_once_with(
        user_id=USER_ID,
        vehicle_id=VEHICLE_ID,
    )


def test_get_command_history_empty(api):
    client, service, _app = api
    service.get_commands.return_value = []

    response = client.get(f"/vehicles/{VEHICLE_ID}/commands")

    assert response.status_code == 200
    assert response.json() == []


def test_get_single_command(api):
    client, service, _app = api
    service.get_command.return_value = sample_command()

    response = client.get(
        f"/vehicles/{VEHICLE_ID}/commands/{COMMAND_ID}"
    )

    assert response.status_code == 200
    assert response.json()["command_id"] == COMMAND_ID


def test_get_single_command_not_found(api):
    client, service, _app = api
    service.get_command.return_value = None

    response = client.get(
        f"/vehicles/{VEHICLE_ID}/commands/{COMMAND_ID}"
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Command not found"


@pytest.mark.parametrize(
    ("error", "expected_status"),
    [
        (VehicleAccessDeniedError("Access denied"), 403),
        (VehicleNotActiveError("Vehicle inactive"), 404),
    ],
)
def test_get_command_errors(api, error, expected_status):
    client, service, _app = api
    service.get_command.side_effect = error

    response = client.get(
        f"/vehicles/{VEHICLE_ID}/commands/{COMMAND_ID}"
    )

    assert response.status_code == expected_status


def test_unauthenticated_command_request(api):
    client, service, app = api
    app.dependency_overrides.pop(get_current_user)

    response = client.get(f"/vehicles/{VEHICLE_ID}/commands")

    assert response.status_code == 401
    service.get_commands.assert_not_called()
