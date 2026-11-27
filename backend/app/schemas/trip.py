from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class TripStatus(str, Enum):
    ONGOING = "ongoing"
    COMPLETED = "completed"


class NamedLocation(BaseModel):
    model_config = ConfigDict(extra="ignore")

    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    description: str | None = None


class RoutePoint(BaseModel):
    model_config = ConfigDict(extra="ignore")

    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    timestamp: datetime | None = None
    speed_kmh: float | None = Field(default=None, ge=0)


class BatteryRange(BaseModel):
    model_config = ConfigDict(extra="ignore")

    start_percent: float | None = Field(default=None, ge=0, le=100)
    end_percent: float | None = Field(default=None, ge=0, le=100)


class Pagination(BaseModel):
    model_config = ConfigDict(extra="ignore")

    page: int = Field(ge=1)
    page_size: int = Field(ge=1)
    total_items: int = Field(ge=0)
    total_pages: int = Field(ge=0)


class Trip(BaseModel):
    model_config = ConfigDict(extra="ignore")

    trip_id: str
    status: TripStatus
    started_at: datetime
    ended_at: datetime | None = None
    start_location: NamedLocation
    end_location: NamedLocation | None = None
    distance_km: float | None = Field(default=None, ge=0)
    duration_seconds: int | None = Field(default=None, ge=0)
    energy_consumed_kwh: float | None = Field(default=None, ge=0)


class TripDetail(Trip):
    average_speed_kmh: float | None = Field(default=None, ge=0)
    battery: BatteryRange | None = None
    route: list[RoutePoint] = Field(default_factory=list)


class TripListResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    trips: list[Trip]
    pagination: Pagination
