import asyncio
import logging
from contextlib import asynccontextmanager

from backend.app.communication.mqtt_command_handler import MQTTCommandHandler
from backend.app.communication.mqtt_subscriber import MQTTSubscriber
from backend.app.communication.websocket_manager import WebSocketManager
from backend.app.communication.websocket_notifications import (
    _log_broadcast_error as _log_ws_broadcast_error,
)
from backend.app.communication.websocket_notifications import (
    create_command_notification_callback,
    create_telemetry_notification_callback,
)
from backend.app.core.database import close_database_connection, connect_to_database
from backend.app.core.indexes import ensure_database_indexes
from backend.app.repositories.command_repository import CommandRepository
from backend.app.repositories.telemetry_repository import TelemetryRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.routes.auth import router as auth_router
from backend.app.routes.charging import router as charging_router
from backend.app.routes.commands import router as commands_router
from backend.app.routes.location import router as location_router
from backend.app.routes.telemetry import router as telemetry_router
from backend.app.routes.trips import router as trips_router
from backend.app.routes.vehicles import router as vehicles_router
from backend.app.routes.websocket import router as websocket_router
from backend.app.services.charging_runtime import (
    create_charging_notification_callback,
    create_charging_runtime,
)
from backend.app.services.command_response_service import CommandResponseService
from backend.app.services.command_service import CommandService
from backend.app.services.command_timeout_manager import CommandTimeoutManager
from backend.app.services.geocoding_service import GeocodingService
from backend.app.services.location_service import LocationService
from backend.app.services.telemetry_service import TelemetryService
from backend.app.services.trip_runtime import (
    create_trip_notification_callback,
    create_trip_runtime,
)
from fastapi import FastAPI, HTTPException, Request
from pymongo.errors import PyMongoError

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.database = connect_to_database()
    mqtt_subscriber = None
    timeout_manager = None
    geocoding_service = None
    websocket_manager = WebSocketManager()
    event_loop = asyncio.get_running_loop()
    app.state.websocket_manager = websocket_manager

    try:
        database = app.state.database
        ensure_database_indexes(database)

        telemetry_repository = TelemetryRepository(database["vehicle_telemetry"])
        vehicle_repository = VehicleRepository(
            database["vehicles"], database["user_vehicles"]
        )
        command_repository = CommandRepository(database["commands"])
        trip_callback = create_trip_notification_callback(websocket_manager, event_loop)
        trip_repo, trip_service = create_trip_runtime(
            database, vehicle_repository, on_trip_completed=trip_callback
        )
        telemetry_service = TelemetryService(
            telemetry_repository, vehicle_repository, trip_service=trip_service
        )
        notify_websocket_command_clients = create_command_notification_callback(
            websocket_manager, event_loop
        )
        timeout_manager = CommandTimeoutManager(
            command_repository,
            on_command_timed_out=notify_websocket_command_clients,
        )

        command_response_service = CommandResponseService(
            command_repository, timeout_manager, notify_websocket_command_clients
        )

        notify_websocket_clients = create_telemetry_notification_callback(
            websocket_manager, event_loop
        )

        charging_callback = create_charging_notification_callback(
            websocket_manager, event_loop
        )
        charging_event_service, charging_handler = create_charging_runtime(
            database, on_charging=charging_callback
        )

        mqtt_subscriber = MQTTSubscriber(
            telemetry_service,
            on_telemetry=notify_websocket_clients,
            charging_handler=charging_handler,
        )
        command_handler = MQTTCommandHandler(
            mqtt_subscriber.client, command_response_service.handle_response
        )
        mqtt_subscriber.command_handler = command_handler

        command_service = CommandService(
            command_repository,
            vehicle_repository,
            telemetry_repository,
            command_handler.publish_command,
            timeout_manager,
        )
        geocoding_service = GeocodingService()
        location_service = LocationService(
            vehicle_repository,
            telemetry_repository,
            geocoding_service=geocoding_service,
        )

        app.state.telemetry_service = telemetry_service
        app.state.command_repository = command_repository
        app.state.command_service = command_service
        app.state.command_response_service = command_response_service
        app.state.command_timeout_manager = timeout_manager
        app.state.charging_event_service = charging_event_service
        app.state.location_service = location_service
        app.state.trip_service = trip_service
        app.state.trip_repository = trip_repo
        app.state.mqtt_subscriber = mqtt_subscriber

        mqtt_subscriber.start()
        yield

    finally:
        if mqtt_subscriber is not None:
            mqtt_subscriber.stop()
        if timeout_manager is not None:
            timeout_manager.stop_all()
        if geocoding_service is not None:
            geocoding_service.shutdown(wait=True)
        await websocket_manager.disconnect_all()
        close_database_connection()


def _log_broadcast_error(result, message: str) -> None:
    _log_ws_broadcast_error(result, message)


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
app.include_router(charging_router)
app.include_router(location_router)
app.include_router(trips_router)
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
