
import secrets
from datetime import UTC, datetime, timedelta

from backend.app.core.database import (
    close_database_connection,
    connect_to_database,
)
from backend.app.core.security import hash_pairing_code
from backend.app.repositories.vehicle_repository import VehicleRepository


def main():
    database = connect_to_database()

    try:
        repository = VehicleRepository(
            vehicles_collection=database["vehicles"],
            associations_collection=database["user_vehicles"],
        )

        vehicle_id = "XEV-DEMO-001"
        vehicle = repository.get_vehicle_by_id(vehicle_id)

        if vehicle is None:
            print("Demo vehicle does not exist.")
            return

        existing_association = database["user_vehicles"].find_one(
            {
                "vehicle_id": vehicle_id,
                "association_status": "active",
            }
        )

        if existing_association:
            print("Demo vehicle is already associated.")
            return

        pairing_code = secrets.token_urlsafe(12)
        now = datetime.now(UTC)

        result = database["vehicles"].update_one(
            {
                "vehicle_id": vehicle_id,
                "is_active": True,
            },
            {
                "$set": {
                    "pairing_code_hash": hash_pairing_code(pairing_code),
                    "pairing_expires_at": now + timedelta(minutes=30),
                    "updated_at": now,
                },
                "$unset": {"pairing_code_used_at": ""},
            },
        )

        if result.modified_count != 1:
            print("Unable to refresh the pairing code.")
            return

        print("Demo vehicle pairing code refreshed.")
        print(f"Vehicle ID: {vehicle_id}")
        print(f"Pairing code: {pairing_code}")
        print("Pairing code expires in 30 minutes.")

    finally:
        close_database_connection()


if __name__ == "__main__":
    main()
