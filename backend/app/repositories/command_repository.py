
from datetime import datetime

from backend.app.models.command import create_command_document
from backend.app.schemas.command import CommandRequest, CommandStatus
from pymongo import DESCENDING
from pymongo.collection import Collection


class CommandRepository:
    """Handles MongoDB persistence for remote vehicle commands."""

    def __init__(self, collection: Collection):
        self.collection = collection

    def create_command(
        self,
        user_id: str,
        vehicle_id: str,
        request: CommandRequest,
    ) -> dict:
        """Persist a newly submitted command."""

        document = create_command_document(
            user_id=user_id,
            vehicle_id=vehicle_id,
            request=request,
        )
        self.collection.insert_one(document)
        return document

    def get_command(
        self,
        vehicle_id: str,
        command_id: str,
        user_id: str,
    ) -> dict | None:
        """Retrieve a command belonging to a user and vehicle."""

        return self.collection.find_one(
            {
                "command_id": command_id,
                "vehicle_id": vehicle_id,
                "user_id": user_id,
            },
            {"_id": 0},
        )

    def get_vehicle_commands(
        self,
        vehicle_id: str,
        user_id: str,
        limit: int = 100,
    ) -> list[dict]:
        """Retrieve a user's command history for a vehicle."""

        cursor = (
            self.collection.find(
                {
                    "vehicle_id": vehicle_id,
                    "user_id": user_id,
                },
                {"_id": 0},
            )
            .sort("requested_at", DESCENDING)
            .limit(limit)
        )
        return list(cursor)

    def get_command_for_response(
        self,
        command_id: str,
        vehicle_id: str,
    ) -> dict | None:
        """Retrieve a command for validating a simulator response."""

        return self.collection.find_one(
            {
                "command_id": command_id,
                "vehicle_id": vehicle_id,
            },
            {"_id": 0},
        )

    def update_command_result(
        self,
        command_id: str,
        vehicle_id: str,
        status: CommandStatus,
        completed_at: datetime,
        failure_reason: str | None = None,
    ) -> bool:
        """Record a result only while the command is submitted."""

        if status not in {
            CommandStatus.SUCCEEDED,
            CommandStatus.FAILED,
        }:
            raise ValueError("Invalid execution result status")

        result = self.collection.update_one(
            {
                "command_id": command_id,
                "vehicle_id": vehicle_id,
                "status": CommandStatus.SUBMITTED.value,
            },
            {
                "$set": {
                    "status": status.value,
                    "completed_at": completed_at,
                    "failure_reason": failure_reason,
                }
            },
        )
        return result.modified_count == 1

    def mark_command_timed_out(
        self,
        command_id: str,
        vehicle_id: str,
        completed_at: datetime,
    ) -> bool:
        """Mark a pending command timed out without overwriting final status."""

        result = self.collection.update_one(
            {
                "command_id": command_id,
                "vehicle_id": vehicle_id,
                "status": CommandStatus.SUBMITTED.value,
            },
            {
                "$set": {
                    "status": CommandStatus.TIMED_OUT.value,
                    "completed_at": completed_at,
                    "failure_reason": "Command execution timed out",
                }
            },
        )
        return result.modified_count == 1
