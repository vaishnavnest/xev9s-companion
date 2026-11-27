from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, patch

import pytest
from backend.app.services.auth_service import AuthService


@pytest.fixture
def mock_users():
    return MagicMock()


@pytest.fixture
def mock_sessions():
    return MagicMock()


@pytest.fixture
def service(mock_users, mock_sessions):
    return AuthService(users=mock_users, sessions=mock_sessions)


def test_refresh_session_not_found(service, mock_sessions):
    mock_sessions.get_session_by_refresh_hash.return_value = None

    with pytest.raises(ValueError, match="Invalid or expired refresh token"):
        service.refresh("nonexistent-token")


def test_refresh_account_inactive_or_missing(service, mock_users, mock_sessions):
    token = "some-refresh-token"
    mock_sessions.get_session_by_refresh_hash.return_value = {
        "_id": "session-1",
        "user_id": "user-123",
        "refresh_token_hash": "matched-hash",
        "rotated_token_hashes": [],
        "expires_at": datetime.now(UTC) + timedelta(days=1),
        "revoked_at": None,
    }
    mock_sessions.rotate_refresh_token.return_value = True
    mock_users.get_user_by_id.return_value = None

    with (
        patch(
            "backend.app.services.auth_service.hash_refresh_token",
            return_value="matched-hash",
        ),
        pytest.raises(ValueError, match="Account is unavailable"),
    ):
        service.refresh(token)

    mock_sessions.revoke_session_by_id.assert_called_once_with("session-1")


def test_refresh_naive_datetime_handling(service, mock_users, mock_sessions):
    token = "some-refresh-token"
    naive_future = datetime.now() + timedelta(days=2)
    mock_sessions.get_session_by_refresh_hash.return_value = {
        "_id": "session-1",
        "user_id": "user-123",
        "refresh_token_hash": "matched-hash",
        "rotated_token_hashes": [],
        "expires_at": naive_future,
        "revoked_at": None,
    }
    mock_sessions.rotate_refresh_token.return_value = True
    mock_users.get_user_by_id.return_value = {
        "_id": "user-123",
        "is_active": True,
    }

    with patch(
        "backend.app.services.auth_service.hash_refresh_token",
        return_value="matched-hash",
    ):
        tokens = service.refresh(token)

    assert "access_token" in tokens
    assert "refresh_token" in tokens


def test_refresh_mismatched_current_hash(service, mock_sessions):
    token = "some-refresh-token"
    mock_sessions.get_session_by_refresh_hash.return_value = {
        "_id": "session-1",
        "user_id": "user-123",
        "refresh_token_hash": "other-hash",
        "rotated_token_hashes": [],
        "expires_at": datetime.now(UTC) + timedelta(days=1),
        "revoked_at": None,
    }

    with (
        patch(
            "backend.app.services.auth_service.hash_refresh_token",
            return_value="my-hash",
        ),
        pytest.raises(ValueError, match="Invalid refresh token"),
    ):
        service.refresh(token)


def test_logout_successful(service, mock_sessions):
    mock_sessions.get_session_by_refresh_hash.return_value = {
        "_id": "session-123",
        "revoked_at": None,
    }
    mock_sessions.revoke_session_by_id.return_value = True

    result = service.logout("refresh-token-123")
    assert result is True
    mock_sessions.revoke_session_by_id.assert_called_once_with("session-123")


def test_logout_session_not_found(service, mock_sessions):
    mock_sessions.get_session_by_refresh_hash.return_value = None

    result = service.logout("nonexistent-token")
    assert result is False
    mock_sessions.revoke_session_by_id.assert_not_called()


def test_logout_session_already_revoked(service, mock_sessions):
    mock_sessions.get_session_by_refresh_hash.return_value = {
        "_id": "session-123",
        "revoked_at": datetime.now(UTC),
    }

    result = service.logout("already-revoked-token")
    assert result is False
    mock_sessions.revoke_session_by_id.assert_not_called()
