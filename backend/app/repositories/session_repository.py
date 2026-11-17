
from datetime import datetime, timedelta, timezone

from pymongo.collection import Collection

from backend.app.models.session import create_session_document


class SessionRepository:
    """Handles persistent refresh-token sessions."""

    def __init__(self, collection: Collection):
        self.collection = collection

    def create_session(
        self,
        user_id: str,
        refresh_token_hash: str,
        expires_in_days: int,
    ) -> dict:
        document = create_session_document(
            user_id=user_id,
            refresh_token_hash=refresh_token_hash,
            expires_in_days=expires_in_days,
        )

        result = self.collection.insert_one(document)
        document["_id"] = result.inserted_id
        return document

    def get_session_by_refresh_hash(
        self,
        token_hash: str,
    ) -> dict | None:
        return self.collection.find_one({
            "$or": [
                {"refresh_token_hash": token_hash},
                {"rotated_token_hashes": token_hash},
            ]
        })

    def get_active_session(self, token_hash: str) -> dict | None:
        now = datetime.now(timezone.utc)

        return self.collection.find_one({
            "refresh_token_hash": token_hash,
            "revoked_at": None,
            "expires_at": {"$gt": now},
        })

    def rotate_refresh_token(
        self,
        session_id,
        old_token_hash: str,
        new_token_hash: str,
        expires_in_days: int,
    ) -> bool:
        now = datetime.now(timezone.utc)

        result = self.collection.update_one(
            {
                "_id": session_id,
                "refresh_token_hash": old_token_hash,
                "revoked_at": None,
                "expires_at": {"$gt": now},
            },
            {
                "$addToSet": {
                    "rotated_token_hashes": old_token_hash
                },
                "$set": {
                    "refresh_token_hash": new_token_hash,
                    "created_at": now,
                    "expires_at": now + timedelta(
                        days=expires_in_days
                    ),
                },
            },
        )

        return result.modified_count == 1

    def revoke_session(
        self,
        session_id,
        token_hash: str,
    ) -> bool:
        result = self.collection.update_one(
            {
                "_id": session_id,
                "refresh_token_hash": token_hash,
                "revoked_at": None,
            },
            {
                "$set": {
                    "revoked_at": datetime.now(timezone.utc)
                }
            },
        )

        return result.modified_count == 1

    def revoke_session_by_id(self, session_id) -> bool:
        result = self.collection.update_one(
            {
                "_id": session_id,
                "revoked_at": None,
            },
            {
                "$set": {
                    "revoked_at": datetime.now(timezone.utc)
                }
            },
        )

        return result.modified_count == 1
