
from datetime import UTC, datetime

from backend.app.core.exceptions import (
    InvalidPairingCodeError,
    VehicleAlreadyAssociatedError,
)
from backend.app.models.vehicle import (
    create_user_vehicle_document,
    create_vehicle_document,
)
from bson import ObjectId
from pymongo.collection import Collection
from pymongo.errors import DuplicateKeyError


class VehicleRepository:
    """Handles MongoDB operations for vehicles and user associations."""

    def __init__(
        self,
        vehicles_collection: Collection,
        associations_collection: Collection,
    ):
        self.vehicles = vehicles_collection
        self.associations = associations_collection

    def register_vehicle(
        self,
        vehicle_id: str,
        model: str,
        pairing_code_hash: str,
        pairing_expires_at: datetime,
    ) -> dict:
        """Register a trusted vehicle."""

        document = create_vehicle_document(
            vehicle_id=vehicle_id,
            model=model,
            pairing_code_hash=pairing_code_hash,
            pairing_expires_at=pairing_expires_at,
        )

        try:
            result = self.vehicles.insert_one(document)
        except DuplicateKeyError as exc:
            raise ValueError(
                "Vehicle identifier already exists"
            ) from exc

        document["_id"] = result.inserted_id
        return document

    def get_vehicle_by_id(self, vehicle_id: str) -> dict | None:
        """Find a vehicle using its identifier."""

        return self.vehicles.find_one({"vehicle_id": vehicle_id})

    def get_active_vehicle_by_id(self, vehicle_id: str) -> dict | None:
        """Find an active vehicle using its identifier."""

        return self.vehicles.find_one(
            {
                "vehicle_id": vehicle_id,
                "is_active": True,
            }
        )

    def associate_vehicle(
        self,
        user_id: str,
        vehicle_id: str,
        pairing_code_hash: str,
    ) -> None:
        """Consume a pairing code and create an association atomically."""

        if not ObjectId.is_valid(user_id):
            raise ValueError("Invalid user identifier")

        user_object_id = ObjectId(user_id)

        existing_association = self.associations.find_one(
            {
                "user_id": user_object_id,
                "vehicle_id": vehicle_id,
            }
        )

        if existing_association is not None:
            raise VehicleAlreadyAssociatedError(
                "Vehicle is already associated with this account"
            )

        now = datetime.now(UTC)

        with(
                self.vehicles.database.client.start_session() as session,
                session.start_transaction(),
            ):
                vehicle = self.vehicles.find_one_and_update(
                    {
                        "vehicle_id": vehicle_id,
                        "pairing_code_hash": pairing_code_hash,
                        "pairing_expires_at": {"$gt": now},
                        "is_active": True,
                        "pairing_code_used_at": {"$exists": False},
                    },
                    {
                        "$set": {
                            "pairing_code_used_at": now,
                            "updated_at": now,
                        }
                    },
                    session=session,
                )

                if vehicle is None:
                    raise InvalidPairingCodeError(
                        "Invalid, expired, or already-used pairing code"
                    )

                document = create_user_vehicle_document(
                    user_id=user_object_id,
                    vehicle_id=vehicle_id,
                )

                try:
                    self.associations.insert_one(
                        document,
                        session=session,
                    )
                except DuplicateKeyError as exc:
                    raise VehicleAlreadyAssociatedError(
                        "Vehicle is already associated with this account"
                    ) from exc

    def is_vehicle_associated_with_user(
        self,
        user_id: str,
        vehicle_id: str,
        ) -> bool:
        """Check whether a vehicle has an active association with a user."""

        if not ObjectId.is_valid(user_id):
            raise ValueError("Invalid user identifier")

        association = self.associations.find_one(
            {
                "user_id": ObjectId(user_id),
                "vehicle_id": vehicle_id,
                "association_status": "active",
            },
            {"_id": 1},
        )

        return association is not None


    def get_user_vehicles(self, user_id: str) -> list[dict]:
        """Retrieve vehicles associated with a specific user."""

        if not ObjectId.is_valid(user_id):
            raise ValueError("Invalid user identifier")

        user_object_id = ObjectId(user_id)

        associations = list(
            self.associations.find(
                {
                "user_id": user_object_id,
                "association_status": "active",
                }
            ).sort("associated_at", -1)
        )

        vehicle_ids = [
            association["vehicle_id"]
            for association in associations
        ]

        if not vehicle_ids:
            return []

        vehicles = {
            vehicle["vehicle_id"]: vehicle
            for vehicle in self.vehicles.find(
                {"vehicle_id": {"$in": vehicle_ids}}
            )
        }

        return [
            {
                "vehicle_id": association["vehicle_id"],
                "model": vehicles[association["vehicle_id"]]["model"],
                "association_status": association["association_status"],
                "associated_at": association["associated_at"],
            }
            for association in associations
            if association["vehicle_id"] in vehicles
        ]
