from unittest.mock import MagicMock

import pytest
from backend.app.models.session import create_session_document
from backend.app.repositories.session_repository import SessionRepository
from bson import ObjectId


@pytest.fixture
def mock_collection():
    return MagicMock()


@pytest.fixture
def repo(mock_collection):
    return SessionRepository(mock_collection)


def test_create_session_document_fields():
    doc = create_session_document(
        user_id="user_123",
        refresh_token_hash="hash_abc",
        expires_in_days=7,
    )
    assert doc["user_id"] == "user_123"
    assert doc["refresh_token_hash"] == "hash_abc"
    assert doc["rotated_token_hashes"] == []
    assert doc["revoked_at"] is None
    assert doc["expires_at"] > doc["created_at"]


def test_create_session(repo, mock_collection):
    fake_id = ObjectId()
    mock_collection.insert_one.return_value = MagicMock(inserted_id=fake_id)

    session = repo.create_session(
        user_id="user-456",
        refresh_token_hash="token-hash-123",
        expires_in_days=14,
    )

    assert session["_id"] == fake_id
    assert session["user_id"] == "user-456"
    assert session["refresh_token_hash"] == "token-hash-123"
    mock_collection.insert_one.assert_called_once()


def test_get_session_by_refresh_hash(repo, mock_collection):
    expected_session = {"_id": "session_1", "user_id": "user-456"}
    mock_collection.find_one.return_value = expected_session

    session = repo.get_session_by_refresh_hash("token-hash-123")
    assert session == expected_session

    query = mock_collection.find_one.call_args[0][0]
    assert "$or" in query
    assert {"refresh_token_hash": "token-hash-123"} in query["$or"]
    assert {"rotated_token_hashes": "token-hash-123"} in query["$or"]


def test_get_session_by_refresh_hash_not_found(repo, mock_collection):
    mock_collection.find_one.return_value = None

    session = repo.get_session_by_refresh_hash("nonexistent-hash")
    assert session is None


def test_get_active_session_found(repo, mock_collection):
    expected_session = {"_id": "session_1", "revoked_at": None}
    mock_collection.find_one.return_value = expected_session

    session = repo.get_active_session("token-hash-123")
    assert session == expected_session
    query = mock_collection.find_one.call_args[0][0]
    assert query["refresh_token_hash"] == "token-hash-123"
    assert query["revoked_at"] is None
    assert "$gt" in query["expires_at"]


def test_get_active_session_not_found(repo, mock_collection):
    mock_collection.find_one.return_value = None

    session = repo.get_active_session("expired-or-revoked-hash")
    assert session is None


def test_rotate_refresh_token_success(repo, mock_collection):
    mock_collection.update_one.return_value = MagicMock(modified_count=1)

    success = repo.rotate_refresh_token(
        session_id="session-1",
        old_token_hash="old-hash",
        new_token_hash="new-hash",
        expires_in_days=7,
    )
    assert success is True
    mock_collection.update_one.assert_called_once()


def test_rotate_refresh_token_failure(repo, mock_collection):
    mock_collection.update_one.return_value = MagicMock(modified_count=0)

    success = repo.rotate_refresh_token(
        session_id="session-1",
        old_token_hash="old-hash",
        new_token_hash="new-hash",
        expires_in_days=7,
    )
    assert success is False


def test_revoke_session_success(repo, mock_collection):
    mock_collection.update_one.return_value = MagicMock(modified_count=1)

    revoked = repo.revoke_session("session-1", "token-hash-123")
    assert revoked is True


def test_revoke_session_failure(repo, mock_collection):
    mock_collection.update_one.return_value = MagicMock(modified_count=0)

    revoked = repo.revoke_session("session-1", "wrong-hash")
    assert revoked is False


def test_revoke_session_by_id_success(repo, mock_collection):
    mock_collection.update_one.return_value = MagicMock(modified_count=1)

    revoked = repo.revoke_session_by_id("session-1")
    assert revoked is True


def test_revoke_session_by_id_failure(repo, mock_collection):
    mock_collection.update_one.return_value = MagicMock(modified_count=0)

    revoked = repo.revoke_session_by_id("nonexistent-session")
    assert revoked is False
