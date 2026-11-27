
from dataclasses import dataclass
from datetime import UTC, datetime
from math import isfinite
from typing import Any

from simulator.vehicle.state import (
    ChargingStatus,
    OperatingState,
    VehicleState,
)


@dataclass(frozen=True, slots=True)
class SimulationConfig:
    """Configurable parameters for vehicle simulation."""

    driving_speed_kph: float = 60.0
    energy_consumption_kwh_per_100km: float = 16.0
    battery_capacity_kwh: float = 60.0
    charging_power_kw: float = 7.2

    def __post_init__(self) -> None:
        values = (
            self.driving_speed_kph,
            self.energy_consumption_kwh_per_100km,
            self.battery_capacity_kwh,
            self.charging_power_kw,
        )
        if any(not isfinite(value) or value <= 0 for value in values):
            raise ValueError(
                "Simulation parameters must be finite and positive"
            )


class SimulationEngine:
    """Updates vehicle measurements as simulated time passes."""

    def __init__(
        self,
        state: VehicleState,
        config: SimulationConfig | None = None,
    ) -> None:
        self.state = state
        self.config = config or SimulationConfig()
        self.target_percentage: float = 100.0
        self.stop_charging_at_target: bool = True
        self.schedule_enabled: bool = False
        self.scheduled_start_time: str | None = None
        self.scheduled_end_time: str | None = None
        self.scheduled_days: list[str] = []
        self.timezone: str = "UTC"

    def update_charging_preferences(self, preferences: dict[str, Any]) -> None:
        """Apply incoming charging preferences to the simulation engine."""
        if "target_percentage" in preferences:
            target = preferences["target_percentage"]
            if (
                isinstance(target, bool)
                or not isinstance(target, (int, float))
                or not isfinite(target)
                or not 0 <= target <= 100
            ):
                raise ValueError("target_percentage must be between 0 and 100")
            self.target_percentage = float(target)

        if "stop_charging_at_target" in preferences:
            self.stop_charging_at_target = bool(
                preferences["stop_charging_at_target"]
            )

        if "schedule_enabled" in preferences:
            self.schedule_enabled = bool(preferences["schedule_enabled"])

        if "scheduled_start_time" in preferences:
            self.scheduled_start_time = preferences["scheduled_start_time"]

        if "scheduled_end_time" in preferences:
            self.scheduled_end_time = preferences["scheduled_end_time"]

        if "scheduled_days" in preferences and isinstance(
            preferences["scheduled_days"], list
        ):
            self.scheduled_days = list(preferences["scheduled_days"])

        if "timezone" in preferences and isinstance(
            preferences["timezone"], str
        ):
            self.timezone = preferences["timezone"]

    def advance(self, elapsed_seconds: float) -> VehicleState:
        """Advance vehicle measurements by the specified elapsed time."""

        if not isfinite(elapsed_seconds) or elapsed_seconds <= 0:
            raise ValueError(
                "elapsed_seconds must be finite and positive"
            )

        if self.state.operating_state == OperatingState.DRIVING:
            self._advance_driving(elapsed_seconds)
        elif self.state.operating_state == OperatingState.CHARGING:
            self._advance_charging(elapsed_seconds)

        return self.state

    def _update_timestamp(self) -> None:
        """Update timestamp without moving backwards in time."""

        now = datetime.now(UTC)
        self.state.updated_at = max(
            now,
            self.state.updated_at,
        )

    def _update_range(self) -> None:
        """Recalculate estimated range from current battery level."""

        self.state.estimated_range_km = (
            self.state.battery_percentage
            * self.config.battery_capacity_kwh
            / self.config.energy_consumption_kwh_per_100km
        )

    def _advance_driving(self, elapsed_seconds: float) -> None:
        distance = (
            self.config.driving_speed_kph * elapsed_seconds / 3600
        )
        energy_required = (
            distance
            * self.config.energy_consumption_kwh_per_100km
            / 100
        )
        available_energy = (
            self.state.battery_percentage
            * self.config.battery_capacity_kwh
            / 100
        )

        if energy_required >= available_energy:
            distance = (
                available_energy
                * 100
                / self.config.energy_consumption_kwh_per_100km
            )
            self.state.battery_percentage = 0.0
            self.state.operating_state = OperatingState.PARKED
            self.state.speed_kph = 0.0
        else:
            battery_drop = (
                energy_required
                / self.config.battery_capacity_kwh
                * 100
            )
            self.state.battery_percentage -= battery_drop
            self.state.speed_kph = self.config.driving_speed_kph

        self.state.odometer_km += distance
        self._update_range()
        self._update_timestamp()

    def _advance_charging(self, elapsed_seconds: float) -> None:
        effective_target = (
            self.target_percentage if self.stop_charging_at_target else 100.0
        )

        if self.state.battery_percentage >= effective_target:
            self._complete_charging()
            return

        energy_added = (
            self.config.charging_power_kw * elapsed_seconds / 3600
        )
        battery_increase = (
            energy_added / self.config.battery_capacity_kwh * 100
        )

        if battery_increase >= effective_target - self.state.battery_percentage:
            self.state.battery_percentage = effective_target
            self._complete_charging()
            return

        self.state.battery_percentage += battery_increase
        self.state.charging_power_kw = self.config.charging_power_kw
        self._update_range()
        self._update_timestamp()

    def _complete_charging(self) -> None:
        """Finish charging and return the vehicle to parked state."""

        self.state.operating_state = OperatingState.PARKED
        self.state.charging_status = ChargingStatus.DISCONNECTED
        self.state.charging_power_kw = 0.0
        self._update_range()
        self._update_timestamp()
