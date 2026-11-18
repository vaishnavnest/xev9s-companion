from datetime import UTC, datetime, timedelta


def create_session_document(
    user_id: str,
    refresh_token_hash: str,
    expires_in_days: int,
) -> dict:
    """Build the MongoDB document for a new session."""

    now = datetime.now(UTC)

    return {
        "user_id": user_id,
        "refresh_token_hash": refresh_token_hash,
        "rotated_token_hashes": [],
        "created_at": now,
        "expires_at": now + timedelta(days=expires_in_days),
        "revoked_at": None,
    }
