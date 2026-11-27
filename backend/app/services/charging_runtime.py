
import asyncio
import logging
from collections.abc import Callable
from typing import Any

from backend.app.communication.mqtt_charging_handler import MQTTChargingHandler
from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.repositories.charging_event_repository import (
    ChargingEventRepository,
)
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.services.charging_event_service import ChargingEventService
from bson import ObjectId
from fastapi.encoders import jsonable_encoder
from pymongo.database import Database

logger = logging.getLogger(__name__)


def create_charging_notification_callback(
    websocket_manager: WebSocketManager,
    event_loop: asyncio.AbstractEventLoop,
) -> Callable[[dict[str, Any]], None]:
    """Create a thread-safe callback for charging WebSocket updates."""

    def notify(update: dict[str, Any]) -> None:
        message = jsonable_encoder(
            update,
            custom_encoder={ObjectId: str},
        )
        future = asyncio.run_coroutine_threadsafe(
            websocket_manager.broadcast(update["vehicle_id"], message),
            event_loop,
        )

        def handle_result(result: asyncio.Future) -> None:
            try:
                result.result()
            except Exception:
                logger.exception("WebSocket charging broadcast failed")

        future.add_done_callback(handle_result)

    return notify


def create_charging_runtime(
    database: Database,
    on_charging: Callable[[dict[str, Any]], None] | None = None,
) -> tuple[ChargingEventService, MQTTChargingHandler]:
    """Initialize charging event processing and MQTT handling."""

    event_repository = ChargingEventRepository(database["charging_events"])
    session_repository = ChargingSessionRepository(database["charging_sessions"])

    event_service = ChargingEventService(
        event_repository,
        session_repository,
        database.client,
    )
    mqtt_handler = MQTTChargingHandler(
        event_service,
        on_charging=on_charging,
    )

    return event_service, mqtt_handler
