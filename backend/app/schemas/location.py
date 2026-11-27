from datetime import datetime
from typing import Literal

from backend.app.schemas.telemetry import OperatingState
from pydantic import BaseModel, ConfigDict, Field


class VehicleLocationResponse(BaseModel):
    """Represent the latest or last-known vehicle location."""

    model_config = ConfigDict(extra="ignore")

    vehicle_id: str = Field(min_length=1, max_length=64)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    timestamp: datetime | None = None
    is_current: bool
    connectivity_status: Literal["online", "offline"]
    operating_state: OperatingState | None = None
