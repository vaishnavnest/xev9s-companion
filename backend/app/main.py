
import asyncio
import logging
from contextlib import asynccontextmanager

from backend.app.communication.mqtt_command_handler import MQTTCommandHandler
from backend.app.communication.mqtt_subscriber import MQTTSubscriber
from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.core.database import (
    close_database_connection,
    connect_to_database,
)
from backend.app.core.indexes import ensure_database_indexes
from backend.app.repositories.command_repository import CommandRepository
from backend.app.repositories.telemetry_repository import TelemetryRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.routes.auth import router as auth_router
from backend.app.routes.commands import router as commands_router
from backend.app.routes.telemetry import router as telemetry_router
from backend.app.routes.vehicles import router as vehicles_router
from backend.app.routes.websocket import router as websocket_router
from backend.app.schemas.telemetry import TelemetryResponse
from backend.app.services.command_response_service import CommandResponseService
from backend.app.services.command_service import CommandService
from backend.app.services.command_timeout_manager import CommandTimeoutManager
from backend.app.services.telemetry_service import TelemetryService
from fastapi import FastAPI, HTTPException, Request
from pymongo.errors import PyMongoError

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.database = connect_to_database()
    mqtt_subscriber = None
    timeout_manager = None
    websocket_manager = WebSocketManager()
    event_loop = asyncio.get_running_loop()
    app.state.websocket_manager = websocket_manager

    try:
        database = app.state.database
        ensure_database_indexes(database)

        telemetry_repository = TelemetryRepository(
            database["vehicle_telemetry"]
        )
        vehicle_repository = VehicleRepository(
            database["vehicles"],
            database["user_vehicles"],
        )
        command_repository = CommandRepository(database["commands"])

        telemetry_service = TelemetryService(
            telemetry_repository,
            vehicle_repository,
        )

        timeout_manager = CommandTimeoutManager(command_repository)

        def notify_websocket_command_clients(command: dict) -> None:
            """Schedule command notifications on the application event loop."""
            message = {
                **command,
                "requested_at": command["requested_at"].isoformat(),
                "completed_at": command["completed_at"].isoformat(),
            }

            future = asyncio.run_coroutine_threadsafe(
                websocket_manager.broadcast(command["vehicle_id"], message),
                event_loop,
            )

            def handle_broadcast_result(result) -> None:
                try:
                    result.result()
                except Exception:
                    logger.exception("WebSocket command broadcast failed")

            future.add_done_callback(handle_broadcast_result)

        command_response_service = CommandResponseService(
            command_repository,
            timeout_manager,
            notify_websocket_command_clients,
        )

        def notify_websocket_clients(telemetry: dict) -> None:
            """Schedule telemetry broadcasting on the application event loop."""
            message = TelemetryResponse.model_validate(
                telemetry
            ).model_dump(mode="json")

            future = asyncio.run_coroutine_threadsafe(
                websocket_manager.broadcast(
                    message["vehicle_id"],
                    message,
                ),
                event_loop,
            )

            def handle_broadcast_result(result) -> None:
                try:
                    result.result()
                except Exception:
                    logger.exception("WebSocket telemetry broadcast failed")

            future.add_done_callback(handle_broadcast_result)

        mqtt_subscriber = MQTTSubscriber(
            telemetry_service,
            on_telemetry=notify_websocket_clients,
        )

        command_handler = MQTTCommandHandler(
            mqtt_subscriber.client,
            command_response_service.handle_response,
        )
        mqtt_subscriber.command_handler = command_handler

        command_service = CommandService(
            command_repository,
            vehicle_repository,
            telemetry_repository,
            command_handler.publish_command,
            timeout_manager,
        )

        app.state.telemetry_service = telemetry_service
        app.state.command_repository = command_repository
        app.state.command_service = command_service
        app.state.command_response_service = command_response_service
        app.state.command_timeout_manager = timeout_manager
        app.state.mqtt_subscriber = mqtt_subscriber

        mqtt_subscriber.start()
        yield

    finally:
        if mqtt_subscriber is not None:
            mqtt_subscriber.stop()
        if timeout_manager is not None:
            timeout_manager.stop_all()

        await websocket_manager.disconnect_all()
        close_database_connection()


app = FastAPI(
    title="XEV 9S Backend API",
    description="Backend API for the XEV 9S connected vehicle platform",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(auth_router)
app.include_router(vehicles_router)
app.include_router(commands_router)
app.include_router(telemetry_router)
app.include_router(websocket_router)


@app.get("/")
def root():
    return {"message": "XEV 9S Backend is running"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/health/database")
def database_health_check(request: Request):
    try:
        request.app.state.database.command("ping")
        return {"database": "connected"}
    except PyMongoError:
        raise HTTPException(
            status_code=503,
            detail="Database connection unavailable",
        )
