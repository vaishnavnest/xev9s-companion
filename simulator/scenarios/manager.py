
from datetime import UTC, datetime
from math import isfinite

from simulator.scenarios.models import (
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)
from simulator.scenarios.remote_state import (
    prepare_remote_operation_state,
)
from simulator.scenarios.state_snapshot import (
    copy_vehicle_state,
    restore_vehicle_state,
)
from simulator.vehicle.state import (
    ChargingStatus,
    OperatingState,
    VehicleState,
)


class ScenarioManager:
    """Controls demonstration scenario selection and lifecycle."""

    def __init__(
        self,
        state: VehicleState,
        charging_power_kw: float = 7.2,
    ) -> None:
        if not isfinite(charging_power_kw) or charging_power_kw <= 0:
            raise ValueError("Charging power must be a positive finite value")

        self.state = state
        self.charging_power_kw = charging_power_kw
        self._baseline_state = copy_vehicle_state(state)
        self.selected_scenario: ScenarioType | None = None
        self.config: ScenarioConfig | None = None
        self.status = ScenarioStatus.IDLE
        self._initial_state: VehicleState | None = None

    def select_scenario(
        self,
        scenario: ScenarioType,
        config: ScenarioConfig | None = None,
    ) -> VehicleState:
        """Select a scenario and apply its initial conditions atomically."""

        if self.status == ScenarioStatus.RUNNING:
            raise ValueError(
                "Stop the running scenario before selecting another"
            )

        if not isinstance(scenario, ScenarioType):
            raise TypeError("Invalid scenario type")

        scenario_config = config if config is not None else ScenarioConfig()
        if not isinstance(scenario_config, ScenarioConfig):
            raise TypeError("Invalid scenario configuration")

        candidate = copy_vehicle_state(self._baseline_state)
        self._apply_initial_conditions(
            candidate,
            scenario,
            scenario_config,
        )

        validated_state = copy_vehicle_state(candidate)

        restore_vehicle_state(self.state, validated_state)
        self.selected_scenario = scenario
        self.config = scenario_config
        self._initial_state = copy_vehicle_state(validated_state)
        self.status = ScenarioStatus.IDLE

        return self.state

    def _apply_initial_conditions(
        self,
        state: VehicleState,
        scenario: ScenarioType,
        config: ScenarioConfig,
    ) -> None:
        """Prepare an independent state for the selected scenario."""

        battery = config.initial_battery_percentage

        if scenario == ScenarioType.LOW_BATTERY:
            threshold = config.battery_alert_threshold

            if threshold <= 0:
                raise ValueError(
                    "Low-battery scenario requires a positive threshold"
                )

            battery = min(battery, max(0.0, threshold - 1.0))

        baseline_battery = self._baseline_state.battery_percentage
        baseline_range = self._baseline_state.estimated_range_km

        state.battery_percentage = battery
        state.estimated_range_km = (
            baseline_range * battery / baseline_battery
            if baseline_battery > 0
            else 0.0
        )

        state.speed_kph = 0.0
        state.charging_power_kw = 0.0
        state.charging_status = ChargingStatus.DISCONNECTED
        state.operating_state = OperatingState.PARKED
        state.cabin_preconditioning_active = False

        if config.route:
            state.latitude, state.longitude = config.route[0]

        if scenario in (
            ScenarioType.DRIVING_ROUTE,
            ScenarioType.COMPLETED_JOURNEY,
        ):
            state.operating_state = OperatingState.DRIVING
            state.is_locked = False

        elif scenario in (
            ScenarioType.CHARGING_TO_TARGET,
            ScenarioType.CHARGING_INTERRUPTION,
        ):
            state.operating_state = OperatingState.CHARGING
            state.charging_status = ChargingStatus.CHARGING
            state.charging_power_kw = self.charging_power_kw

        elif scenario in (
            ScenarioType.REMOTE_OP_SUCCESS,
            ScenarioType.REMOTE_OP_FAILURE,
        ):
            prepare_remote_operation_state(state, scenario, config)

        if config.initial_lock_state is not None:
            state.is_locked = config.initial_lock_state

        state.updated_at = datetime.now(UTC)

    def start(self) -> None:
        """Start a selected scenario from its initial state."""

        if self.selected_scenario is None:
            raise ValueError("No scenario has been selected")

        if self.status == ScenarioStatus.RUNNING:
            raise ValueError("Scenario is already running")

        if self.status != ScenarioStatus.IDLE:
            raise ValueError("Reset the scenario before starting it again")

        self.status = ScenarioStatus.RUNNING

    def stop(self) -> None:
        """Safely stop the active scenario."""

        if self.status != ScenarioStatus.RUNNING:
            raise ValueError("No scenario is currently running")

        self.state.operating_state = OperatingState.PARKED
        self.state.charging_status = ChargingStatus.DISCONNECTED
        self.state.charging_power_kw = 0.0
        self.state.speed_kph = 0.0
        self.state.cabin_preconditioning_active = False
        self.state.updated_at = datetime.now(UTC)

        self.status = ScenarioStatus.STOPPED

    def reset(self) -> VehicleState:
        """Restore the selected scenario's initial vehicle state."""

        if self._initial_state is None:
            raise ValueError("Select a scenario before resetting")

        restore_vehicle_state(self.state, self._initial_state)
        self.status = ScenarioStatus.IDLE

        return self.state
