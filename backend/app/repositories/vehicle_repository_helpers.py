from bson import ObjectId


def validate_user_object_id(user_id: str) -> ObjectId:
    """Validate and convert a user identifier string to ObjectId."""
    if not ObjectId.is_valid(user_id):
        raise ValueError("Invalid user identifier")
    return ObjectId(user_id)


def build_user_vehicle_summaries(
    associations: list[dict],
    vehicles: dict[str, dict],
) -> list[dict]:
    """Combine active user associations with vehicle metadata."""
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
