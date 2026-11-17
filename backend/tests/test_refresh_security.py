
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import pytest

from backend.app.core.security import hash_refresh_token
from backend.app.services import auth_service


@pytest.fixture
def setup_service(monkeypatch):
    users = MagicMock()
    sessions = MagicMock()
    service = auth_service.AuthService(users, sessions)

    old_token = "old-refresh-token"
    old_hash = hash_refresh_token(old_token)

    session = {
        "_id": "session-123",
        "user_id": "user-123",
        "refresh_token_hash": old_hash,
        "rotated_token_hashes": [],
        "expires_at": datetime.now(timezone.utc)
        + timedelta(days=7),
        "revoked_at": None,
    }

    user = {
        "_id": "user-123",
        "email": "test@example.com",
        "full_name": "Test User",
        "is_active": True,
    }

    sessions.get_session_by_refresh_hash.return_value = session
    sessions.rotate_refresh_token.return_value = True
    users.get_user_by_id.return_value = user

    monkeypatch.setattr(
        auth_service,
        "generate_refresh_token",
        lambda: "new-refresh-token",
    )
    monkeypatch.setattr(
        auth_service,
        "create_access_token",
        lambda user_id: "new-access-token",
    )

    return service, users, sessions, session, old_token


def test_successful_refresh(setup_service):
    service, users, sessions, session, old_token = setup_service

    result = service.refresh(old_token)

    assert result["refresh_token"] == "new-refresh-token"
    assert result["access_token"] == "new-access-token"
    sessions.rotate_refresh_token.assert_called_once()
    users.get_user_by_id.assert_called_once_with("user-123")


def test_reused_refresh_token_revokes_session(setup_service):
    service, users, sessions, session, old_token = setup_service

    session["rotated_token_hashes"] = [
        hash_refresh_token(old_token)
    ]
    session["refresh_token_hash"] = "new-current-hash"

    with pytest.raises(ValueError, match="reuse detected"):
        service.refresh(old_token)

    sessions.revoke_session_by_id.assert_called_once_with(
        "session-123"
    )
    sessions.rotate_refresh_token.assert_not_called()


def test_concurrent_refresh_failure_revokes_session(setup_service):
    service, users, sessions, session, old_token = setup_service

    sessions.rotate_refresh_token.return_value = False

    with pytest.raises(ValueError, match="reuse detected"):
        service.refresh(old_token)

    sessions.revoke_session_by_id.assert_called_once_with(
        "session-123"
    )


def test_expired_refresh_token_rejected(setup_service):
    service, users, sessions, session, old_token = setup_service

    session["expires_at"] = (
        datetime.now(timezone.utc) - timedelta(days=1)
    )

    with pytest.raises(ValueError, match="expired"):
        service.refresh(old_token)

    sessions.rotate_refresh_token.assert_not_called()


def test_revoked_session_rejected(setup_service):
    service, users, sessions, session, old_token = setup_service

    session["revoked_at"] = datetime.now(timezone.utc)

    with pytest.raises(ValueError, match="revoked"):
        service.refresh(old_token)

    sessions.rotate_refresh_token.assert_not_called()
