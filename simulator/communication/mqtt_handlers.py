import json
import logging

from simulator.communication.message_handler import MQTTMessageHandler
from simulator.communication.mqtt_client import MQTTClient
from simulator.vehicle.simulation_engine import SimulationEngine

logger = logging.getLogger(__name__)


def on_mqtt_connected(mqtt_client: MQTTClient) -> None:
    """Subscribe to command and charging preferences topics after connecting."""
    mqtt_client.subscribe(mqtt_client.command_topic, qos=1)
    mqtt_client.subscribe(mqtt_client.charging_preferences_topic, qos=1)
    logger.info(
        "Listening for commands on %s and preferences on %s",
        mqtt_client.command_topic,
        mqtt_client.charging_preferences_topic,
    )


def handle_charging_preferences(
    payload: bytes,
    engine: SimulationEngine,
) -> None:
    """Parse and apply incoming charging preferences."""
    try:
        data = json.loads(payload)
    except (json.JSONDecodeError, UnicodeDecodeError):
        logger.warning("Ignoring invalid JSON charging preferences payload")
        return

    if not isinstance(data, dict):
        logger.warning("Ignoring non-object charging preferences payload")
        return

    try:
        engine.update_charging_preferences(data)
    except ValueError:
        logger.warning("Ignoring invalid charging preferences values")
        return

    logger.info(
        "Updated charging preferences: target=%.1f%%, stop_at_target=%s",
        engine.target_percentage,
        engine.stop_charging_at_target,
    )


def handle_mqtt_command(
    topic: str,
    payload: bytes,
    message_handler: MQTTMessageHandler,
    mqtt_client: MQTTClient,
    engine: SimulationEngine | None = None,
) -> None:
    """Execute an incoming command or charging preferences update."""
    if (
        engine is not None
        and topic == mqtt_client.charging_preferences_topic
    ):
        handle_charging_preferences(payload, engine)
        return

    if topic != mqtt_client.command_topic:
        logger.warning("Ignoring unexpected MQTT topic: %s", topic)
        return

    response = message_handler.handle_message(payload)

    try:
        mqtt_client.publish(
            mqtt_client.response_topic,
            json.dumps(response),
            qos=1,
        )
    except RuntimeError:
        logger.exception("Failed to publish command response")
        return

    logger.info(
        "Processed command %s with status %s",
        response.get("command_id"),
        response.get("status"),
    )
