
from dataclasses import dataclass, field
from datetime import UTC, datetime
from enum import Enum
from math import isfinite


class OperatingState(str, Enum):
    """Supported operating states of the simulated vehicle."""

    PARKED = "parked"
    DRIVING = "driving"
    CHARGING = "charging"
    INTERRUPTED = "interrupted"


class ChargingStatus(str, Enum):
    """Current connection and charging condition."""

    DISCONNECTED = "disconnected"
    CONNECTED = "connected"
    CHARGING = "charging"
    INTERRUPTED = "interrupted"


@dataclass(slots=True)
class VehicleState:
    """Represents the current state of one simulated vehicle."""

    vehicle_id: str
    battery_percentage: float = 80.0
    estimated_range_km: float = 300.0
    odometer_km: float = 0.0
    latitude: float | None = None
    longitude: float | None = None
    speed_kph: float = 0.0
    operating_state: OperatingState = OperatingState.PARKED
    is_locked: bool = True
    charging_status: ChargingStatus = ChargingStatus.DISCONNECTED
    charging_power_kw: float = 0.0
    cabin_preconditioning_active: bool = False
    updated_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    def __post_init__(self) -> None:
        """Validate vehicle identity, measurements and state consistency."""

        if not isinstance(self.vehicle_id, str) or not self.vehicle_id.strip():
            raise ValueError("vehicle_id must be a non-empty string")

        measurements = {
            "battery_percentage": self.battery_percentage,
            "estimated_range_km": self.estimated_range_km,
            "odometer_km": self.odometer_km,
            "speed_kph": self.speed_kph,
            "charging_power_kw": self.charging_power_kw,
        }

        for name, value in measurements.items():
            if (
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not isfinite(value)
                or value < 0
            ):
                raise ValueError(f"{name} must be a finite, non-negative number")

        if self.battery_percentage > 100:
            raise ValueError("battery_percentage cannot exceed 100")

        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Latitude and longitude must both be provided")

        if self.latitude is not None and self.longitude is not None:
            coordinates = (self.latitude, self.longitude)
            if any(
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not isfinite(value)
                for value in coordinates
            ):
                raise ValueError("Coordinates must be finite numbers")

            if not -90 <= self.latitude <= 90:
                raise ValueError("latitude must be between -90 and 90")
            if not -180 <= self.longitude <= 180:
                raise ValueError("longitude must be between -180 and 180")

        if not isinstance(self.operating_state, OperatingState):
            raise TypeError("operating_state must be an OperatingState")

        if not isinstance(self.charging_status, ChargingStatus):
            raise TypeError("charging_status must be a ChargingStatus")

        if (
            self.operating_state == OperatingState.DRIVING
            and self.charging_status == ChargingStatus.CHARGING
        ):
            raise ValueError("A vehicle cannot drive while charging")

        if (
            self.operating_state == OperatingState.CHARGING
            and self.charging_status != ChargingStatus.CHARGING
        ):
            raise ValueError("Charging state requires active charging status")

        if (
            self.operating_state == OperatingState.INTERRUPTED
            and self.charging_status != ChargingStatus.INTERRUPTED
        ):
            raise ValueError("Interrupted state requires interrupted charging status")

        if (
            self.charging_status == ChargingStatus.CHARGING
            and self.operating_state != OperatingState.CHARGING
        ):
            raise ValueError("Active charging requires charging operating state")

        if (
            self.charging_status == ChargingStatus.INTERRUPTED
            and self.operating_state != OperatingState.INTERRUPTED
        ):
            raise ValueError("Interrupted charging requires interrupted operating state")

        if (
            self.charging_status != ChargingStatus.CHARGING
            and self.charging_power_kw != 0
        ):
            raise ValueError("Charging power must be zero when not charging")

        if (
            not isinstance(self.updated_at, datetime)
            or self.updated_at.tzinfo is None
            or self.updated_at.utcoffset() is None
        ):
            raise ValueError("updated_at must be timezone-aware")
