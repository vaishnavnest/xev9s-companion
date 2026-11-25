from pymongo import ASCENDING, DESCENDING


def ensure_database_indexes(database) -> None:
    """Create required indexes for application collections."""

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

    database["vehicles"].create_index(
        [("vehicle_id", ASCENDING)],
        unique=True,
        name="uq_vehicles_vehicle_id",
    )

    database["user_vehicles"].create_index(
        [
            ("user_id", ASCENDING),
            ("vehicle_id", ASCENDING),
        ],
        unique=True,
        name="uq_user_vehicles_association",
    )

    database["user_vehicles"].create_index(
        [
            ("user_id", ASCENDING),
            ("associated_at", DESCENDING),
        ],
        name="idx_user_vehicles_associated_at",
    )

    database["vehicle_telemetry"].create_index(
        [
            ("vehicle_id", ASCENDING),
            ("timestamp", DESCENDING),
        ],
        name="idx_vehicle_telemetry_vehicle_timestamp",
    )

    database["commands"].create_index(
        [("command_id", ASCENDING)],
        unique=True,
        name="uq_commands_command_id",
    )

    database["commands"].create_index(
        [
            ("vehicle_id", ASCENDING),
            ("requested_at", DESCENDING),
        ],
        name="idx_commands_vehicle_history",
    )

    database["commands"].create_index(
        [
            ("user_id", ASCENDING),
            ("vehicle_id", ASCENDING),
        ],
        name="idx_commands_user_vehicle",
    )
