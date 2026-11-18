from unittest.mock import MagicMock, patch

import pytest
from backend.app.core.database import (
    close_database_connection,
    connect_to_database,
)
from backend.app.core.indexes import ensure_database_indexes
from backend.app.main import app, database_health_check, health_check, lifespan, root
from fastapi import HTTPException
from pymongo.errors import ConnectionFailure, PyMongoError


def test_root_endpoint():
    response = root()
    assert response == {"message": "XEV 9S Backend is running"}


def test_health_check_endpoint():
    response = health_check()
    assert response == {"status": "healthy"}


def test_database_health_check_success():
    request = MagicMock()
    mock_db = MagicMock()
    request.app.state.database = mock_db
    mock_db.command.return_value = {"ok": 1}

    response = database_health_check(request)
    assert response == {"database": "connected"}
    mock_db.command.assert_called_once_with("ping")


def test_database_health_check_failure():
    request = MagicMock()
    mock_db = MagicMock()
    request.app.state.database = mock_db
    mock_db.command.side_effect = PyMongoError("Connection timeout")

    with pytest.raises(HTTPException) as exc_info:
        database_health_check(request)

    assert exc_info.value.status_code == 503
    assert exc_info.value.detail == "Database connection unavailable"


@pytest.mark.anyio
async def test_lifespan_lifecycle():
    fake_app = MagicMock()
    mock_db = MagicMock()

    with (
        patch(
            "backend.app.main.connect_to_database", return_value=mock_db
        ) as mock_connect,
        patch("backend.app.main.ensure_database_indexes") as mock_indexes,
        patch("backend.app.main.close_database_connection") as mock_close,
    ):
        async with lifespan(fake_app):
            assert fake_app.state.database == mock_db
            mock_connect.assert_called_once()
            mock_indexes.assert_called_once_with(mock_db)
            mock_close.assert_not_called()

        mock_close.assert_called_once()


def test_routes_registered_and_openapi():
    schema = app.openapi()
    assert "paths" in schema
    assert "/" in schema["paths"]
    assert "/health" in schema["paths"]
    assert "/health/database" in schema["paths"]
    assert "/auth/register" in schema["paths"]
    assert "/auth/login" in schema["paths"]


def test_ensure_database_indexes():
    mock_db = {
        "users": MagicMock(),
        "sessions": MagicMock(),
        "vehicles": MagicMock(),
        "user_vehicles": MagicMock(),
    }

    ensure_database_indexes(mock_db)

    mock_db["users"].create_index.assert_called_once()
    mock_db["sessions"].create_index.assert_called_once()


def test_connect_to_database_missing_env(monkeypatch):
    monkeypatch.setattr("backend.app.core.database.MONGODB_URI", None)
    monkeypatch.setattr("backend.app.core.database.MONGODB_DATABASE", None)

    with pytest.raises(ValueError, match="MongoDB environment variables are missing"):
        connect_to_database()


def test_connect_to_database_success_and_reuse(monkeypatch):
    monkeypatch.setattr(
        "backend.app.core.database.MONGODB_URI", "mongodb://localhost:27017"
    )
    monkeypatch.setattr("backend.app.core.database.MONGODB_DATABASE", "test_db")
    monkeypatch.setattr("backend.app.core.database.client", None)
    monkeypatch.setattr("backend.app.core.database.database", None)

    mock_client = MagicMock()
    mock_db = MagicMock()
    mock_client.__getitem__.return_value = mock_db
    mock_client.admin.command.return_value = {"ok": 1}

    with patch("backend.app.core.database.MongoClient", return_value=mock_client):
        db1 = connect_to_database()
        assert db1 == mock_db

        # Calling again should reuse cached connection
        db2 = connect_to_database()
        assert db2 == mock_db

    close_database_connection()


def test_connect_to_database_ping_failure(monkeypatch):
    monkeypatch.setattr(
        "backend.app.core.database.MONGODB_URI", "mongodb://localhost:27017"
    )
    monkeypatch.setattr("backend.app.core.database.MONGODB_DATABASE", "test_db")
    monkeypatch.setattr("backend.app.core.database.client", None)
    monkeypatch.setattr("backend.app.core.database.database", None)

    mock_client = MagicMock()
    mock_client.admin.command.side_effect = ConnectionFailure("Cannot connect")

    with patch("backend.app.core.database.MongoClient", return_value=mock_client):
        with pytest.raises(ConnectionFailure):
            connect_to_database()
        mock_client.close.assert_called_once()

    close_database_connection()
