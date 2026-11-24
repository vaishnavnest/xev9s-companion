
from dataclasses import dataclass
from datetime import UTC, datetime
from math import isfinite

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
        if self.state.battery_percentage >= 100:
            self._complete_charging()
            return

        energy_added = (
            self.config.charging_power_kw * elapsed_seconds / 3600
        )
        battery_increase = (
            energy_added / self.config.battery_capacity_kwh * 100
        )

        if battery_increase >= 100 - self.state.battery_percentage:
            self.state.battery_percentage = 100.0
            self._complete_charging()
            return

        self.state.battery_percentage += battery_increase
        self.state.charging_power_kw = self.config.charging_power_kw
        self._update_range()
        self._update_timestamp()

    def _complete_charging(self) -> None:
        """Finish charging and return the vehicle to parked state."""

        self.state.battery_percentage = 100.0
        self.state.operating_state = OperatingState.PARKED
        self.state.charging_status = ChargingStatus.DISCONNECTED
        self.state.charging_power_kw = 0.0
        self._update_range()
        self._update_timestamp()
