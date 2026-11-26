
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChargingSessionStatus(str, Enum):
    """Lifecycle statuses for charging sessions."""

    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    INTERRUPTED = "interrupted"
    CANCELLED = "cancelled"


class ChargingSessionResponse(BaseModel):
    """Charging session details returned to the application."""

    model_config = ConfigDict(extra="ignore")

    session_id: str
    vehicle_id: str

    started_at: datetime
    ended_at: datetime | None = None

    starting_battery_percentage: float = Field(ge=0, le=100)
    ending_battery_percentage: float | None = Field(
        default=None,
        ge=0,
        le=100,
    )

    target_percentage: float = Field(ge=0, le=100)
    final_target_percentage: float | None = Field(
        default=None,
        ge=0,
        le=100,
    )

    charging_power_kw: float = Field(ge=0)
    average_charging_power_kw: float | None = Field(default=None, ge=0)
    peak_charging_power_kw: float | None = Field(default=None, ge=0)

    duration_seconds: float = Field(ge=0)
    status: ChargingSessionStatus
    interruption_reason: str | None = None

    @field_validator("started_at", "ended_at")
    @classmethod
    def validate_timestamps(
        cls,
        value: datetime | None,
    ) -> datetime | None:
        """Require timezone-aware session timestamps."""

        if value is not None and (
            value.tzinfo is None or value.utcoffset() is None
        ):
            raise ValueError("Session timestamps must include a timezone")

        return value


class ChargingSessionHistoryResponse(BaseModel):
    """Charging history returned for a vehicle."""

    sessions: list[ChargingSessionResponse]
    count: int
