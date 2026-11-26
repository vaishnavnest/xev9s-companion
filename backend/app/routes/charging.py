
from backend.app.communication.mqtt_charging_publisher import (
    MQTTChargingPublisher,
)
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
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
from backend.app.schemas.charging import (
    ChargingPreferencesResponse,
    ChargingPreferencesUpdate,
)
from backend.app.schemas.charging_session import (
    ChargingSessionHistoryResponse,
)
from backend.app.services.charging_service import ChargingService
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

router = APIRouter(prefix="/vehicles/{vehicle_id}/charging", tags=["Charging"])


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

    if isinstance(error, VehicleNotActiveError):
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


@router.get("", response_model=ChargingPreferencesResponse | None)
def get_charging_preferences(
    vehicle_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve charging preferences for an owned vehicle."""

    service = get_charging_service(request)

    try:
        return service.get_preferences(current_user["id"], vehicle_id)
    except (VehicleAccessDeniedError, VehicleNotActiveError) as error:
        handle_charging_error(error)


@router.put(
    "/preferences",
    response_model=ChargingPreferencesResponse,
)
def update_charging_preferences(
    vehicle_id: str,
    preferences: ChargingPreferencesUpdate,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Save charging preferences for an owned vehicle."""

    service = get_charging_service(request)

    try:
        return service.update_preferences(
            current_user["id"],
            vehicle_id,
            preferences,
        )
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        MQTTUnavailableError,
        ValueError,
    ) as error:
        handle_charging_error(error)


@router.get(
    "/sessions",
    response_model=ChargingSessionHistoryResponse,
)
def get_charging_sessions(
    vehicle_id: str,
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: dict = Depends(get_current_user),
):
    """Retrieve charging session history for an owned vehicle."""

    service = get_charging_service(request)

    try:
        sessions = service.get_session_history(
            current_user["id"],
            vehicle_id,
            limit,
            offset,
        )
        return {
            "sessions": sessions,
            "count": len(sessions),
        }
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        ValueError,
    ) as error:
        handle_charging_error(error)
