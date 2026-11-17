
import os
from datetime import datetime, timezone
from backend.app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    generate_refresh_token,
    hash_refresh_token,
)
from backend.app.repositories.user_repository import UserRepository
from backend.app.repositories.session_repository import SessionRepository


REFRESH_TOKEN_EXPIRE_DAYS = int(
    os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7")
)


class AuthService:
    """Handles registration, login, refresh, and logout."""

    def __init__(
        self,
        users: UserRepository,
        sessions: SessionRepository,
    ):
        self.users = users
        self.sessions = sessions

    def register(
        self,
        email: str,
        password: str,
        full_name: str,
    ) -> dict:
        if self.users.get_user_by_email(email):
            raise ValueError("An account with this email already exists")

        hashed = hash_password(password)

        try:
            user = self.users.create_user(
                email=email,
                full_name=full_name,
                password_hash=hashed,
            )
        except ValueError as error:
            raise ValueError(
                "An account with this email already exists"
            ) from error

        return self._public_user(user)

    def login(self, email: str, password: str) -> dict:
        user = self.users.get_user_by_email(email)

        if (
            not user
            or not verify_password(password, user["password_hash"])
            or not user.get("is_active", False)
        ):
            raise ValueError("Incorrect email or password")

        return self._create_tokens(user)

    def refresh(self, refresh_token: str) -> dict:
        old_hash = hash_refresh_token(refresh_token)
        session = self.sessions.get_session_by_refresh_hash(
            old_hash
        )

        if not session:
            raise ValueError("Invalid or expired refresh token")

        if session.get("revoked_at") is not None:
            raise ValueError("Session has been revoked")
        
        expires_at = session["expires_at"]

        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)

        if expires_at <= datetime.now(timezone.utc):
            raise ValueError("Invalid or expired refresh token")

        used_hashes = session.get("rotated_token_hashes", [])

        if old_hash in used_hashes:
            self.sessions.revoke_session_by_id(session["_id"])
            raise ValueError("Refresh token reuse detected")

        current_hash = session["refresh_token_hash"]

        if current_hash != old_hash:
            raise ValueError("Invalid refresh token")

        new_token = generate_refresh_token()
        new_hash = hash_refresh_token(new_token)

        rotated = self.sessions.rotate_refresh_token(
            session["_id"],
            old_hash,
            new_hash,
            REFRESH_TOKEN_EXPIRE_DAYS,
        )
        
        if not rotated:
            self.sessions.revoke_session_by_id(session["_id"])
            raise ValueError("Refresh token reuse detected")

        user = self.users.get_user_by_id(session["user_id"])

        if not user or not user.get("is_active", False):
            self.sessions.revoke_session_by_id(session["_id"])
            raise ValueError("Account is unavailable")

        return self._token_response(user, new_token)
        

    def logout(self, refresh_token: str) -> bool:
        token_hash = hash_refresh_token(refresh_token)

        session = self.sessions.get_session_by_refresh_hash(
            token_hash
        )

        if not session or session.get("revoked_at") is not None:
            return False

        return self.sessions.revoke_session_by_id(
        session["_id"]
        )

    def _create_tokens(self, user: dict) -> dict:
        refresh_token = generate_refresh_token()

        self.sessions.create_session(
            user_id=str(user["_id"]),
            refresh_token_hash=hash_refresh_token(refresh_token),
            expires_in_days=REFRESH_TOKEN_EXPIRE_DAYS,
        )

        return self._token_response(user, refresh_token)

    def _token_response(self, user: dict, refresh_token: str) -> dict:
        return {
            "access_token": create_access_token(str(user["_id"])),
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": 15 * 60,
        }

    @staticmethod
    def _public_user(user: dict) -> dict:
        return {
            "id": str(user["_id"]),
            "email": user["email"],
            "full_name": user["full_name"],
            "is_active": user["is_active"],
            "created_at": user["created_at"],
        }
