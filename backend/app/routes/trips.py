from datetime import datetime
from typing import Annotated

from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    TripNotFoundError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.repositories.trip_repository import TripRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.schemas.trip import (
    TripDetail,
    TripListResponse,
    TripStatus,
)
from backend.app.services.trip_lifecycle import TripLifecycleManager
from backend.app.services.trip_service import TripService
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

router = APIRouter(prefix="/vehicles/{vehicle_id}/trips", tags=["Trips"])


def get_trip_service(request: Request) -> TripService:
    """Retrieve or instantiate the trip service."""
    if hasattr(request.app.state, "trip_service"):
        return request.app.state.trip_service

    database = request.app.state.database
    trip_repo = TripRepository(database["trips"])
    vehicle_repo = VehicleRepository(
        database["vehicles"],
        database["user_vehicles"],
    )
    lifecycle = TripLifecycleManager(trip_repo)
    return TripService(trip_repo, vehicle_repo, lifecycle)


def handle_trip_error(error: Exception) -> None:
    """Translate trip service exceptions into standard HTTP exceptions."""
    if isinstance(error, VehicleAccessDeniedError):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(error),
        ) from error

    if isinstance(error, (VehicleNotActiveError, TripNotFoundError)):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    if isinstance(error, ValueError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error

    raise error


@router.get("", response_model=TripListResponse, status_code=status.HTTP_200_OK)
def list_vehicle_trips(
    vehicle_id: str,
    request: Request,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    sort: Annotated[str, Query()] = "-started_at",
    from_time: Annotated[datetime | None, Query(alias="from")] = None,
    to_time: Annotated[datetime | None, Query(alias="to")] = None,
    trip_status: Annotated[TripStatus | None, Query(alias="status")] = None,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve paginated trips for an associated vehicle (UC-06)."""
    service = get_trip_service(request)
    try:
        return service.list_trips(
            user_id=current_user["id"],
            vehicle_id=vehicle_id,
            page=page,
            page_size=page_size,
            sort=sort,
            from_time=from_time,
            to_time=to_time,
            status=trip_status.value if trip_status else None,
        )
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        TripNotFoundError,
        ValueError,
    ) as error:
        handle_trip_error(error)


@router.get(
    "/{trip_id}",
    response_model=TripDetail,
    status_code=status.HTTP_200_OK,
)
def get_vehicle_trip_detail(
    vehicle_id: str,
    trip_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve full details of a single trip including GPS route (UC-06)."""
    service = get_trip_service(request)
    try:
        return service.get_trip_detail(
            user_id=current_user["id"],
            vehicle_id=vehicle_id,
            trip_id=trip_id,
        )
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        TripNotFoundError,
        ValueError,
    ) as error:
        handle_trip_error(error)
