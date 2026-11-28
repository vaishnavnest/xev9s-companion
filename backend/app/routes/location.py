from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.repositories.telemetry_repository import TelemetryRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.schemas.location import VehicleLocationResponse
from backend.app.services.geocoding_service import GeocodingService
from backend.app.services.location_service import LocationService
from fastapi import APIRouter, Depends, HTTPException, Request, status

router = APIRouter(prefix="/vehicles", tags=["Vehicle Location"])


def get_location_service(request: Request) -> LocationService:
    """Retrieve or build the location service."""
    if hasattr(request.app.state, "location_service"):
        return request.app.state.location_service

    database = request.app.state.database
    service = LocationService(
        vehicle_repository=VehicleRepository(
            database["vehicles"],
            database["user_vehicles"],
        ),
        telemetry_repository=TelemetryRepository(database["vehicle_telemetry"]),
        geocoding_service=GeocodingService(),
    )
    request.app.state.location_service = service
    return service


@router.get(
    "/{vehicle_id}/location",
    response_model=VehicleLocationResponse,
    status_code=status.HTTP_200_OK,
)
def get_vehicle_location(
    vehicle_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve the latest valid coordinates and connectivity status."""
    service = get_location_service(request)

    try:
        return service.get_vehicle_location(
            user_id=current_user["id"],
            vehicle_id=vehicle_id,
        )
    except VehicleAccessDeniedError as error:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(error),
        ) from error
    except VehicleNotActiveError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
