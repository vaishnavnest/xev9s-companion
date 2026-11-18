import hashlib
import hmac
import os
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from dotenv import load_dotenv
from pwdlib import PasswordHash

load_dotenv()

password_hash = PasswordHash.recommended()

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY") or os.getenv("JWT_SECRET")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
VEHICLE_PAIRING_PEPPER = os.getenv("VEHICLE_PAIRING_PEPPER")

if not JWT_SECRET_KEY or len(JWT_SECRET_KEY) < 32:
    raise ValueError("A valid JWT_SECRET_KEY must be configured")


def hash_password(password: str) -> str:
    """Hash a password using the recommended Argon2 configuration."""
    return password_hash.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    """Verify a password against its stored hash."""
    return password_hash.verify(password, hashed_password)


def create_access_token(user_id: str) -> str:
    """Create a short-lived JWT access token."""
    now = datetime.now(UTC)

    payload = {
        "sub": user_id,
        "iat": now,
        "exp": now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
        "type": "access",
    }

    return jwt.encode(payload, JWT_SECRET_KEY, algorithm="HS256")


def decode_access_token(token: str) -> dict:
    """Decode and validate an access token."""
    payload = jwt.decode(
        token,
        JWT_SECRET_KEY,
        algorithms=["HS256"],
        options={"require": ["sub", "iat", "exp", "type"]},
    )

    if payload.get("type") != "access":
        raise jwt.InvalidTokenError("Invalid token type")

    return payload


def generate_refresh_token() -> str:
    """Generate a cryptographically secure opaque refresh token."""
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    """Hash a refresh token before storing it."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

def hash_pairing_code(pairing_code: str) -> str:
    """Create a keyed hash of a vehicle pairing code."""

    if (
        not VEHICLE_PAIRING_PEPPER
        or len(VEHICLE_PAIRING_PEPPER) < 32
    ):
        raise RuntimeError(
            "A valid VEHICLE_PAIRING_PEPPER must be configured"
        )

    message = (
        b"xev9s:vehicle-pairing:v1:"
        + pairing_code.encode("utf-8")
    )

    return hmac.new(
        VEHICLE_PAIRING_PEPPER.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()