
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    InvalidPairingCodeError,
    VehicleAlreadyAssociatedError,
)
from backend.app.routes import vehicles as vehicle_routes
from fastapi import FastAPI
from fastapi.testclient import TestClient


@pytest.fixture
def api(monkeypatch):
    service = MagicMock()
    app = FastAPI()
    app.include_router(vehicle_routes.router)

    user = {
        "id": "507f1f77bcf86cd799439011",
        "email": "test@example.com",
        "full_name": "Test User",
        "is_active": True,
        "created_at": datetime.now(UTC),
    }

    monkeypatch.setattr(
        vehicle_routes,
        "get_vehicle_service",
        lambda request: service,
    )

    app.dependency_overrides[get_current_user] = lambda: user

    client = TestClient(app)
    yield client, service, app


def test_get_vehicles(api):
    client, service, _app = api

    service.get_user_vehicles.return_value = [
        {
            "vehicle_id": "XEV9S-001",
            "model": "XEV 9S",
            "association_status": "active",
            "associated_at": datetime.now(UTC),
        }
    ]

    response = client.get("/vehicles")

    assert response.status_code == 200
    assert len(response.json()["vehicles"]) == 1
    assert response.json()["vehicles"][0]["vehicle_id"] == "XEV9S-001"
    service.get_user_vehicles.assert_called_once_with(
        "507f1f77bcf86cd799439011"
    )


def test_get_vehicles_empty_list(api):
    client, service, _app = api
    service.get_user_vehicles.return_value = []

    response = client.get("/vehicles")

    assert response.status_code == 200
    assert response.json() == {"vehicles": []}


def test_associate_vehicle_success(api):
    client, service, _app = api

    associated_vehicle = {
        "vehicle_id": "XEV9S-001",
        "model": "XEV 9S",
        "association_status": "active",
        "associated_at": datetime.now(UTC),
    }
    service.get_user_vehicles.return_value = [associated_vehicle]

    response = client.post(
        "/vehicles/associate",
        json={
            "vehicle_id": "XEV9S-001",
            "pairing_code": "TEST-CODE-123",
        },
    )

    assert response.status_code == 201
    assert len(response.json()["vehicles"]) == 1
    assert response.json()["vehicles"][0]["vehicle_id"] == "XEV9S-001"
    assert response.json()["vehicles"][0]["model"] == "XEV 9S"

    service.associate_vehicle.assert_called_once_with(
        user_id="507f1f77bcf86cd799439011",
        vehicle_id="XEV9S-001",
        pairing_code="TEST-CODE-123",
    )
    service.get_user_vehicles.assert_called_once_with(
        "507f1f77bcf86cd799439011"
    )


def test_associate_vehicle_invalid_pairing_code(api):
    client, service, _app = api
    service.associate_vehicle.side_effect = InvalidPairingCodeError(
        "Invalid, expired, or already-used pairing code"
    )

    response = client.post(
        "/vehicles/associate",
        json={
            "vehicle_id": "XEV9S-001",
            "pairing_code": "INVALID-CODE",
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Invalid, expired, or already-used pairing code"
    )
    service.get_user_vehicles.assert_not_called()


def test_associate_vehicle_already_associated(api):
    client, service, _app = api
    service.associate_vehicle.side_effect = VehicleAlreadyAssociatedError(
        "Vehicle is already associated with this account"
    )

    response = client.post(
        "/vehicles/associate",
        json={
            "vehicle_id": "XEV9S-001",
            "pairing_code": "TEST-CODE-123",
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == (
        "Vehicle is already associated with this account"
    )
    service.get_user_vehicles.assert_not_called()


def test_associate_vehicle_invalid_request(api):
    client, service, _app = api

    response = client.post(
        "/vehicles/associate",
        json={
            "vehicle_id": "   ",
            "pairing_code": "TEST-CODE-123",
        },
    )

    assert response.status_code == 422
    service.associate_vehicle.assert_not_called()


def test_unauthenticated_vehicle_request(api):
    client, service, app = api

    app.dependency_overrides.pop(get_current_user)

    response = client.get("/vehicles")

    assert response.status_code == 401
    service.get_user_vehicles.assert_not_called()
