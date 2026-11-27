
import json
import logging
import re
from collections.abc import Callable
from typing import Any

from backend.app.core.exceptions import (
    ChargingSessionAlreadyActiveError,
    ChargingSessionNotFoundError,
    DuplicateChargingEventError,
    InvalidChargingTransitionError,
)
from backend.app.schemas.charging_event import ChargingEvent
from backend.app.services.charging_event_service import (
    ChargingEventService,
)
from pydantic import ValidationError

logger = logging.getLogger(__name__)

CHARGING_EVENTS_TOPIC = "xev9s/vehicles/+/charging/events"

CHARGING_TOPIC_PATTERN = re.compile(
    r"^xev9s/vehicles/([A-Za-z0-9_-]+)/charging/events$"
)


class MQTTChargingHandler:
    """Validate and process incoming charging lifecycle events."""

    def __init__(
        self,
        charging_service: ChargingEventService,
        on_charging: Callable[[dict[str, Any]], None] | None = None,
    ) -> None:
        self.charging_service = charging_service
        self.on_charging = on_charging

    def handle_message(self, topic: str, payload: bytes) -> None:
        """Validate topic and payload before processing an event."""

        match = CHARGING_TOPIC_PATTERN.fullmatch(topic)

        if match is None:
            logger.warning("Ignoring invalid charging topic: %s", topic)
            return

        vehicle_id = match.group(1)

        try:
            event = ChargingEvent.model_validate(json.loads(payload))

            if event.vehicle_id != vehicle_id:
                logger.warning(
                    "Charging vehicle ID does not match topic: %s",
                    topic,
                )
                return

            result = self.charging_service.process_event(event)

            if self.on_charging is not None:
                self.on_charging(
                    {
                        "type": "charging_update",
                        "vehicle_id": vehicle_id,
                        "event": event.model_dump(mode="json"),
                        "session": result,
                    }
                )

        except DuplicateChargingEventError:
            logger.info("Ignoring duplicate charging event: %s", vehicle_id)
        except (
            ChargingSessionAlreadyActiveError,
            ChargingSessionNotFoundError,
            InvalidChargingTransitionError,
        ):
            logger.warning(
                "Rejected charging lifecycle event for %s",
                vehicle_id,
                exc_info=True,
            )
        except (json.JSONDecodeError, ValidationError, UnicodeDecodeError):
            logger.warning(
                "Rejected invalid charging payload on %s",
                topic,
                exc_info=True,
            )
        except Exception:
            logger.exception(
                "Failed to process charging event for %s",
                vehicle_id,
            )
