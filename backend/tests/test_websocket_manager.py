
from unittest.mock import AsyncMock, MagicMock

import pytest
from backend.app.communication.websocket_manager import WebSocketManager


@pytest.mark.anyio
async def test_connect_accepts_websocket():
    manager = WebSocketManager()
    websocket = MagicMock()
    websocket.accept = AsyncMock()

    await manager.connect("XEV-001", websocket)

    websocket.accept.assert_awaited_once()


@pytest.mark.anyio
async def test_broadcast_only_reaches_matching_vehicle():
    manager = WebSocketManager()
    first = MagicMock()
    second = MagicMock()

    for websocket in (first, second):
        websocket.accept = AsyncMock()
        websocket.send_json = AsyncMock()
        websocket.close = AsyncMock()

    await manager.connect("XEV-001", first)
    await manager.connect("XEV-002", second)

    message = {"battery_percentage": 80}
    await manager.broadcast("XEV-001", message)

    first.send_json.assert_awaited_once_with(message)
    second.send_json.assert_not_awaited()


@pytest.mark.anyio
async def test_disconnect_removes_websocket():
    manager = WebSocketManager()
    websocket = MagicMock()
    websocket.accept = AsyncMock()
    websocket.send_json = AsyncMock()
    websocket.close = AsyncMock()

    await manager.connect("XEV-001", websocket)
    await manager.disconnect("XEV-001", websocket)
    await manager.broadcast("XEV-001", {"speed_kph": 20})

    websocket.send_json.assert_not_awaited()


@pytest.mark.anyio
async def test_broadcast_removes_failed_connections():
    manager = WebSocketManager()
    websocket = MagicMock()
    websocket.accept = AsyncMock()
    websocket.send_json = AsyncMock(
        side_effect=RuntimeError("Connection closed")
    )
    websocket.close = AsyncMock()

    await manager.connect("XEV-001", websocket)

    await manager.broadcast("XEV-001", {"speed_kph": 20})
    await manager.broadcast("XEV-001", {"speed_kph": 30})

    websocket.send_json.assert_awaited_once()


@pytest.mark.anyio
async def test_disconnect_all_closes_connections():
    manager = WebSocketManager()
    websocket = MagicMock()
    websocket.accept = AsyncMock()
    websocket.send_json = AsyncMock()
    websocket.close = AsyncMock()

    await manager.connect("XEV-001", websocket)
    await manager.disconnect_all()

    websocket.close.assert_awaited_once_with(
        code=1001,
        reason="Server shutting down",
    )
