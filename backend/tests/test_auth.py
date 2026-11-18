from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.dependencies import get_current_user
from backend.app.routes import auth as auth_routes
from fastapi import FastAPI
from fastapi.testclient import TestClient


@pytest.fixture
def api(monkeypatch):
    service = MagicMock()
    app = FastAPI()
    app.include_router(auth_routes.router)

    user = {
        "id": "test-user-id",
        "email": "test@example.com",
        "full_name": "Test User",
        "is_active": True,
        "created_at": datetime.now(UTC),
    }

    monkeypatch.setattr(
        auth_routes,
        "get_auth_service",
        lambda request: service,
    )

    app.dependency_overrides[get_current_user] = lambda: user

    client = TestClient(app)
    yield client, service


def test_register(api):
    client, service = api
    service.register.return_value = {
        "id": "test-user-id",
        "email": "test@example.com",
        "full_name": "Test User",
        "is_active": True,
        "created_at": datetime.now(UTC),
    }

    response = client.post(
        "/auth/register",
        json={
            "full_name": "Test User",
            "email": "test@example.com",
            "password": "StrongPassword123!",
            "confirm_password": "StrongPassword123!",
        },
    )

    assert response.status_code == 201
    assert response.json()["email"] == "test@example.com"
    assert "password_hash" not in response.json()


def test_register_duplicate_user(api):
    client, service = api
    service.register.side_effect = ValueError(
        "An account with this email already exists"
    )

    response = client.post(
        "/auth/register",
        json={
            "full_name": "Test User",
            "email": "test@example.com",
            "password": "StrongPassword123!",
            "confirm_password": "StrongPassword123!",
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "An account with this email already exists"


def test_register_password_mismatch(api):
    client, service = api

    response = client.post(
        "/auth/register",
        json={
            "full_name": "Test User",
            "email": "test@example.com",
            "password": "StrongPassword123!",
            "confirm_password": "DifferentPassword123!",
        },
    )

    assert response.status_code == 422
    service.register.assert_not_called()


def test_login(api):
    client, service = api
    service.login.return_value = {
        "access_token": "test-access-token",
        "refresh_token": "test-refresh-token",
        "token_type": "bearer",
        "expires_in": 900,
    }

    response = client.post(
        "/auth/login",
        json={
            "email": "test@example.com",
            "password": "StrongPassword123!",
        },
    )

    assert response.status_code == 200
    assert response.json()["access_token"] == "test-access-token"


def test_login_incorrect_credentials(api):
    client, service = api
    service.login.side_effect = ValueError("Incorrect email or password")

    response = client.post(
        "/auth/login",
        json={
            "email": "test@example.com",
            "password": "WrongPassword123!",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect email or password"


def test_refresh(api):
    client, service = api
    service.refresh.return_value = {
        "access_token": "new-access-token",
        "refresh_token": "new-refresh-token",
        "token_type": "bearer",
        "expires_in": 900,
    }

    response = client.post(
        "/auth/refresh",
        json={
            "refresh_token": "old-refresh-token",
        },
    )

    assert response.status_code == 200
    assert response.json()["refresh_token"] == "new-refresh-token"


def test_refresh_invalid_token(api):
    client, service = api
    service.refresh.side_effect = ValueError("Invalid or expired refresh token")

    response = client.post(
        "/auth/refresh",
        json={
            "refresh_token": "invalid-token",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or expired refresh token"


def test_logout(api):
    client, _service = api

    response = client.post(
        "/auth/logout",
        json={
            "refresh_token": "test-refresh-token",
        },
    )

    assert response.status_code == 200
    assert response.json()["message"] == "Logged out successfully"


def test_logout_failure(api):
    client, service = api
    service.logout.return_value = False

    response = client.post(
        "/auth/logout",
        json={
            "refresh_token": "already-revoked-token",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or already revoked refresh token"


def test_get_auth_service():
    request = MagicMock()
    request.app.state.database = {
        "users": MagicMock(),
        "sessions": MagicMock(),
    }
    svc = auth_routes.get_auth_service(request)
    assert svc is not None
    assert svc.users is not None
    assert svc.sessions is not None


def test_get_profile(api):
    client, _service = api

    response = client.get(
        "/auth/me",
        headers={"Authorization": "Bearer test-access-token"},
    )

    assert response.status_code == 200
    assert response.json()["email"] == "test@example.com"
    assert "password_hash" not in response.json()
