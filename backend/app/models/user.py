from datetime import UTC, datetime


def create_user_document(
    email: str,
    full_name: str,
    password_hash: str,
) -> dict:
    """Build the MongoDB document for a newly registered user."""

    now = datetime.now(UTC)

    return {
        "email": email.strip().lower(),
        "full_name": full_name.strip(),
        "password_hash": password_hash,
        "is_active": True,
        "created_at": now,
        "updated_at": now,
    }
