
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChargingEventType(str, Enum):
    """Supported charging lifecycle events."""

    CONNECTED = "connected"
    CHARGING_STARTED = "charging_started"
    CHARGING_PROGRESS = "charging_progress"
    PAUSED = "paused"
    RESUMED = "resumed"
    INTERRUPTED = "interrupted"
    COMPLETED = "completed"
    DISCONNECTED = "disconnected"


class ChargingEvent(BaseModel):
    """Validated charging event received from the simulator."""

    model_config = ConfigDict(extra="forbid")

    event_id: str = Field(min_length=1, max_length=128)
    vehicle_id: str = Field(min_length=1, max_length=64)
    session_id: str | None = Field(default=None, max_length=128)

    event_type: ChargingEventType
    timestamp: datetime

    battery_percentage: float | None = Field(
        default=None,
        ge=0,
        le=100,
    )
    charging_power_kw: float | None = Field(
        default=None,
        ge=0,
    )
    target_percentage: float | None = Field(
        default=None,
        ge=0,
        le=100,
    )
    interruption_reason: str | None = Field(
        default=None,
        max_length=500,
    )

    @field_validator("event_id", "vehicle_id", "session_id")
    @classmethod
    def validate_identifiers(cls, value: str | None) -> str | None:
        """Strip whitespace and reject blank identifiers."""

        if value is None:
            return None

        value = value.strip()
        if not value:
            raise ValueError("Identifier cannot be empty or whitespace")

        return value

    @field_validator("timestamp")
    @classmethod
    def validate_timestamp_timezone(cls, value: datetime) -> datetime:
        """Require timezone-aware event timestamps."""

        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("Event timestamp must include a timezone")

        return value

    @field_validator("interruption_reason")
    @classmethod
    def validate_interruption_reason(
        cls,
        value: str | None,
    ) -> str | None:
        """Normalize optional interruption reasons."""

        if value is None:
            return None

        value = value.strip()
        return value or None

    @field_validator("charging_power_kw")
    @classmethod
    def validate_power_for_event(
        cls,
        value: float | None,
    ) -> float | None:
        """Allow zero power but reject negative power."""

        return value
