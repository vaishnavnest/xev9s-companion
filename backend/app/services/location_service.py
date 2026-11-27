import threading
from datetime import UTC, datetime
from math import asin, cos, isfinite, radians, sin, sqrt
from typing import Literal

from backend.app.core.command_config import VEHICLE_ONLINE_TIMEOUT_SECONDS
from backend.app.core.exceptions import VehicleAccessDeniedError, VehicleNotActiveError
from backend.app.repositories.telemetry_repository import TelemetryRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from backend.app.schemas.location import VehicleLocationResponse
from backend.app.services.geocoding_service import GeocodingService

EARTH_RADIUS_METERS = 6_371_008.8
GEOCODE_DISTANCE_THRESHOLD_METERS = 150.0


def _haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate Haversine distance between two coordinates in metres."""
    phi1, lambda1, phi2, lambda2 = (
        radians(lat1),
        radians(lon1),
        radians(lat2),
        radians(lon2),
    )
    haversine = (
        sin((phi2 - phi1) / 2) ** 2
        + cos(phi1) * cos(phi2) * sin((lambda2 - lambda1) / 2) ** 2
    )
    return 2 * EARTH_RADIUS_METERS * asin(sqrt(haversine))


def _is_valid_coordinates(latitude: object, longitude: object) -> bool:
    """Return True when both coordinates are finite and within valid GPS bounds."""
    if (
        isinstance(latitude, bool)
        or isinstance(longitude, bool)
        or not isinstance(latitude, (int, float))
        or not isinstance(longitude, (int, float))
    ):
        return False
    return (
        isfinite(latitude)
        and isfinite(longitude)
        and -90 <= latitude <= 90
        and -180 <= longitude <= 180
    )


class LocationService:
    """Orchestrates vehicle location retrieval and connectivity analysis."""

    def __init__(
        self,
        vehicle_repository: VehicleRepository,
        telemetry_repository: TelemetryRepository,
        online_timeout_seconds: int = VEHICLE_ONLINE_TIMEOUT_SECONDS,
        geocoding_service: GeocodingService | None = None,
    ) -> None:
        self.vehicle_repository = vehicle_repository
        self.telemetry_repository = telemetry_repository
        self.online_timeout_seconds = online_timeout_seconds
        self.geocoding_service = geocoding_service
        self._geocode_lock = threading.Lock()
        self._vehicle_geocode_cache: dict[str, tuple[float, float, str]] = {}

    @staticmethod
    def _normalize_datetime(timestamp: object) -> datetime | None:
        """Ensure datetimes are timezone-aware in UTC."""
        if not isinstance(timestamp, datetime):
            return None
        if timestamp.tzinfo is None or timestamp.utcoffset() is None:
            return timestamp.replace(tzinfo=UTC)
        return timestamp.astimezone(UTC)

    def _validate_access(self, user_id: str, vehicle_id: str) -> str:
        """Validate vehicle identity, active status, and user ownership."""
        normalized_id = vehicle_id.strip()
        if not normalized_id:
            raise ValueError("Vehicle identifier cannot be empty")

        vehicle = self.vehicle_repository.get_vehicle_by_id(normalized_id)
        if vehicle is None or not vehicle.get("is_active", False):
            raise VehicleNotActiveError("Vehicle is not registered or active")

        if not self.vehicle_repository.is_vehicle_associated_with_user(
            user_id, normalized_id
        ):
            raise VehicleAccessDeniedError("You do not have access to this vehicle")

        return normalized_id

    def get_vehicle_location(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> VehicleLocationResponse:
        """Retrieve latest valid location and evaluate freshness."""
        normalized_id = self._validate_access(user_id, vehicle_id)

        latest_telemetry = self.telemetry_repository.get_latest_telemetry(normalized_id)
        connectivity_status: Literal["online", "offline"] = "offline"
        operating_state = None

        if latest_telemetry is not None:
            operating_state = latest_telemetry.get("operating_state")
            tel_timestamp = self._normalize_datetime(latest_telemetry.get("timestamp"))
            if tel_timestamp is not None:
                age = (datetime.now(UTC) - tel_timestamp).total_seconds()
                if 0 <= age <= self.online_timeout_seconds:
                    connectivity_status = "online"

        latest_loc = self.telemetry_repository.get_latest_valid_location(normalized_id)
        if latest_loc is None:
            return VehicleLocationResponse(
                vehicle_id=normalized_id,
                latitude=None,
                longitude=None,
                timestamp=None,
                is_current=False,
                connectivity_status=connectivity_status,
                operating_state=operating_state,
            )

        latitude = latest_loc.get("latitude")
        longitude = latest_loc.get("longitude")
        loc_timestamp = self._normalize_datetime(latest_loc.get("timestamp"))

        if loc_timestamp is not None:
            loc_age = (datetime.now(UTC) - loc_timestamp).total_seconds()
            is_current = (
                connectivity_status == "online"
                and 0 <= loc_age <= self.online_timeout_seconds
            )
        else:
            is_current = False

        return VehicleLocationResponse(
            vehicle_id=normalized_id,
            latitude=latitude,
            longitude=longitude,
            timestamp=loc_timestamp,
            is_current=is_current,
            connectivity_status=connectivity_status,
            operating_state=operating_state,
            description=self._resolve_description(normalized_id, latitude, longitude),
        )

    def _resolve_description(
        self,
        vehicle_id: str,
        latitude: object,
        longitude: object,
    ) -> str | None:
        """Resolve a cached or distance-gated location description lazily."""
        if self.geocoding_service is None or not _is_valid_coordinates(
            latitude, longitude
        ):
            return None

        lat, lon = float(latitude), float(longitude)  # type: ignore[arg-type]

        with self._geocode_lock:
            last = self._vehicle_geocode_cache.get(vehicle_id)
            if last is not None:
                last_lat, last_lon, last_desc = last
                if (
                    _haversine_meters(last_lat, last_lon, lat, lon)
                    < GEOCODE_DISTANCE_THRESHOLD_METERS
                ):
                    return last_desc

        cached = self.geocoding_service.get_cached(lat, lon)
        if cached is not None:
            with self._geocode_lock:
                self._vehicle_geocode_cache[vehicle_id] = (lat, lon, cached)
            return cached

        def _on_success(description: str) -> None:
            with self._geocode_lock:
                self._vehicle_geocode_cache[vehicle_id] = (lat, lon, description)

        self.geocoding_service.schedule_lookup(lat, lon, on_success=_on_success)
        return None
