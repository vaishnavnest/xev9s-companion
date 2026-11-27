import math
from datetime import datetime
from typing import Annotated

from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    ChargingSessionNotFoundError,
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.routes.charging_dependencies import (
    get_charging_service,
    handle_charging_error,
)
from backend.app.schemas.charging import (
    ChargingPreferencesResponse,
    ChargingPreferencesUpdate,
)
from backend.app.schemas.charging_session import (
    ChargingSessionHistoryResponse,
    ChargingSessionResponse,
    ChargingSessionStatus,
)
from backend.app.services.charging_service import ChargingService
from fastapi import APIRouter, Depends, Query, Request

__all__ = [
    "ChargingService",
    "get_charging_preferences",
    "get_charging_service",
    "get_charging_session_detail",
    "get_charging_sessions",
    "handle_charging_error",
    "router",
    "update_charging_preferences",
]

router = APIRouter(prefix="/vehicles/{vehicle_id}/charging", tags=["Charging"])


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
    page: Annotated[int | None, Query(ge=1)] = None,
    page_size: Annotated[int | None, Query(ge=1, le=100)] = None,
    session_status: Annotated[
        ChargingSessionStatus | None, Query(alias="status")
    ] = None,
    from_time: Annotated[datetime | None, Query(alias="from")] = None,
    to_time: Annotated[datetime | None, Query(alias="to")] = None,
    sort: Annotated[str, Query()] = "-started_at",
):
    """Retrieve filtered, paginated charging session history for an owned vehicle."""

    service = get_charging_service(request)

    if page is not None or page_size is not None:
        effective_page = page if page is not None else 1
        effective_limit = page_size if page_size is not None else limit
        effective_offset = (effective_page - 1) * effective_limit
    else:
        effective_limit = limit
        effective_offset = offset
        effective_page = (offset // limit) + 1

    try:
        sessions, total_items = service.get_session_history(
            current_user["id"],
            vehicle_id,
            effective_limit,
            effective_offset,
            status=session_status,
            from_time=from_time,
            to_time=to_time,
            sort=sort,
        )
        total_pages = math.ceil(total_items / effective_limit) if total_items > 0 else 0
        return {
            "sessions": sessions,
            "count": len(sessions),
            "pagination": {
                "page": effective_page,
                "page_size": effective_limit,
                "total_items": total_items,
                "total_pages": total_pages,
            },
        }
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        ValueError,
    ) as error:
        handle_charging_error(error)


@router.get(
    "/sessions/{session_id}",
    response_model=ChargingSessionResponse,
)
def get_charging_session_detail(
    vehicle_id: str,
    session_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve a single charging session for an owned vehicle."""

    service = get_charging_service(request)

    try:
        return service.get_session_detail(
            current_user["id"],
            vehicle_id,
            session_id,
        )
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        ChargingSessionNotFoundError,
        ValueError,
    ) as error:
        handle_charging_error(error)
