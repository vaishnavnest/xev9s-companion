
from fastapi import APIRouter, Depends, HTTPException, Request, status

from backend.app.repositories.user_repository import UserRepository
from backend.app.repositories.session_repository import SessionRepository
from backend.app.services.auth_service import AuthService
from backend.app.schemas.user import (
    UserCreate,
    UserLogin,
    UserResponse,
    TokenResponse,
    RefreshTokenRequest,
)

from backend.app.core.dependencies import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


def get_auth_service(request: Request) -> AuthService:
    """Build authentication service using the app database."""

    database = request.app.state.database

    return AuthService(
        users=UserRepository(database["users"]),
        sessions=SessionRepository(database["sessions"]),
    )


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_user(data: UserCreate, request: Request):
    service = get_auth_service(request)

    try:
        return service.register(
            email=data.email,
            password=data.password,
            full_name=data.full_name,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error


@router.post("/login", response_model=TokenResponse)
def login_user(data: UserLogin, request: Request):
    service = get_auth_service(request)

    try:
        return service.login(
            email=data.email,
            password=data.password,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(error),
            headers={"WWW-Authenticate": "Bearer"},
        ) from error


@router.post("/refresh", response_model=TokenResponse)
def refresh_access_token(
    data: RefreshTokenRequest,
    request: Request,
):
    service = get_auth_service(request)

    try:
        return service.refresh(data.refresh_token)
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(error),
        ) from error


@router.post("/logout")
def logout_user(data: RefreshTokenRequest, request: Request):
    service = get_auth_service(request)

    revoked = service.logout(data.refresh_token)

    if not revoked:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or already revoked refresh token",
        )

    return {"message": "Logged out successfully"}

@router.get("/me", response_model=UserResponse)
def get_my_profile(
    current_user: dict = Depends(get_current_user),
):
    return current_user