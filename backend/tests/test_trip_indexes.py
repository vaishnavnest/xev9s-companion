from unittest.mock import MagicMock, call

from backend.app.core.indexes import ensure_database_indexes


def test_trip_indexes_are_created_centrally():
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

    trips_collection = collections["trips"]
    assert trips_collection.create_index.call_count == 3

    assert trips_collection.create_index.call_args_list == [
        call(
            [("trip_id", 1)],
            unique=True,
            name="uq_trips_trip_id",
        ),
        call(
            [("vehicle_id", 1)],
            unique=True,
            partialFilterExpression={"status": "ongoing"},
            name="uq_trips_active_vehicle",
        ),
        call(
            [
                ("vehicle_id", 1),
                ("started_at", -1),
            ],
            name="idx_trips_vehicle_history",
        ),
    ]
