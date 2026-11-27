from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import OperatingState, VehicleState


class ChargingEventTracker:
    """Tracks charging state transitions and emits ChargingEvent payloads."""

    def __init__(self) -> None:
        self.active_session_id: str | None = None
        self._previous_state: OperatingState | None = None

    @staticmethod
    def _build_event(
        event_type: str,
        state: VehicleState,
        session_id: str,
        target_percentage: float,
        interruption_reason: str | None = None,
    ) -> dict[str, Any]:
        return {
            "event_id": str(uuid4()),
            "vehicle_id": state.vehicle_id,
            "session_id": session_id,
            "event_type": event_type,
            "timestamp": datetime.now(UTC).isoformat(),
            "battery_percentage": round(state.battery_percentage, 2),
            "target_percentage": target_percentage,
            "charging_power_kw": state.charging_power_kw,
            "interruption_reason": interruption_reason,
        }

    def evaluate(
        self,
        state: VehicleState,
        engine: SimulationEngine,
    ) -> list[dict[str, Any]]:
        """Evaluate current state and return any charging events to publish."""
        events: list[dict[str, Any]] = []
        current_state = state.operating_state
        effective_target = (
            engine.target_percentage if engine.stop_charging_at_target else 100.0
        )

        if current_state == OperatingState.CHARGING:
            if self.active_session_id is None:
                self.active_session_id = f"chg-{uuid4().hex[:12]}"
                events.append(
                    self._build_event(
                        "charging_started",
                        state,
                        self.active_session_id,
                        effective_target,
                    )
                )
            elif self._previous_state == OperatingState.INTERRUPTED:
                events.append(
                    self._build_event(
                        "resumed",
                        state,
                        self.active_session_id,
                        effective_target,
                    )
                )
            else:
                events.append(
                    self._build_event(
                        "charging_progress",
                        state,
                        self.active_session_id,
                        effective_target,
                    )
                )
        elif (
            current_state == OperatingState.INTERRUPTED
            and self._previous_state != OperatingState.INTERRUPTED
            and self.active_session_id is not None
        ):
            events.append(
                self._build_event(
                    "interrupted",
                    state,
                    self.active_session_id,
                    effective_target,
                    interruption_reason="Charging interrupted",
                )
            )
        elif (
            current_state
            not in (OperatingState.CHARGING, OperatingState.INTERRUPTED)
            and self.active_session_id is not None
        ):
            event_type = (
                "completed"
                if state.battery_percentage >= effective_target
                else "disconnected"
            )
            events.append(
                self._build_event(
                    event_type,
                    state,
                    self.active_session_id,
                    effective_target,
                )
            )
            self.active_session_id = None

        self._previous_state = current_state
        return events
