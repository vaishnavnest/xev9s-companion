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
        json={"refresh_token": "old-refresh-token"},
    )

    assert response.status_code == 200
    assert response.json()["refresh_token"] == "new-refresh-token"


def test_refresh_invalid_token(api):
    client, service = api
    service.refresh.side_effect = ValueError("Invalid or expired refresh token")

    response = client.post(
        "/auth/refresh",
        json={"refresh_token": "invalid-token"},
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or expired refresh token"


def test_logout(api):
    client, _service = api

    response = client.post(
        "/auth/logout",
        json={"refresh_token": "test-refresh-token"},
    )

    assert response.status_code == 200
    assert response.json()["message"] == "Logged out successfully"


def test_logout_failure(api):
    client, service = api
    service.logout.return_value = False

    response = client.post(
        "/auth/logout",
        json={"refresh_token": "already-revoked-token"},
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
