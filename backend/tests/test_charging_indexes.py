from unittest.mock import MagicMock, call

from backend.app.core.indexes import ensure_database_indexes


def test_charging_indexes_are_created_centrally():
    collection_names = [
        "users",
        "sessions",
        "vehicles",
        "user_vehicles",
        "vehicle_telemetry",
        "commands",
        "charging_preferences",
        "charging_sessions",
        "charging_events",
        "trips",
    ]
    collections = {name: MagicMock() for name in collection_names}

    database = MagicMock()
    database.__getitem__.side_effect = collections.__getitem__

    ensure_database_indexes(database)

    assert collections["charging_preferences"].create_index.call_args_list == [
        call(
            [("vehicle_id", 1)],
            unique=True,
            name="uq_charging_preferences_vehicle",
        ),
    ]

    assert collections["charging_sessions"].create_index.call_args_list == [
        call(
            [("session_id", 1)],
            unique=True,
            name="uq_charging_sessions_session_id",
        ),
        call(
            [("vehicle_id", 1), ("started_at", -1)],
            name="idx_charging_sessions_vehicle_history",
        ),
        call(
            [("vehicle_id", 1)],
            unique=True,
            partialFilterExpression={"status": {"$in": ["active", "paused"]}},
            name="uq_charging_sessions_active_vehicle",
        ),
    ]

    assert collections["charging_events"].create_index.call_args_list == [
        call(
            [("event_id", 1)],
            unique=True,
            name="uq_charging_events_event_id",
        ),
        call(
            [("vehicle_id", 1), ("timestamp", -1)],
            name="idx_charging_events_vehicle_timestamp",
        ),
    ]
