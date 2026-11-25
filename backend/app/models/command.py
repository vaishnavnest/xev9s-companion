
from datetime import UTC, datetime
from uuid import uuid4

from backend.app.schemas.command import (
    CommandRequest,
    CommandStatus,
)


def create_command_document(
    user_id: str,
    vehicle_id: str,
    request: CommandRequest,
) -> dict:
    """Build a MongoDB document for a newly submitted command."""

    now = datetime.now(UTC)

    return {
        "command_id": str(uuid4()),
        "user_id": user_id,
        "vehicle_id": vehicle_id,
        "operation": request.operation.value,
        "status": CommandStatus.SUBMITTED.value,
        "requested_at": now,
        "completed_at": None,
        "failure_reason": None,
    }
