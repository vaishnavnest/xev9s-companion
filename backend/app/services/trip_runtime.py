import asyncio
import logging
from collections.abc import Callable
from typing import Any

from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.repositories.trip_repository import TripRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.services.trip_lifecycle import TripLifecycleManager
from backend.app.services.trip_service import TripService
from bson import ObjectId
from fastapi.encoders import jsonable_encoder
from pymongo.database import Database

logger = logging.getLogger(__name__)


def create_trip_notification_callback(
    websocket_manager: WebSocketManager,
    event_loop: asyncio.AbstractEventLoop,
) -> Callable[[dict[str, Any]], None]:
    """Create a thread-safe callback for trip.completed WebSocket broadcasts."""

    def notify(trip: dict[str, Any]) -> None:
        ended_at = trip.get("ended_at")
        started_at = trip.get("started_at")
        timestamp_str = (
            ended_at.isoformat() if hasattr(ended_at, "isoformat") else str(ended_at)
        )
        started_at_str = (
            started_at.isoformat()
            if hasattr(started_at, "isoformat")
            else str(started_at)
        )

        message = {
            "event": "trip.completed",
            "vehicle_id": trip["vehicle_id"],
            "timestamp": timestamp_str,
            "data": {
                "trip_id": trip["trip_id"],
                "status": trip["status"],
                "started_at": started_at_str,
                "ended_at": timestamp_str,
                "distance_km": trip.get("distance_km"),
                "duration_seconds": trip.get("duration_seconds"),
                "average_speed_kmh": trip.get("average_speed_kmh"),
                "energy_consumed_kwh": trip.get("energy_consumed_kwh"),
                "start_location": trip.get("start_location"),
                "end_location": trip.get("end_location"),
            },
        }

        encoded_message = jsonable_encoder(
            message,
            custom_encoder={ObjectId: str},
        )
        future = asyncio.run_coroutine_threadsafe(
            websocket_manager.broadcast(trip["vehicle_id"], encoded_message),
            event_loop,
        )

        def handle_result(result: asyncio.Future) -> None:
            try:
                result.result()
            except Exception:
                logger.exception("WebSocket trip broadcast failed")

        future.add_done_callback(handle_result)

    return notify


def create_trip_runtime(
    database: Database,
    vehicle_repository: VehicleRepository,
    on_trip_completed: Callable[[dict[str, Any]], None] | None = None,
) -> tuple[TripRepository, TripService]:
    """Instantiate and wire trip repository, lifecycle manager, and service."""
    trip_repository = TripRepository(database["trips"])
    lifecycle_manager = TripLifecycleManager(
        trip_repository=trip_repository,
        on_trip_completed=on_trip_completed,
    )
    trip_service = TripService(
        trip_repository=trip_repository,
        vehicle_repository=vehicle_repository,
        lifecycle_manager=lifecycle_manager,
    )
    return trip_repository, trip_service
