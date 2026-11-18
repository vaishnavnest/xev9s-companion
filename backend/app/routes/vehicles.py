
from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    InvalidPairingCodeError,
    VehicleAlreadyAssociatedError,
)
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.schemas.vehicle import (
    VehicleAssociationRequest,
    VehicleListResponse,
)
from backend.app.services.vehicle_service import VehicleService
from fastapi import APIRouter, Depends, HTTPException, Request, status

router = APIRouter(prefix="/vehicles", tags=["Vehicles"])


def get_vehicle_service(request: Request) -> VehicleService:
    """Build vehicle service using the application database."""

    database = request.app.state.database

    return VehicleService(
        VehicleRepository(
            vehicles_collection=database["vehicles"],
            associations_collection=database["user_vehicles"],
        )
    )


@router.get("", response_model=VehicleListResponse)
def get_my_vehicles(
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve vehicles associated with the authenticated user."""

    service = get_vehicle_service(request)

    return {
        "vehicles": service.get_user_vehicles(current_user["id"])
    }


@router.post(
    "/associate",
    response_model=VehicleListResponse,
    status_code=status.HTTP_201_CREATED,
)
def associate_vehicle(
    data: VehicleAssociationRequest,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Associate a vehicle and return the updated vehicle list."""

    service = get_vehicle_service(request)

    try:
        service.associate_vehicle(
            user_id=current_user["id"],
            vehicle_id=data.vehicle_id,
            pairing_code=data.pairing_code,
        )
    except InvalidPairingCodeError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    except VehicleAlreadyAssociatedError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error

    return {
        "vehicles": service.get_user_vehicles(current_user["id"])
    }
