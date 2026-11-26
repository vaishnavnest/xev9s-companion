from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.routes.commands import (
    get_command_service,
    handle_command_error,
)
from backend.app.routes.commands import router as commands_router
from backend.app.routes.telemetry import get_telemetry_service
from backend.app.routes.telemetry import router as telemetry_router
from backend.app.routes.vehicles import get_vehicle_service
from backend.app.services.vehicle_service import VehicleService
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient


def test_get_command_service_dependency():
    request = MagicMock()
    mock_service = object()
    request.app.state.command_service = mock_service

    assert get_command_service(request) is mock_service


def test_handle_command_error_value_error_and_unhandled():
    with pytest.raises(HTTPException) as exc_info:
        handle_command_error(ValueError("Invalid argument provided"))

    assert exc_info.value.status_code == 400
    assert exc_info.value.detail == "Invalid argument provided"

    with pytest.raises(RuntimeError):
        handle_command_error(RuntimeError("Unknown critical error"))


def test_get_vehicle_commands_route_exceptions():
    service = MagicMock()
    app = FastAPI()
    app.include_router(commands_router)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-01"}
    app.state.command_service = service

    with TestClient(app) as client:
        service.get_commands.side_effect = VehicleAccessDeniedError("Denied")
        res1 = client.get("/vehicles/XEV-001/commands")
        assert res1.status_code == 403
        assert res1.json()["detail"] == "Denied"

        service.get_commands.side_effect = VehicleNotActiveError("Not active")
        res2 = client.get("/vehicles/XEV-001/commands")
        assert res2.status_code == 404
        assert res2.json()["detail"] == "Not active"

        service.get_commands.side_effect = ValueError("Invalid parameter")
        res3 = client.get("/vehicles/XEV-001/commands")
        assert res3.status_code == 400
        assert res3.json()["detail"] == "Invalid parameter"


def test_get_telemetry_service_dependency():
    request = MagicMock()
    mock_service = object()
    request.app.state.telemetry_service = mock_service

    assert get_telemetry_service(request) is mock_service


def test_get_telemetry_history_access_denied_route():
    service = MagicMock()
    app = FastAPI()
    app.include_router(telemetry_router)
    app.dependency_overrides[get_current_user] = lambda: {"id": "user-01"}
    app.state.telemetry_service = service

    service.get_telemetry_history.side_effect = VehicleAccessDeniedError(
        "Access denied to history"
    )

    with TestClient(app) as client:
        res = client.get(
            "/vehicles/XEV-001/telemetry/history",
            params={
                "start_time": "2026-11-26T00:00:00Z",
                "end_time": "2026-11-26T01:00:00Z",
            },
        )
        assert res.status_code == 403
        assert res.json()["detail"] == "Access denied to history"


def test_get_vehicle_service_dependency():
    request = MagicMock()
    request.app.state.database = {
        "vehicles": MagicMock(),
        "user_vehicles": MagicMock(),
    }

    service = get_vehicle_service(request)
    assert isinstance(service, VehicleService)
