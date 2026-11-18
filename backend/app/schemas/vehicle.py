
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class VehicleAssociationRequest(BaseModel):
    """Vehicle identifier and pairing code submitted for association."""

    model_config = ConfigDict(extra="forbid")

    vehicle_id: str = Field(min_length=1, max_length=64)
    pairing_code: str = Field(min_length=1, max_length=128)

    @field_validator("vehicle_id", "pairing_code")
    @classmethod
    def strip_and_validate_required_fields(cls, value: str) -> str:
        """Strip whitespace and reject blank values."""
        value = value.strip()
        if not value:
            raise ValueError("Field cannot be empty or whitespace")
        return value


class VehicleResponse(BaseModel):
    """Vehicle information returned to its associated user."""

    vehicle_id: str
    model: str
    association_status: Literal["active"]
    associated_at: datetime


class VehicleListResponse(BaseModel):
    """List of vehicles associated with the authenticated user."""

    vehicles: list[VehicleResponse]
