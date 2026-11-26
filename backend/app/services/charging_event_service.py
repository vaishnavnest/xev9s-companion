
from backend.app.core.exceptions import (
    ChargingSessionNotFoundError,
    DuplicateChargingEventError,
)
from backend.app.repositories.charging_event_repository import (
    ChargingEventRepository,
)
from backend.app.repositories.charging_session_repository import (
    ChargingSessionRepository,
)
from backend.app.schemas.charging_event import (
    ChargingEvent,
    ChargingEventType,
)
from backend.app.services.charging_session_lifecycle import (
    ChargingSessionLifecycle,
)
from pymongo.errors import DuplicateKeyError


class ChargingEventService:
    """Processes charging events and coordinates session lifecycle."""

    def __init__(
        self,
        event_repository: ChargingEventRepository,
        session_repository: ChargingSessionRepository,
        mongo_client,
    ):
        self.event_repository = event_repository
        self.session_repository = session_repository
        self.mongo_client = mongo_client
        self.lifecycle = ChargingSessionLifecycle(session_repository)

    def process_event(self, event: ChargingEvent) -> dict:
        """Persist an event and apply its session transition."""

        try:
            with (
                self.mongo_client.start_session() as session,
                session.start_transaction(),
            ):
                self.event_repository.save_event(
                    event,
                    session=session,
                )

                result = self._apply_transition(event, session)

            return result

        except DuplicateKeyError as exc:
            raise DuplicateChargingEventError(
                "Charging event has already been processed"
            ) from exc

    def _apply_transition(self, event: ChargingEvent, session) -> dict:
        """Dispatch an event to its appropriate lifecycle handler."""

        if event.event_type == ChargingEventType.CONNECTED:
            return {"status": "connected"}

        if event.event_type == ChargingEventType.CHARGING_STARTED:
            return self.lifecycle.start(event, session)

        active_session = self.session_repository.get_active_session(
            event.vehicle_id,
            session=session,
        )

        if active_session is None:
            raise ChargingSessionNotFoundError(
                "No active charging session exists"
            )

        if event.session_id != active_session["session_id"]:
            raise ChargingSessionNotFoundError(
                "Charging session does not match the active session"
            )

        handlers = {
            ChargingEventType.CHARGING_PROGRESS: (
                self.lifecycle.update_progress
            ),
            ChargingEventType.PAUSED: self.lifecycle.pause,
            ChargingEventType.RESUMED: self.lifecycle.resume,
            ChargingEventType.INTERRUPTED: self.lifecycle.finish,
            ChargingEventType.COMPLETED: self.lifecycle.finish,
            ChargingEventType.DISCONNECTED: self.lifecycle.disconnect,
        }

        handler = handlers.get(event.event_type)

        if handler is None:
            raise ValueError("Unsupported charging event type")

        return handler(event, active_session, session)
