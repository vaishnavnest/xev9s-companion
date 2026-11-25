
import json
import logging
import re
from collections.abc import Callable
from typing import Any

import paho.mqtt.client as mqtt
from backend.app.core.exceptions import MQTTUnavailableError

logger = logging.getLogger(__name__)

COMMAND_TOPIC = "xev9s/vehicles/{vehicle_id}/commands"
RESPONSE_TOPIC = "xev9s/vehicles/+/responses"

RESPONSE_TOPIC_PATTERN = re.compile(
    r"^xev9s/vehicles/([A-Za-z0-9_-]+)/responses$"
)


class MQTTCommandHandler:
    """Publish remote commands and process simulator responses."""

    def __init__(
        self,
        client: mqtt.Client,
        on_response: Callable[[dict[str, Any]], None],
    ) -> None:
        self.client = client
        self.on_response = on_response

    def subscribe_responses(self) -> None:
        """Subscribe to simulator command responses."""
        if not self.client.is_connected():
            raise MQTTUnavailableError("MQTT broker is disconnected")

        result, _ = self.client.subscribe(RESPONSE_TOPIC, qos=1)

        if result != mqtt.MQTT_ERR_SUCCESS:
            raise MQTTUnavailableError(
                "Failed to subscribe to command responses"
            )

        logger.info("Subscribed to %s", RESPONSE_TOPIC)

    def publish_command(
        self,
        vehicle_id: str,
        payload: dict[str, Any],
    ) -> None:
        """Publish a remote command to the vehicle simulator."""
        if not self.client.is_connected():
            raise MQTTUnavailableError("MQTT broker is disconnected")

        topic = COMMAND_TOPIC.format(vehicle_id=vehicle_id)

        try:
            result = self.client.publish(topic, payload=json.dumps(payload), qos=1)
        except (ValueError, TypeError) as exc:
            raise MQTTUnavailableError(
                "Command payload could not be serialized"
            ) from exc

        if result.rc != mqtt.MQTT_ERR_SUCCESS:
            raise MQTTUnavailableError(
                f"Failed to publish command to {topic}"
            )

        logger.info("Published remote command to %s", topic)

    def handle_response(
        self,
        topic: str,
        payload: bytes,
    ) -> None:
        """Validate and forward a simulator command response."""
        match = RESPONSE_TOPIC_PATTERN.fullmatch(topic)

        if match is None:
            logger.warning("Ignoring invalid command response topic: %s", topic)
            return

        try:
            response = json.loads(payload)

            if not isinstance(response, dict):
                raise TypeError("Response must be a JSON object")

            if response.get("vehicle_id") != match.group(1):
                logger.warning(
                    "Command response vehicle ID does not match topic: %s",
                    topic,
                )
                return

            self.on_response(response)

        except (json.JSONDecodeError, UnicodeDecodeError, ValueError):
            logger.warning(
                "Rejected invalid command response on %s",
                topic,
                exc_info=True,
            )
        except Exception:
            logger.exception(
                "Failed to process command response from %s",
                topic,
            )
