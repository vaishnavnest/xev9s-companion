import asyncio
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest
from backend.app.services.trip_runtime import (
    create_trip_notification_callback,
    create_trip_runtime,
)


@pytest.mark.anyio
async def test_trip_notification_callback_broadcasts_event():
    websocket_manager = MagicMock()
    websocket_manager.broadcast = AsyncMock()
    event_loop = asyncio.get_running_loop()

    notify = create_trip_notification_callback(websocket_manager, event_loop)

    now = datetime.now(UTC)
    trip_data = {
        "trip_id": "trp_101",
        "vehicle_id": "XEV-001",
        "status": "completed",
        "started_at": now,
        "ended_at": now,
        "distance_km": 12.5,
        "duration_seconds": 600,
        "average_speed_kmh": 75.0,
        "energy_consumed_kwh": 2.1,
        "start_location": {"latitude": 12.97, "longitude": 77.59},
        "end_location": {"latitude": 13.08, "longitude": 80.27},
    }

    notify(trip_data)
    await asyncio.sleep(0.05)

    websocket_manager.broadcast.assert_called_once()
    args = websocket_manager.broadcast.call_args[0]
    assert args[0] == "XEV-001"
    message = args[1]
    assert message["event"] == "trip.completed"
    assert message["data"]["trip_id"] == "trp_101"
    assert message["data"]["distance_km"] == 12.5


def test_create_trip_runtime_wiring():
    database = MagicMock()
    vehicle_repo = MagicMock()
    trip_repo, trip_svc = create_trip_runtime(database, vehicle_repo)

    assert trip_repo is not None
    assert trip_svc is not None
    assert trip_svc.trip_repository is trip_repo
    assert trip_svc.vehicle_repository is vehicle_repo
