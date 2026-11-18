from pymongo import ASCENDING


def ensure_database_indexes(database) -> None:
    """Create required indexes for authentication collections."""

    database["users"].create_index(
        [("email", ASCENDING)],
        unique=True,
        name="uq_users_email",
    )

    database["sessions"].create_index(
        [("refresh_token_hash", ASCENDING)],
        unique=True,
        name="uq_sessions_refresh_token",
    )
