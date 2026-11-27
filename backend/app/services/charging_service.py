
from datetime import datetime

from backend.app.communication.mqtt_charging_publisher import (
    MQTTChargingPublisher,
)
from backend.app.core.exceptions import (
    ChargingSessionNotFoundError,
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
from backend.app.schemas.charging import ChargingPreferencesUpdate
from backend.app.schemas.charging_session import ChargingSessionStatus


class ChargingService:
    """Coordinates charging preferences and session lifecycle."""

    def __init__(
        self,
        charging_repository: ChargingRepository,
        session_repository: ChargingSessionRepository,
        event_repository: ChargingEventRepository,
        vehicle_repository: VehicleRepository,
        mongo_client,
        mqtt_publisher: MQTTChargingPublisher | None = None,
    ):
        self.charging_repository = charging_repository
        self.session_repository = session_repository
        self.event_repository = event_repository
        self.vehicle_repository = vehicle_repository
        self.mongo_client = mongo_client
        self.mqtt_publisher = mqtt_publisher

    def _validate_vehicle(self, vehicle_id: str) -> str:
        """Ensure the vehicle exists and is active."""

        normalized_id = vehicle_id.strip()

        if not normalized_id:
            raise ValueError("Vehicle identifier cannot be empty")

        vehicle = self.vehicle_repository.get_active_vehicle_by_id(
            normalized_id
        )

        if vehicle is None:
            raise VehicleNotActiveError(
                "Vehicle is not registered or active"
            )

        return normalized_id

    def _validate_ownership(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> None:
        """Ensure the user owns the requested vehicle."""

        if not self.vehicle_repository.is_vehicle_associated_with_user(
            user_id,
            vehicle_id,
        ):
            raise VehicleAccessDeniedError(
                "You do not have access to this vehicle"
            )

    def update_preferences(
        self,
        user_id: str,
        vehicle_id: str,
        preferences: ChargingPreferencesUpdate,
    ) -> dict:
        """Save preferences and update an active session target."""

        normalized_id = self._validate_vehicle(vehicle_id)
        self._validate_ownership(user_id, normalized_id)

        with (
            self.mongo_client.start_session() as session,
            session.start_transaction(),
        ):
            saved = self.charging_repository.save_preferences(
                normalized_id,
                preferences,
                session=session,
            )

            active_session = self.session_repository.get_active_session(
                normalized_id,
                session=session,
            )

            if active_session is not None:
                self.session_repository.update_session(
                    active_session["session_id"],
                    {
                        "final_target_percentage": (
                            preferences.target_percentage
                        )
                    },
                    session=session,
                )

        if self.mqtt_publisher is not None:
            self.mqtt_publisher.publish_preferences(
                normalized_id,
                preferences.model_dump(mode="json"),
            )

        return saved

    def get_preferences(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> dict | None:
        """Retrieve preferences and active session after checking ownership."""

        normalized_id = self._validate_vehicle(vehicle_id)
        self._validate_ownership(user_id, normalized_id)

        preferences = self.charging_repository.get_preferences(normalized_id)
        if preferences is None:
            return None

        active_session = self.session_repository.get_active_session(normalized_id)
        return {
            **preferences,
            "active_session": active_session,
        }

    def get_session_history(
        self,
        user_id: str,
        vehicle_id: str,
        limit: int = 20,
        offset: int = 0,
        status: ChargingSessionStatus | None = None,
        from_time: datetime | None = None,
        to_time: datetime | None = None,
        sort: str = "-started_at",
    ) -> tuple[list[dict], int]:
        """Retrieve filtered charging history after checking ownership."""

        normalized_id = self._validate_vehicle(vehicle_id)
        self._validate_ownership(user_id, normalized_id)

        if not 1 <= limit <= 100:
            raise ValueError("Limit must be between 1 and 100")

        if offset < 0:
            raise ValueError("Offset cannot be negative")

        if from_time is not None and to_time is not None and from_time > to_time:
            raise ValueError("Start filter timestamp cannot be after end timestamp")

        return self.session_repository.get_session_history(
            normalized_id,
            limit,
            offset,
            status=status,
            from_time=from_time,
            to_time=to_time,
            sort=sort,
        )

    def get_session_detail(
        self,
        user_id: str,
        vehicle_id: str,
        session_id: str,
    ) -> dict:
        """Retrieve a single charging session after checking ownership."""

        normalized_id = self._validate_vehicle(vehicle_id)
        self._validate_ownership(user_id, normalized_id)

        normalized_session_id = session_id.strip()
        if not normalized_session_id:
            raise ValueError("Session identifier cannot be empty")

        session = self.session_repository.get_session(normalized_session_id)
        if session is None or session.get("vehicle_id") != normalized_id:
            raise ChargingSessionNotFoundError(
                f"Charging session {normalized_session_id} not found for vehicle {normalized_id}"
            )

        return session
