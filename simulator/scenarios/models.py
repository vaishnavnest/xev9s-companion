
from dataclasses import dataclass
from enum import Enum
from math import isfinite


class ScenarioType(str, Enum):
    """Demonstration scenarios required by the XEV 9S project."""

    PARKED_BATTERY_LEVEL = "PARKED_BATTERY_LEVEL"
    DRIVING_ROUTE = "DRIVING_ROUTE"
    CHARGING_TO_TARGET = "CHARGING_TO_TARGET"
    CHARGING_INTERRUPTION = "CHARGING_INTERRUPTION"
    REMOTE_OP_SUCCESS = "REMOTE_OP_SUCCESS"
    REMOTE_OP_FAILURE = "REMOTE_OP_FAILURE"
    CONNECTIVITY_LOSS_RESTORE = "CONNECTIVITY_LOSS_RESTORE"
    LOW_BATTERY = "LOW_BATTERY"
    COMPLETED_JOURNEY = "COMPLETED_JOURNEY"


class ScenarioStatus(str, Enum):
    """Lifecycle status of a demonstration scenario."""

    IDLE = "idle"
    RUNNING = "running"
    STOPPED = "stopped"
    COMPLETED = "completed"

class RemoteOperation(str, Enum):
    """Supported remote vehicle operations."""

    LOCK = "LOCK"
    UNLOCK = "UNLOCK"
    START_CABIN_PRECONDITIONING = "START_CABIN_PRECONDITIONING"
    STOP_CABIN_PRECONDITIONING = "STOP_CABIN_PRECONDITIONING"

@dataclass(frozen=True, slots=True)
class ScenarioConfig:
    """Configurable initial conditions for a vehicle scenario."""

    initial_battery_percentage: float = 80.0
    charging_target_percentage: float = 80.0
    battery_alert_threshold: float = 20.0
    initial_lock_state: bool | None = None
    remote_operation: RemoteOperation | None = None
    offline_duration_seconds: int | None = None
    route: tuple[tuple[float, float], ...] = ()

    def __post_init__(self) -> None:
        """Validate scenario configuration values."""

        percentages = {
            "initial_battery_percentage": self.initial_battery_percentage,
            "charging_target_percentage": self.charging_target_percentage,
            "battery_alert_threshold": self.battery_alert_threshold,
        }

        for name, value in percentages.items():
            if not isfinite(value) or not 0 <= value <= 100:
                raise ValueError(f"{name} must be between 0 and 100")

        if (
            self.initial_lock_state is not None
            and not isinstance(self.initial_lock_state, bool)
        ):
            raise TypeError("initial_lock_state must be a boolean or None")

        if (
            self.remote_operation is not None
            and not isinstance(self.remote_operation, RemoteOperation)
        ):
            raise TypeError(
                "remote_operation must be a RemoteOperation or None"
            )

        duration = self.offline_duration_seconds
        if duration is not None and (
            not isfinite(duration) or duration <= 0
        ):
            raise ValueError(
                "offline_duration_seconds must be finite and positive"
            )

        if self.route and len(self.route) < 2:
            raise ValueError("A route must contain at least two coordinates")

        for latitude, longitude in self.route:
            if not isfinite(latitude) or not -90 <= latitude <= 90:
                raise ValueError("Route latitude must be between -90 and 90")
            if not isfinite(longitude) or not -180 <= longitude <= 180:
                raise ValueError("Route longitude must be between -180 and 180")
