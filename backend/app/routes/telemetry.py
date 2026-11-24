
from datetime import datetime
from typing import Annotated

from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import VehicleAccessDeniedError
from backend.app.schemas.telemetry import (
    TelemetryHistoryResponse,
    TelemetryResponse,
)
from backend.app.services.telemetry_service import TelemetryService
from fastapi import APIRouter, Depends, HTTPException, Query, Request

router = APIRouter(prefix="/vehicles", tags=["Vehicle Telemetry"])


def get_telemetry_service(request: Request) -> TelemetryService:
    """Retrieve the telemetry service initialized during application startup."""
    return request.app.state.telemetry_service


@router.get(
    "/{vehicle_id}/telemetry/latest",
    response_model=TelemetryResponse,
)
def get_latest_telemetry(
    vehicle_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve the latest telemetry for an associated vehicle."""
    service = get_telemetry_service(request)

    try:
        telemetry = service.get_latest_telemetry(
            current_user["id"],
            vehicle_id,
        )
    except VehicleAccessDeniedError as error:
        raise HTTPException(
            status_code=403,
            detail=str(error),
        ) from error

    if telemetry is None:
        raise HTTPException(
            status_code=404,
            detail="No telemetry available for this vehicle",
        )

    return telemetry


@router.get(
    "/{vehicle_id}/telemetry/history",
    response_model=TelemetryHistoryResponse,
)
def get_telemetry_history(
    vehicle_id: str,
    request: Request,
    start_time: Annotated[datetime, Query()],
    end_time: Annotated[datetime, Query()],
    limit: Annotated[int, Query(ge=1, le=1000)] = 100,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve historical telemetry within a specified time range."""
    service = get_telemetry_service(request)

    try:
        records = service.get_telemetry_history(
            user_id=current_user["id"],
            vehicle_id=vehicle_id,
            start_time=start_time,
            end_time=end_time,
            limit=limit,
        )
    except VehicleAccessDeniedError as error:
        raise HTTPException(
            status_code=403,
            detail=str(error),
        ) from error
    except ValueError as error:
        raise HTTPException(
            status_code=422,
            detail=str(error),
        ) from error

    return {
        "telemetry": records,
        "count": len(records),
    }
