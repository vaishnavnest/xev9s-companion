
from datetime import UTC, datetime
from math import isfinite

from simulator.scenarios.execution_handlers import (
    ScenarioExecutionHandlers,
)
from simulator.scenarios.execution_models import (
    ConnectivityStatus,
    ScenarioEvent,
    ScenarioExecutionUpdate,
)
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import (
    RemoteOperation,
    ScenarioStatus,
    ScenarioType,
)
from simulator.scenarios.remote_operations import execute_remote_operation
from simulator.telemetry.generator import generate_telemetry
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


class ScenarioExecutor:
    """Controls scenario lifecycle and produces execution updates."""

    def __init__(
        self,
        manager: ScenarioManager,
        engine: SimulationEngine,
    ) -> None:
        if engine.state is not manager.state:
            raise ValueError("Scenario manager and engine must share state")

        self.manager = manager
        self.engine = engine
        self.state: VehicleState = manager.state
        self.state_manager = VehicleStateManager(self.state)
        self.connectivity = ConnectivityStatus.ONLINE
        self._elapsed_seconds = 0.0
        self._pending_events: list[ScenarioEvent] = []

        self.handlers = ScenarioExecutionHandlers(
            manager,
            engine,
            self.state_manager,
            self._emit,
        )

    def _emit(
        self,
        event_type: str,
        **details: str | float | bool,
    ) -> None:
        self._pending_events.append(
            ScenarioEvent(
                event_type,
                datetime.now(UTC).isoformat(),
                details,
            )
        )

    def _update(self) -> ScenarioExecutionUpdate:
        update = ScenarioExecutionUpdate(
            self.manager.status,
            self.connectivity,
            generate_telemetry(self.state),
            tuple(self._pending_events),
        )
        self._pending_events.clear()
        return update

    def start(self) -> ScenarioExecutionUpdate:
        """Validate and start the selected scenario."""

        scenario = self.manager.selected_scenario
        config = self.manager.config

        if scenario is None or config is None:
            raise ValueError("Select a scenario before starting")

        if (
            scenario in (
                ScenarioType.DRIVING_ROUTE,
                ScenarioType.COMPLETED_JOURNEY,
            )
            and not config.route
        ):
            raise ValueError("A route is required for this driving scenario")

        if (
            scenario == ScenarioType.CONNECTIVITY_LOSS_RESTORE
            and config.offline_duration_seconds is None
        ):
            raise ValueError("Offline duration is required for this scenario")

        self.manager.start()
        self._elapsed_seconds = 0.0
        self.connectivity = ConnectivityStatus.ONLINE
        self.handlers.reset_progress()
        self._emit("SCENARIO_STARTED", scenario=scenario.value)

        if scenario == ScenarioType.LOW_BATTERY:
            self._emit(
                "LOW_BATTERY",
                battery_percentage=self.state.battery_percentage,
                threshold=config.battery_alert_threshold,
            )

        elif scenario in (
            ScenarioType.REMOTE_OP_SUCCESS,
            ScenarioType.REMOTE_OP_FAILURE,
        ):
            self._run_remote_operation(
                scenario == ScenarioType.REMOTE_OP_SUCCESS
            )

        elif (
            scenario == ScenarioType.CHARGING_TO_TARGET
            and self.state.battery_percentage
            >= config.charging_target_percentage
        ):
            self.handlers.complete_charging()

        return self._update()

    def advance(
        self,
        elapsed_seconds: float,
    ) -> ScenarioExecutionUpdate:
        """Advance a running scenario by simulated time."""

        if not isfinite(elapsed_seconds) or elapsed_seconds <= 0:
            raise ValueError("elapsed_seconds must be finite and positive")

        if self.manager.status != ScenarioStatus.RUNNING:
            raise ValueError("Only a running scenario can be advanced")

        self._elapsed_seconds += elapsed_seconds
        scenario = self.manager.selected_scenario

        self.connectivity = self.handlers.advance(
            scenario,
            elapsed_seconds,
            self._elapsed_seconds,
            self.connectivity,
        )

        return self._update()

    def _run_remote_operation(self, should_succeed: bool) -> None:
        """Execute the configured remote operation."""

        config = self.manager.config
        if config is None:
            raise ValueError("Scenario configuration is missing")

        operation = config.remote_operation

        if operation is None:
            operation = (
                RemoteOperation.UNLOCK
                if should_succeed
                else RemoteOperation.LOCK
            )

        event_type, details = execute_remote_operation(
            self.state,
            self.state_manager,
            operation.value,
        )

        self._emit(event_type, **details)
        self.manager.status = ScenarioStatus.COMPLETED

    def stop(self) -> ScenarioExecutionUpdate:
        """Stop the active scenario safely."""

        self.manager.stop()
        self.connectivity = ConnectivityStatus.ONLINE
        self._emit("SCENARIO_STOPPED")
        return self._update()

    def reset(self) -> ScenarioExecutionUpdate:
        """Restore initial state and clear execution progress."""

        self.manager.reset()
        self.connectivity = ConnectivityStatus.ONLINE
        self._elapsed_seconds = 0.0
        self.handlers.reset_progress()
        self._pending_events.clear()
        return self._update()
