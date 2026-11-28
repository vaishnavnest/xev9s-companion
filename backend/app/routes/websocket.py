import asyncio
import logging

from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.core.security import decode_access_token
from backend.app.repositories.user_repository import UserRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jwt import InvalidTokenError
from pymongo.errors import PyMongoError

logger = logging.getLogger(__name__)
WS_AUTH_TIMEOUT_SECONDS = 10.0

router = APIRouter(tags=["Vehicle WebSocket"])


@router.websocket("/ws/vehicles/{vehicle_id}")
async def vehicle_telemetry_socket(
    websocket: WebSocket,
    vehicle_id: str,
) -> None:
    """Authenticate a user and stream telemetry for an associated vehicle."""
    await websocket.accept()
    manager: WebSocketManager = websocket.app.state.websocket_manager

    try:
        try:
            credentials = await asyncio.wait_for(
                websocket.receive_json(),
                timeout=WS_AUTH_TIMEOUT_SECONDS,
            )
        except TimeoutError:
            await websocket.close(code=1008)
            return

        if not isinstance(credentials, dict):
            await websocket.close(code=1008)
            return

        token = credentials.get("token")

        if not isinstance(token, str) or not token:
            await websocket.close(code=1008)
            return

        token_data = decode_access_token(token)
        user_id = token_data.get("sub")

        if not user_id:
            await websocket.close(code=1008)
            return

        database = websocket.app.state.database
        user_repository = UserRepository(database["users"])
        user = await asyncio.to_thread(user_repository.get_user_by_id, user_id)

        if not user or not user.get("is_active"):
            await websocket.close(code=1008)
            return

        vehicle_repository = VehicleRepository(
            database["vehicles"],
            database["user_vehicles"],
        )

        is_associated = await asyncio.to_thread(
            vehicle_repository.is_vehicle_associated_with_user,
            user_id,
            vehicle_id,
        )
        if not is_associated:
            await websocket.close(code=1008)
            return

        await manager.connect(
            vehicle_id,
            websocket,
            accept_connection=False,
        )

        while True:
            await websocket.receive_text()

    except InvalidTokenError:
        await websocket.close(code=1008)
    except PyMongoError:
        logger.exception("Database error during WebSocket authentication")
        await websocket.close(code=1011)
    except WebSocketDisconnect:
        logger.info(
            "WebSocket client disconnected from vehicle %s",
            vehicle_id,
        )
    finally:
        await manager.disconnect(vehicle_id, websocket)
