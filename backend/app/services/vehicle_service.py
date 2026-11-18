
from backend.app.core.security import hash_pairing_code
from backend.app.repositories.vehicle_repository import VehicleRepository


class VehicleService:
    """Implements vehicle association and retrieval operations."""

    def __init__(self, repository: VehicleRepository):
        self.repository = repository

    def associate_vehicle(
        self,
        user_id: str,
        vehicle_id: str,
        pairing_code: str,
    ) -> None:
        """Validate pairing information and associate a vehicle."""

        normalized_vehicle_id = vehicle_id.strip()

        if not normalized_vehicle_id:
            raise ValueError("Vehicle identifier cannot be empty")

        if not pairing_code:
            raise ValueError("Pairing code cannot be empty")

        pairing_code_hash = hash_pairing_code(pairing_code)

        self.repository.associate_vehicle(
            user_id=user_id,
            vehicle_id=normalized_vehicle_id,
            pairing_code_hash=pairing_code_hash,
        )

    def get_user_vehicles(self, user_id: str) -> list[dict]:
        """Retrieve vehicles belonging to the specified user."""

        return self.repository.get_user_vehicles(user_id)

    def is_vehicle_associated_with_user(
        self,
        user_id: str,
        vehicle_id: str,
    ) -> bool:
        """Check whether a user has access to a specific vehicle."""

        normalized_vehicle_id = vehicle_id.strip()

        if not normalized_vehicle_id:
            raise ValueError("Vehicle identifier cannot be empty")

        return self.repository.is_vehicle_associated_with_user(
            user_id=user_id,
            vehicle_id=normalized_vehicle_id,
        )
