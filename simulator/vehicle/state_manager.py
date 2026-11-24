
from datetime import UTC, datetime

from simulator.vehicle.state import (
    ChargingStatus,
    OperatingState,
    VehicleState,
)


class VehicleStateManager:
    """Controls valid state transitions for a simulated vehicle."""

    def __init__(self, state: VehicleState) -> None:
        self.state = state

    def _require_operating_state(self, expected: OperatingState) -> None:
        if self.state.operating_state != expected:
            raise ValueError(
                f"Operation requires vehicle to be {expected.value}"
            )

    def _finalize_transition(self) -> VehicleState:
        self.state.updated_at = datetime.now(UTC)
        self.state.__post_init__()
        return self.state

    def start_driving(self) -> VehicleState:
        """Transition a parked vehicle into driving mode."""
        self._require_operating_state(OperatingState.PARKED)

        if self.state.charging_status != ChargingStatus.DISCONNECTED:
            raise ValueError("Vehicle must be disconnected from the charger")

        self.state.operating_state = OperatingState.DRIVING
        return self._finalize_transition()

    def stop_driving(self) -> VehicleState:
        """Stop driving and return the vehicle to parked mode."""
        self._require_operating_state(OperatingState.DRIVING)

        self.state.operating_state = OperatingState.PARKED
        self.state.speed_kph = 0.0
        return self._finalize_transition()

    def start_charging(self) -> VehicleState:
        """Start charging a parked vehicle."""
        self._require_operating_state(OperatingState.PARKED)

        if self.state.charging_status not in (
            ChargingStatus.DISCONNECTED,
            ChargingStatus.CONNECTED,
        ):
            raise ValueError("Vehicle cannot start charging in its current state")

        self.state.operating_state = OperatingState.CHARGING
        self.state.charging_status = ChargingStatus.CHARGING
        return self._finalize_transition()

    def stop_charging(self) -> VehicleState:
        """Stop active charging and return the vehicle to parked mode."""
        self._require_operating_state(OperatingState.CHARGING)

        self.state.operating_state = OperatingState.PARKED
        self.state.charging_status = ChargingStatus.DISCONNECTED
        self.state.charging_power_kw = 0.0
        return self._finalize_transition()

    def interrupt_charging(self) -> VehicleState:
        """Interrupt an active charging session."""
        self._require_operating_state(OperatingState.CHARGING)

        self.state.operating_state = OperatingState.INTERRUPTED
        self.state.charging_status = ChargingStatus.INTERRUPTED
        self.state.charging_power_kw = 0.0
        return self._finalize_transition()

    def lock_vehicle(self) -> VehicleState:
        """Lock the vehicle."""
        if self.state.is_locked:
            raise ValueError("Vehicle is already locked")

        self.state.is_locked = True
        return self._finalize_transition()

    def unlock_vehicle(self) -> VehicleState:
        """Unlock the vehicle."""
        if not self.state.is_locked:
            raise ValueError("Vehicle is already unlocked")

        self.state.is_locked = False
        return self._finalize_transition()

    def start_cabin_preconditioning(self) -> VehicleState:
        """Activate cabin preconditioning."""
        if self.state.cabin_preconditioning_active:
            raise ValueError("Cabin preconditioning is already active")

        self.state.cabin_preconditioning_active = True
        return self._finalize_transition()

    def stop_cabin_preconditioning(self) -> VehicleState:
        """Deactivate cabin preconditioning."""
        if not self.state.cabin_preconditioning_active:
            raise ValueError("Cabin preconditioning is not active")

        self.state.cabin_preconditioning_active = False
        return self._finalize_transition()
