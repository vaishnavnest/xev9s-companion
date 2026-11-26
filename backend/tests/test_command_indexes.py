from unittest.mock import MagicMock, call

from backend.app.core.indexes import ensure_database_indexes


def test_command_indexes_are_created_centrally():
    collection_names = [
        "users",
        "sessions",
        "vehicles",
        "user_vehicles",
        "vehicle_telemetry",
        "commands",
    ]
    collections = {
        name: MagicMock()
        for name in collection_names
        + [
            "charging_preferences",
            "charging_sessions",
            "charging_events",
        ]
    }

    database = MagicMock()
    database.__getitem__.side_effect = collections.__getitem__

    ensure_database_indexes(database)

    command_collection = collections["commands"]

    assert command_collection.create_index.call_count == 3

    assert command_collection.create_index.call_args_list == [
        call(
            [("command_id", 1)],
            unique=True,
            name="uq_commands_command_id",
        ),
        call(
            [
                ("vehicle_id", 1),
                ("requested_at", -1),
            ],
            name="idx_commands_vehicle_history",
        ),
        call(
            [
                ("user_id", 1),
                ("vehicle_id", 1),
            ],
            name="idx_commands_user_vehicle",
        ),
    ]
