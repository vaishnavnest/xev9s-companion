
from bson import ObjectId
from pymongo.collection import Collection
from pymongo.errors import DuplicateKeyError

from backend.app.models.user import create_user_document


class UserRepository:
    """Handles MongoDB operations for users."""

    def __init__(self, collection: Collection):
        self.collection = collection

    def create_user(
        self,
        email: str,
        full_name: str,
        password_hash: str,
    ) -> dict:
        document = create_user_document(
            email=email,
            full_name=full_name,
            password_hash=password_hash,
        )

        try:
            result = self.collection.insert_one(document)
        except DuplicateKeyError:
            raise ValueError("An account with this email already exists")

        document["_id"] = result.inserted_id
        return document

    def get_user_by_email(self, email: str) -> dict | None:
        normalized_email = email.strip().lower()
        return self.collection.find_one({"email": normalized_email})

    def get_user_by_id(self, user_id: str) -> dict | None:
        if not ObjectId.is_valid(user_id):
            return None

        return self.collection.find_one({"_id": ObjectId(user_id)})
