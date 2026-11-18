import importlib
import os
from datetime import UTC, datetime, timedelta
from unittest.mock import patch

import jwt
import pytest
from backend.app.core import security
from backend.app.core.security import (
    create_access_token,
    decode_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)


def test_password_hashing_and_verification():
    raw_password = "SuperSecretPassword123!"
    hashed = hash_password(raw_password)

    assert hashed != raw_password
    assert verify_password(raw_password, hashed) is True
    assert verify_password("WrongPassword123!", hashed) is False


def test_access_token_creation_and_decoding():
    user_id = "user-123456"
    token = create_access_token(user_id)

    payload = decode_access_token(token)
    assert payload["sub"] == user_id
    assert payload["type"] == "access"
    assert "exp" in payload
    assert "iat" in payload


def test_decode_access_token_invalid_type():
    now = datetime.now(UTC)
    payload = {
        "sub": "user-123",
        "iat": now,
        "exp": now + timedelta(minutes=15),
        "type": "refresh",  # wrong type
    }
    token = jwt.encode(payload, security.JWT_SECRET_KEY, algorithm="HS256")

    with pytest.raises(jwt.InvalidTokenError, match="Invalid token type"):
        decode_access_token(token)


def test_decode_access_token_expired():
    past = datetime.now(UTC) - timedelta(hours=1)
    payload = {
        "sub": "user-123",
        "iat": past - timedelta(minutes=15),
        "exp": past,
        "type": "access",
    }
    expired_token = jwt.encode(payload, security.JWT_SECRET_KEY, algorithm="HS256")

    with pytest.raises(jwt.ExpiredSignatureError):
        decode_access_token(expired_token)


def test_decode_access_token_invalid_signature():
    token = create_access_token("user-123")
    other_secret = "different_secret_key_32_chars_long_min!"

    with (
        patch.object(security, "JWT_SECRET_KEY", other_secret),
        pytest.raises(jwt.InvalidSignatureError),
    ):
        decode_access_token(token)


def test_decode_access_token_missing_claims():
    payload = {
        "sub": "user-123",
        # missing exp, iat, type
    }
    token = jwt.encode(payload, security.JWT_SECRET_KEY, algorithm="HS256")

    with pytest.raises(jwt.MissingRequiredClaimError):
        decode_access_token(token)


def test_generate_and_hash_refresh_token():
    token1 = generate_refresh_token()
    token2 = generate_refresh_token()

    assert isinstance(token1, str)
    assert len(token1) >= 48
    assert token1 != token2

    hash1 = hash_refresh_token(token1)
    hash2 = hash_refresh_token(token1)
    assert hash1 == hash2
    assert len(hash1) == 64  # SHA-256 hexdigest


def test_jwt_secret_validation_failure():
    with (
        patch.dict(os.environ, {"JWT_SECRET_KEY": "", "JWT_SECRET": ""}, clear=False),
        patch("dotenv.load_dotenv"),
        pytest.raises(ValueError, match="A valid JWT_SECRET_KEY must be configured"),
    ):
        importlib.reload(security)

    # Reload again to restore valid state
    importlib.reload(security)
