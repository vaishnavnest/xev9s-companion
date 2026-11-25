
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict


class RemoteOperation(str, Enum):
    """Supported remote vehicle operations."""

    LOCK = "lock"
    UNLOCK = "unlock"
    START_CABIN_PRECONDITIONING = "start_cabin_preconditioning"
    STOP_CABIN_PRECONDITIONING = "stop_cabin_preconditioning"


class CommandStatus(str, Enum):
    """Lifecycle statuses for remote vehicle commands."""

    SUBMITTED = "submitted"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    TIMED_OUT = "timed_out"


class CommandRequest(BaseModel):
    """Remote operation requested for a vehicle."""

    model_config = ConfigDict(extra="forbid")

    operation: RemoteOperation


class CommandResponse(BaseModel):
    """Command execution information returned to the application."""

    command_id: str
    vehicle_id: str
    operation: RemoteOperation
    status: CommandStatus
    requested_at: datetime
    completed_at: datetime | None = None
    failure_reason: str | None = None
