
from datetime import datetime, timezone
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.core.security import create_access_token
from backend.app.repositories.user_repository import UserRepository
from backend.app.routes.auth import router


@pytest.fixture
def client(monkeypatch):
    user = {
        "_id": "test-user-id",
        "email": "test@example.com",
        "full_name": "Test User",
        "is_active": True,
        "created_at": datetime.now(timezone.utc),
    }

    monkeypatch.setattr(
        UserRepository,
        "get_user_by_id",
        lambda self, user_id: user,
    )

    app = FastAPI()
    app.state.database = {"users": MagicMock()}
    app.include_router(router)

    return TestClient(app)


def test_valid_access_token(client):
    token = create_access_token("test-user-id")

    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    assert response.json()["email"] == "test@example.com"


def test_missing_access_token(client):
    response = client.get("/auth/me")

    assert response.status_code == 401


def test_invalid_access_token(client):
    response = client.get(
        "/auth/me",
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401


def test_inactive_user_rejected(client, monkeypatch):
    monkeypatch.setattr(
        UserRepository,
        "get_user_by_id",
        lambda self, user_id: {
            "_id": "test-user-id",
            "email": "test@example.com",
            "full_name": "Test User",
            "is_active": False,
            "created_at": datetime.now(timezone.utc),
        },
    )

    token = create_access_token("test-user-id")

    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401
