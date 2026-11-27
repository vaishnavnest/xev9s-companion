
from datetime import UTC, datetime

from backend.app.core.exceptions import (
    InvalidChargingTransitionError,
)
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.schemas.charging_event import ChargingEvent
from backend.app.schemas.charging_session import ChargingSessionStatus


class ChargingSessionTransitions:
    """Validates and applies charging session state transitions."""

    def __init__(self, session_repository: ChargingSessionRepository):
        self.session_repository = session_repository

    @staticmethod
    def require_status(
        active_session: dict,
        expected: ChargingSessionStatus,
    ) -> None:
        """Ensure the session is in the expected state."""

        if active_session["status"] != expected.value:
            raise InvalidChargingTransitionError(
                f"Expected session status: {expected.value}"
            )

    def pause(self, event: ChargingEvent, active_session: dict, session):
        self.require_status(active_session, ChargingSessionStatus.ACTIVE)

        self.session_repository.update_session(
            event.session_id,
            {
                "status": ChargingSessionStatus.PAUSED.value,
                "charging_power_kw": 0.0,
            },
            session=session,
        )

        return {"session_id": event.session_id, "status": "paused"}

    def resume(self, event: ChargingEvent, active_session: dict, session):
        self.require_status(active_session, ChargingSessionStatus.PAUSED)

        self.session_repository.update_session(
            event.session_id,
            {"status": ChargingSessionStatus.ACTIVE.value},
            session=session,
        )

        return {"session_id": event.session_id, "status": "active"}

    def close(
        self,
        event: ChargingEvent,
        active_session: dict,
        status: ChargingSessionStatus,
        session,
    ) -> dict:
        """Close a session with its final charging details."""

        if event.timestamp < active_session["started_at"]:
            raise InvalidChargingTransitionError(
                "Event timestamp cannot precede session start"
            )

        self.session_repository.update_session(
            event.session_id,
            {
                "status": status.value,
                "ended_at": event.timestamp,
                "ending_battery_percentage": event.battery_percentage,
                "charging_power_kw": 0.0,
                "duration_seconds": (
                    event.timestamp - active_session["started_at"]
                ).total_seconds(),
                "interruption_reason": event.interruption_reason,
                "updated_at": datetime.now(UTC),
            },
            session=session,
        )

        return {"session_id": event.session_id, "status": status.value}
