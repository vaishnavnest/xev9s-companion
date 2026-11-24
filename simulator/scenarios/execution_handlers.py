from collections.abc import Callable

from simulator.scenarios.execution_models import ConnectivityStatus
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import ScenarioStatus, ScenarioType
from simulator.scenarios.route import advance_route, calculate_distance
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import OperatingState, VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


class ScenarioExecutionHandlers:
    """Handles scenario-specific vehicle simulation behaviour."""

    def __init__(
        self,
        manager: ScenarioManager,
        engine: SimulationEngine,
        state_manager: VehicleStateManager,
        emit: Callable[..., None],
    ) -> None:
        self.manager = manager
        self.engine = engine
        self.state: VehicleState = manager.state
        self.state_manager = state_manager
        self.emit = emit
        self.route_segment_index = 0
        self.starting_odometer = self.state.odometer_km

    def reset_progress(self) -> None:
        """Reset route progress after scenario reset or restart."""
        self.route_segment_index = 0
        self.starting_odometer = self.state.odometer_km

    def advance(
        self,
        scenario: ScenarioType,
        elapsed_seconds: float,
        total_elapsed: float,
        connectivity: ConnectivityStatus,
    ) -> ConnectivityStatus:
        """Execute the selected scenario's next simulation step."""
        if scenario in (
            ScenarioType.DRIVING_ROUTE,
            ScenarioType.COMPLETED_JOURNEY,
        ):
            self._advance_driving(elapsed_seconds)

        elif scenario == ScenarioType.CHARGING_TO_TARGET:
            self._advance_charging(elapsed_seconds)

        elif scenario == ScenarioType.CHARGING_INTERRUPTION:
            self.state_manager.interrupt_charging()
            self.manager.status = ScenarioStatus.COMPLETED
            self.emit("CHARGING_INTERRUPTED")

        elif scenario == ScenarioType.CONNECTIVITY_LOSS_RESTORE:
            connectivity = self._advance_connectivity(
                total_elapsed,
                connectivity,
            )

        return connectivity

    def _advance_driving(self, elapsed_seconds: float) -> None:
        route = self.manager.config.route

        remaining = sum(
            calculate_distance(route[index], route[index + 1])
            for index in range(self.route_segment_index, len(route) - 1)
        )

        if remaining <= 0:
            self._complete_journey()
            return

        allowed_seconds = (
            remaining / self.engine.config.driving_speed_kph * 3600
        )
        self.engine.advance(min(elapsed_seconds, allowed_seconds))

        travelled = self.state.odometer_km - self.starting_odometer
        progress = advance_route(
            route,
            0,
            travelled,
        )

        self.route_segment_index = progress.segment_index
        self.state.latitude = progress.latitude
        self.state.longitude = progress.longitude

        if progress.completed:
            self._complete_journey()
        elif self.state.operating_state != OperatingState.DRIVING:
            self.manager.status = ScenarioStatus.COMPLETED
            self.emit("JOURNEY_ENDED", reason="BATTERY_DEPLETED")

    def _complete_journey(self) -> None:
        if self.state.operating_state == OperatingState.DRIVING:
            self.state_manager.stop_driving()

        self.manager.status = ScenarioStatus.COMPLETED
        self.emit("JOURNEY_COMPLETED", odometer_km=self.state.odometer_km)

    def _advance_charging(self, elapsed_seconds: float) -> None:
        target = self.manager.config.charging_target_percentage

        if self.state.battery_percentage >= target:
            self.complete_charging()
            return

        power = self.engine.config.charging_power_kw
        capacity = self.engine.config.battery_capacity_kwh
        energy_needed = (
            (target - self.state.battery_percentage) * capacity / 100
        )
        seconds_to_target = energy_needed / power * 3600

        self.engine.advance(min(elapsed_seconds, seconds_to_target))

        if self.state.battery_percentage >= target:
            self.state.battery_percentage = target
            self.complete_charging()

    def complete_charging(self) -> None:
        if self.state.operating_state == OperatingState.CHARGING:
            self.state_manager.stop_charging()

        self.manager.status = ScenarioStatus.COMPLETED
        self.emit(
            "CHARGING_TARGET_REACHED",
            battery_percentage=self.state.battery_percentage,
        )

    def _advance_connectivity(
        self,
        total_elapsed: float,
        connectivity: ConnectivityStatus,
    ) -> ConnectivityStatus:
        duration = self.manager.config.offline_duration_seconds

        if connectivity == ConnectivityStatus.ONLINE:
            connectivity = ConnectivityStatus.OFFLINE
            self.emit("CONNECTIVITY_LOST")

        if total_elapsed >= duration:
            connectivity = ConnectivityStatus.ONLINE
            self.manager.status = ScenarioStatus.COMPLETED
            self.emit("CONNECTIVITY_RESTORED")

        return connectivity
