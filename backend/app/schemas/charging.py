
from datetime import time
from enum import Enum
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from backend.app.schemas.charging_session import ChargingSessionResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class Weekday(str, Enum):
    """Days available for scheduled charging."""

    SUNDAY = "sunday"
    MONDAY = "monday"
    TUESDAY = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY = "thursday"
    FRIDAY = "friday"
    SATURDAY = "saturday"


class ChargingPreferencesUpdate(BaseModel):
    """Charging preferences submitted by an authenticated user."""

    model_config = ConfigDict(extra="forbid")

    target_percentage: float = Field(ge=0, le=100)
    schedule_enabled: bool = False
    scheduled_start_time: time | None = None
    scheduled_end_time: time | None = None
    scheduled_days: list[Weekday] = Field(default_factory=list)
    timezone: str = Field(min_length=1, max_length=64)
    stop_charging_at_target: bool = True

    @field_validator("timezone")
    @classmethod
    def validate_timezone(cls, value: str) -> str:
        """Accept only recognized IANA timezone identifiers."""

        value = value.strip()
        if not value:
            raise ValueError("Timezone cannot be empty")

        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("Unknown timezone") from exc

        return value

    @field_validator("scheduled_days")
    @classmethod
    def validate_unique_days(cls, value: list[Weekday]) -> list[Weekday]:
        """Reject duplicate weekdays."""

        if len(value) != len(set(value)):
            raise ValueError("Scheduled days must be unique")
        return value

    @model_validator(mode="after")
    def validate_schedule(self):
        """Validate required fields when scheduled charging is enabled."""

        if self.schedule_enabled:
            if self.scheduled_start_time is None:
                raise ValueError("Scheduled start time is required")

            if self.scheduled_end_time is None:
                raise ValueError("Scheduled end time is required")

            if self.scheduled_start_time == self.scheduled_end_time:
                raise ValueError("Schedule start and end times must differ")

            if not self.scheduled_days:
                raise ValueError("Select at least one scheduled day")

        return self


class ChargingPreferencesResponse(BaseModel):
    """Charging preferences returned by the backend."""

    model_config = ConfigDict(extra="ignore")

    vehicle_id: str
    target_percentage: float
    schedule_enabled: bool
    scheduled_start_time: time | None
    scheduled_end_time: time | None
    scheduled_days: list[Weekday]
    timezone: str
    stop_charging_at_target: bool
    active_session: ChargingSessionResponse | None = None
