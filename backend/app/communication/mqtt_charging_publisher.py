
import json
import logging
from typing import Any

import paho.mqtt.client as mqtt
from backend.app.core.exceptions import MQTTUnavailableError

logger = logging.getLogger(__name__)

CHARGING_PREFERENCES_TOPIC = (
    "xev9s/vehicles/{vehicle_id}/charging/preferences"
)


class MQTTChargingPublisher:
    """Publish charging preferences to the vehicle simulator."""

    def __init__(self, client: mqtt.Client) -> None:
        self.client = client

    def publish_preferences(
        self,
        vehicle_id: str,
        preferences: dict[str, Any],
    ) -> None:
        """Publish updated charging preferences to the simulator."""

        if not self.client.is_connected():
            raise MQTTUnavailableError("MQTT broker is disconnected")

        topic = CHARGING_PREFERENCES_TOPIC.format(
            vehicle_id=vehicle_id
        )

        payload = {
            **preferences,
            "vehicle_id": vehicle_id,
        }

        try:
            result = self.client.publish(
                topic,
                payload=json.dumps(payload),
                qos=1,
            )
        except (TypeError, ValueError) as exc:
            raise MQTTUnavailableError(
                "Charging preferences could not be serialized"
            ) from exc

        if result.rc != mqtt.MQTT_ERR_SUCCESS:
            raise MQTTUnavailableError(
                f"Failed to publish charging preferences to {topic}"
            )

        logger.info(
            "Published charging preferences for vehicle %s",
            vehicle_id,
        )
