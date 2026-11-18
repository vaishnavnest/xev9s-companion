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


def test_register_success(service, mock_users):
    mock_users.get_user_by_email.return_value = None
    created_user = {
        "_id": "user-123",
        "email": "test@example.com",
        "full_name": "Test User",
        "is_active": True,
        "created_at": datetime.now(UTC),
    }
    mock_users.create_user.return_value = created_user

    result = service.register(
        email="test@example.com",
        password="ValidPassword123!",
        full_name="Test User",
    )

    assert result["id"] == "user-123"
    assert result["email"] == "test@example.com"
    assert result["full_name"] == "Test User"
    assert result["is_active"] is True
    mock_users.create_user.assert_called_once()


def test_register_duplicate_precheck(service, mock_users):
    mock_users.get_user_by_email.return_value = {"_id": "existing"}

    with pytest.raises(ValueError, match="An account with this email already exists"):
        service.register(
            email="existing@example.com",
            password="ValidPassword123!",
            full_name="Existing User",
        )
    mock_users.create_user.assert_not_called()


def test_register_duplicate_on_insert(service, mock_users):
    mock_users.get_user_by_email.return_value = None
    mock_users.create_user.side_effect = ValueError("Duplicate key")

    with pytest.raises(ValueError, match="An account with this email already exists"):
        service.register(
            email="existing@example.com",
            password="ValidPassword123!",
            full_name="Existing User",
        )


def test_login_success(service, mock_users, mock_sessions):
    hashed_pw = "hashed-password"
    user = {
        "_id": "user-123",
        "email": "test@example.com",
        "password_hash": hashed_pw,
        "is_active": True,
    }
    mock_users.get_user_by_email.return_value = user

    with patch("backend.app.services.auth_service.verify_password", return_value=True):
        tokens = service.login(email="test@example.com", password="Password123!")

    assert "access_token" in tokens
    assert "refresh_token" in tokens
    assert tokens["token_type"] == "bearer"
    assert tokens["expires_in"] == 900
    mock_sessions.create_session.assert_called_once()


def test_login_user_not_found(service, mock_users):
    mock_users.get_user_by_email.return_value = None

    with pytest.raises(ValueError, match="Incorrect email or password"):
        service.login(email="unknown@example.com", password="Password123!")


def test_login_wrong_password(service, mock_users):
    user = {
        "_id": "user-123",
        "email": "test@example.com",
        "password_hash": "hashed-pw",
        "is_active": True,
    }
    mock_users.get_user_by_email.return_value = user

    with (
        patch("backend.app.services.auth_service.verify_password", return_value=False),
        pytest.raises(ValueError, match="Incorrect email or password"),
    ):
        service.login(email="test@example.com", password="WrongPassword!")


def test_login_inactive_user(service, mock_users):
    user = {
        "_id": "user-123",
        "email": "test@example.com",
        "password_hash": "hashed-pw",
        "is_active": False,
    }
    mock_users.get_user_by_email.return_value = user

    with (
        patch("backend.app.services.auth_service.verify_password", return_value=True),
        pytest.raises(ValueError, match="Incorrect email or password"),
    ):
        service.login(email="test@example.com", password="Password123!")


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
    # Naive datetime without tzinfo
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
