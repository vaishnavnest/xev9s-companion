import asyncio
import logging
from collections.abc import Callable
from typing import Any

from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.schemas.telemetry import TelemetryResponse

logger = logging.getLogger(__name__)


def _log_broadcast_error(result: asyncio.Future, message: str) -> None:
    try:
        result.result()
    except Exception:
        logger.exception(message)


def create_command_notification_callback(
    websocket_manager: WebSocketManager,
    event_loop: asyncio.AbstractEventLoop,
) -> Callable[[dict[str, Any]], None]:
    """Create a thread-safe callback for command WebSocket updates."""

    def notify(command: dict[str, Any]) -> None:
        message = {
            **command,
            "requested_at": command["requested_at"].isoformat(),
            "completed_at": command["completed_at"].isoformat(),
        }
        future = asyncio.run_coroutine_threadsafe(
            websocket_manager.broadcast(command["vehicle_id"], message),
            event_loop,
        )
        future.add_done_callback(
            lambda res: _log_broadcast_error(res, "WebSocket command broadcast failed")
        )

    return notify


def create_telemetry_notification_callback(
    websocket_manager: WebSocketManager,
    event_loop: asyncio.AbstractEventLoop,
) -> Callable[[dict[str, Any]], None]:
    """Create a thread-safe callback for telemetry WebSocket updates."""

    def notify(telemetry: dict[str, Any]) -> None:
        message = TelemetryResponse.model_validate(telemetry).model_dump(mode="json")
        future = asyncio.run_coroutine_threadsafe(
            websocket_manager.broadcast(message["vehicle_id"], message),
            event_loop,
        )
        future.add_done_callback(
            lambda res: _log_broadcast_error(
                res, "WebSocket telemetry broadcast failed"
            )
        )

    return notify
