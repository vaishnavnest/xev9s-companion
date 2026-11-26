from backend.app.core.dependencies import get_current_user
from backend.app.core.exceptions import (
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
    VehicleOfflineError,
)
from backend.app.schemas.command import CommandRequest, CommandResponse
from fastapi import APIRouter, Depends, HTTPException, Request, status

router = APIRouter(
    prefix="/vehicles/{vehicle_id}/commands",
    tags=["Vehicle Commands"],
)


def get_command_service(request: Request):
    """Retrieve the command service initialized by the application."""

    return request.app.state.command_service


def handle_command_error(error: Exception) -> None:
    """Translate command service exceptions into HTTP responses."""

    if isinstance(error, VehicleAccessDeniedError):
        code = status.HTTP_403_FORBIDDEN
    elif isinstance(error, VehicleNotActiveError):
        code = status.HTTP_404_NOT_FOUND
    elif isinstance(error, VehicleOfflineError):
        code = status.HTTP_409_CONFLICT
    elif isinstance(error, MQTTUnavailableError):
        code = status.HTTP_503_SERVICE_UNAVAILABLE
    elif isinstance(error, ValueError):
        code = status.HTTP_400_BAD_REQUEST
    else:
        raise error

    raise HTTPException(
        status_code=code,
        detail=str(error),
    ) from error


@router.post(
    "",
    response_model=CommandResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
def submit_vehicle_command(
    vehicle_id: str,
    data: CommandRequest,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Submit a remote command to an associated vehicle."""

    service = get_command_service(request)

    try:
        return service.submit_command(
            user_id=current_user["id"],
            vehicle_id=vehicle_id,
            request=data,
        )
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        VehicleOfflineError,
        MQTTUnavailableError,
        ValueError,
    ) as error:
        handle_command_error(error)


@router.get(
    "",
    response_model=list[CommandResponse],
)
def get_vehicle_commands(
    vehicle_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve command history for an associated vehicle."""

    service = get_command_service(request)

    try:
        return service.get_commands(
            user_id=current_user["id"],
            vehicle_id=vehicle_id,
        )
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        ValueError,
    ) as error:
        handle_command_error(error)


@router.get(
    "/{command_id}",
    response_model=CommandResponse,
)
def get_vehicle_command(
    vehicle_id: str,
    command_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve one command belonging to an associated vehicle."""

    service = get_command_service(request)

    try:
        command = service.get_command(
            user_id=current_user["id"],
            vehicle_id=vehicle_id,
            command_id=command_id,
        )
    except (
        VehicleAccessDeniedError,
        VehicleNotActiveError,
        ValueError,
    ) as error:
        handle_command_error(error)

    if command is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Command not found",
        )

    return command
