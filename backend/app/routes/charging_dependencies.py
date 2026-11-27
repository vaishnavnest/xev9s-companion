from backend.app.communication.mqtt_charging_publisher import (
    MQTTChargingPublisher,
)
from backend.app.core.exceptions import (
    ChargingSessionNotFoundError,
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.repositories.charging_event_repository import (
    ChargingEventRepository,
)
from backend.app.repositories.charging_repository import ChargingRepository
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.services.charging_service import ChargingService
from fastapi import HTTPException, Request, status


def get_charging_service(request: Request) -> ChargingService:
    """Build charging service using the application database and MQTT client."""

    database = request.app.state.database
    mqtt_client = request.app.state.mqtt_subscriber.client

    return ChargingService(
        charging_repository=ChargingRepository(
            database["charging_preferences"]
        ),
        session_repository=ChargingSessionRepository(
            database["charging_sessions"]
        ),
        event_repository=ChargingEventRepository(
            database["charging_events"]
        ),
        vehicle_repository=VehicleRepository(
            database["vehicles"],
            database["user_vehicles"],
        ),
        mongo_client=database.client,
        mqtt_publisher=MQTTChargingPublisher(mqtt_client),
    )


def handle_charging_error(error: Exception) -> None:
    """Translate charging service errors into HTTP responses."""

    if isinstance(error, VehicleAccessDeniedError):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(error),
        ) from error

    if isinstance(error, (VehicleNotActiveError, ChargingSessionNotFoundError)):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    if isinstance(error, MQTTUnavailableError):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(error),
        ) from error

    if isinstance(error, ValueError):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(error),
        ) from error
