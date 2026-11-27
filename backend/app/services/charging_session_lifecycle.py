from math import isfinite

from backend.app.core.exceptions import (
    ChargingSessionAlreadyActiveError,
    InvalidChargingTransitionError,
)
from backend.app.models.charging_session import (
    create_charging_session_document,
)
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.schemas.charging_event import (
    ChargingEvent,
    ChargingEventType,
)
from backend.app.schemas.charging_session import ChargingSessionStatus
from backend.app.services.charging_session_transitions import (
    ChargingSessionTransitions,
)
from backend.app.services.trip_calculations import normalize_utc_datetime


class ChargingSessionLifecycle:
    """Manages charging session creation and state changes."""

    def __init__(self, session_repository: ChargingSessionRepository):
        self.session_repository = session_repository
        self.transitions = ChargingSessionTransitions(session_repository)

    def start(self, event: ChargingEvent, session) -> dict:
        """Create a new charging session."""

        if not event.session_id or event.battery_percentage is None:
            raise InvalidChargingTransitionError(
                "Starting requires a session ID and battery percentage"
            )

        existing = self.session_repository.get_active_session(
            event.vehicle_id,
            session=session,
        )

        if existing is not None:
            raise ChargingSessionAlreadyActiveError(
                "Vehicle already has an active charging session"
            )

        document = create_charging_session_document(
            event,
            event.target_percentage or 100.0,
        )

        try:
            self.session_repository.create_session(
                event,
                document["target_percentage"],
                session=session,
            )
        except ValueError as exc:
            if (
                self.session_repository.get_active_session(
                    event.vehicle_id,
                    session=session,
                )
                is not None
            ):
                raise ChargingSessionAlreadyActiveError(
                    "Vehicle already has an active charging session"
                ) from exc
            raise

        return {
            "session_id": event.session_id,
            "status": ChargingSessionStatus.ACTIVE.value,
        }

    def update_progress(
        self,
        event: ChargingEvent,
        active_session: dict,
        session,
    ) -> dict:
        """Update battery and charging power measurements."""

        if (
            event.battery_percentage is None
            or event.charging_power_kw is None
            or not isfinite(event.charging_power_kw)
            or event.charging_power_kw < 0
        ):
            raise InvalidChargingTransitionError(
                "Charging progress requires valid battery and power values"
            )

        self.transitions.require_status(
            active_session,
            ChargingSessionStatus.ACTIVE,
        )

        started_at = normalize_utc_datetime(active_session["started_at"])
        event_timestamp = normalize_utc_datetime(event.timestamp)

        if event_timestamp < started_at:
            raise InvalidChargingTransitionError(
                "Event timestamp cannot precede session start"
            )

        previous_average = active_session.get("average_charging_power_kw")
        if previous_average is None:
            sample_count = 0
            previous_average = 0.0
        else:
            sample_count = active_session.get("power_sample_count", 1)

        average = (previous_average * sample_count + event.charging_power_kw) / (
            sample_count + 1
        )

        previous_peak = active_session.get("peak_charging_power_kw")
        peak_power = max(
            previous_peak if previous_peak is not None else 0.0,
            event.charging_power_kw,
        )

        self.session_repository.update_session(
            event.session_id,
            {
                "ending_battery_percentage": event.battery_percentage,
                "charging_power_kw": event.charging_power_kw,
                "average_charging_power_kw": average,
                "peak_charging_power_kw": peak_power,
                "power_sample_count": sample_count + 1,
                "duration_seconds": (event_timestamp - started_at).total_seconds(),
            },
            session=session,
        )

        return {"session_id": event.session_id, "status": "active"}

    def pause(self, event: ChargingEvent, active_session: dict, session):
        return self.transitions.pause(event, active_session, session)

    def resume(self, event: ChargingEvent, active_session: dict, session):
        return self.transitions.resume(event, active_session, session)

    def finish(
        self,
        event: ChargingEvent,
        active_session: dict,
        session,
    ) -> dict:
        """Complete or interrupt a charging session."""

        if event.event_type == ChargingEventType.COMPLETED:
            status = ChargingSessionStatus.COMPLETED
        else:
            status = ChargingSessionStatus.INTERRUPTED

        if event.battery_percentage is None:
            raise InvalidChargingTransitionError(
                "Finishing requires the final battery percentage"
            )

        return self.transitions.close(
            event,
            active_session,
            status,
            session,
        )

    def disconnect(
        self,
        event: ChargingEvent,
        active_session: dict,
        session,
    ) -> dict:
        """Close the session as interrupted after disconnection."""

        return self.transitions.close(
            event,
            active_session,
            ChargingSessionStatus.INTERRUPTED,
            session,
        )
