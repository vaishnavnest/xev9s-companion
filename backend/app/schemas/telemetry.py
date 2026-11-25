
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

OperatingState = Literal[
    "parked",
    "driving",
    "charging",
    "interrupted",
]

ChargingStatus = Literal[
    "disconnected",
    "connected",
    "charging",
    "interrupted",
]


class TelemetryPayload(BaseModel):
    """Validated telemetry received from a simulated vehicle."""

    model_config = ConfigDict(extra="forbid")

    vehicle_id: str = Field(min_length=1, max_length=64)
    timestamp: datetime

    battery_percentage: float = Field(ge=0, le=100)
    estimated_range_km: float = Field(ge=0)
    speed_kph: float = Field(ge=0)
    odometer_km: float = Field(ge=0)

    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)

    operating_state: OperatingState
    is_locked: bool
    charging_status: ChargingStatus
    charging_power_kw: float = Field(ge=0)
    cabin_preconditioning_active: bool

    @field_validator("timestamp")
    @classmethod
    def validate_timestamp_timezone(cls, value: datetime) -> datetime:
        """Require timezone-aware telemetry timestamps."""

        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("Telemetry timestamp must include a timezone")
        return value

    @model_validator(mode="after")
    def validate_coordinates(self):
        """Require both GPS coordinates or neither."""
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError(
                "Latitude and longitude must both be provided"
            )
        return self

class TelemetryResponse(BaseModel):
    """Represent a stored vehicle telemetry record."""
    model_config = ConfigDict(extra="ignore")

    vehicle_id: str
    timestamp: datetime
    battery_percentage: float
    estimated_range_km: float
    speed_kph: float
    odometer_km: float
    latitude: float | None
    longitude: float | None
    operating_state: OperatingState
    is_locked: bool
    charging_status: ChargingStatus
    charging_power_kw: float
    cabin_preconditioning_active: bool
    received_at: datetime


class TelemetryHistoryResponse(BaseModel):
    """Represent a collection of historical telemetry records."""

    telemetry: list[TelemetryResponse]
    count: int
