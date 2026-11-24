
import asyncio
import logging
from collections import defaultdict

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class WebSocketManager:
    """Manage vehicle-specific WebSocket connections."""

    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(
        self,
        vehicle_id: str,
        websocket: WebSocket,
        accept_connection: bool = True,
    ) -> None:
        """Accept and register a WebSocket connection."""
        if accept_connection:
            await websocket.accept()

        async with self._lock:
            self._connections[vehicle_id].add(websocket)

        logger.info("WebSocket connected for vehicle %s", vehicle_id)

    async def disconnect(
        self,
        vehicle_id: str,
        websocket: WebSocket,
    ) -> None:
        """Remove a WebSocket connection."""
        async with self._lock:
            connections = self._connections.get(vehicle_id)

            if connections is None:
                return

            connections.discard(websocket)

            if not connections:
                self._connections.pop(vehicle_id, None)

        logger.info("WebSocket disconnected for vehicle %s", vehicle_id)

    async def broadcast(
        self,
        vehicle_id: str,
        message: dict,
    ) -> None:
        """Broadcast a message to all connected clients of a vehicle."""
        async with self._lock:
            connections = tuple(self._connections.get(vehicle_id, set()))

        if not connections:
            return

        results = await asyncio.gather(
            *(
                websocket.send_json(message)
                for websocket in connections
            ),
            return_exceptions=True,
        )

        disconnected = [
            websocket
            for websocket, result in zip(connections, results)
            if isinstance(result, Exception)
        ]

        for websocket in disconnected:
            await self.disconnect(vehicle_id, websocket)

    async def disconnect_all(self) -> None:
        """Close all active WebSocket connections during shutdown."""
        async with self._lock:
            connections = [
                (vehicle_id, websocket)
                for vehicle_id, clients in self._connections.items()
                for websocket in clients
            ]
            self._connections.clear()

        await asyncio.gather(
            *(
                websocket.close(code=1001, reason="Server shutting down")
                for _, websocket in connections
            ),
            return_exceptions=True,
        )
