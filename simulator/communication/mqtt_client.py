import logging
import os
from collections.abc import Callable

import paho.mqtt.client as mqtt
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

MessageCallback = Callable[[str, bytes], None]
ConnectionCallback = Callable[[], None]


class MQTTClient:
    """Manage the simulator's connection to an MQTT broker."""

    def __init__(
        self,
        vehicle_id: str = "XEV-001",
        message_callback: MessageCallback | None = None,
        on_connected: ConnectionCallback | None = None,
    ) -> None:
        if not vehicle_id.strip() or any(
            character in vehicle_id for character in "/+#"
        ):
            raise ValueError("Vehicle ID is invalid for MQTT topics")

        host = os.getenv("MQTT_BROKER_HOST", "127.0.0.1")
        port = int(os.getenv("MQTT_BROKER_PORT", "1884"))
        keepalive = int(os.getenv("MQTT_KEEPALIVE", "60"))

        if not host.strip():
            raise ValueError("MQTT broker host cannot be empty")
        if not 1 <= port <= 65535:
            raise ValueError("MQTT broker port must be between 1 and 65535")
        if keepalive <= 0:
            raise ValueError("MQTT keepalive must be positive")

        self.vehicle_id = vehicle_id
        self.host = host
        self.port = port
        self.keepalive = keepalive
        self._connected = False
        self._message_callback = message_callback
        self._on_connected_callback = on_connected

        self.client = mqtt.Client(
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
            client_id=f"xev9s-simulator-{vehicle_id}",
            protocol=mqtt.MQTTv311,
        )
        self.client.reconnect_delay_set(min_delay=1, max_delay=30)

        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message

    @property
    def is_connected(self) -> bool:
        """Return whether the client is connected to the broker."""
        return self._connected

    @property
    def command_topic(self) -> str:
        """Return this vehicle's command subscription topic."""
        return f"xev9s/vehicles/{self.vehicle_id}/commands"

    @property
    def response_topic(self) -> str:
        """Return this vehicle's command response topic."""
        return f"xev9s/vehicles/{self.vehicle_id}/responses"

    @property
    def telemetry_topic(self) -> str:
        """Return this vehicle's telemetry publication topic."""
        return f"xev9s/vehicles/{self.vehicle_id}/telemetry"

    @property
    def charging_events_topic(self) -> str:
        """Return this vehicle's charging events publication topic."""
        return f"xev9s/vehicles/{self.vehicle_id}/charging/events"

    @property
    def charging_preferences_topic(self) -> str:
        """Return this vehicle's charging preferences subscription topic."""
        return f"xev9s/vehicles/{self.vehicle_id}/charging/preferences"

    def _on_connect(
        self,
        client: mqtt.Client,
        userdata: object,
        flags: mqtt.ConnectFlags,
        reason_code: mqtt.ReasonCode,
        properties: mqtt.Properties | None,
    ) -> None:
        """Update connection status after the broker responds."""
        if reason_code.is_failure:
            self._connected = False
            logger.error("MQTT connection rejected: %s", reason_code)
            return

        self._connected = True
        logger.info("Connected to MQTT broker at %s:%s", self.host, self.port)

        if self._on_connected_callback is not None:
            try:
                self._on_connected_callback()
            except Exception:
                logger.exception("MQTT connection callback failed")

    def _on_disconnect(
        self,
        client: mqtt.Client,
        userdata: object,
        disconnect_flags: mqtt.DisconnectFlags,
        reason_code: mqtt.ReasonCode,
        properties: mqtt.Properties | None,
    ) -> None:
        """Update connection status after disconnection."""
        self._connected = False
        logger.info("Disconnected from MQTT broker: %s", reason_code)

    def _on_message(
        self,
        client: mqtt.Client,
        userdata: object,
        message: mqtt.MQTTMessage,
    ) -> None:
        """Forward received messages to the registered callback."""
        if self._message_callback is None:
            logger.warning("Received MQTT message without a callback")
            return

        self._message_callback(message.topic, message.payload)

    def subscribe(self, topic: str, qos: int = 1) -> None:
        """Subscribe to an MQTT topic."""
        if not topic.strip():
            raise ValueError("MQTT subscription topic cannot be empty")
        if qos not in (0, 1, 2):
            raise ValueError("MQTT QoS must be 0, 1, or 2")
        if not self.client.is_connected():
            raise RuntimeError("Cannot subscribe while MQTT is disconnected")

        result, _ = self.client.subscribe(topic, qos=qos)
        if result != mqtt.MQTT_ERR_SUCCESS:
            raise RuntimeError(f"MQTT subscription failed: {result}")
        logger.info("Subscribed to MQTT topic: %s", topic)

    def publish(
        self,
        topic: str,
        payload: bytes | str,
        qos: int = 1,
    ) -> mqtt.MQTTMessageInfo:
        """Publish a message to an MQTT topic."""
        if not topic.strip():
            raise ValueError("MQTT publication topic cannot be empty")
        if qos not in (0, 1, 2):
            raise ValueError("MQTT QoS must be 0, 1, or 2")
        if not self.client.is_connected():
            raise RuntimeError("Cannot publish while MQTT is disconnected")

        result = self.client.publish(topic, payload, qos=qos)
        if result.rc != mqtt.MQTT_ERR_SUCCESS:
            raise RuntimeError(f"MQTT publication failed: {result.rc}")
        return result

    def connect(self) -> None:
        """Connect to the broker and start the network loop."""
        if self.client.is_connected():
            return

        try:
            self.client.connect(self.host, self.port, self.keepalive)
        except OSError as exc:
            logger.warning(
                "MQTT broker unavailable at %s:%s (%s); retrying in background",
                self.host,
                self.port,
                exc,
            )
            self.client.connect_async(self.host, self.port, self.keepalive)
        self.client.loop_start()

    def disconnect(self) -> None:
        """Disconnect from the broker and stop the network loop."""
        if self.client.is_connected():
            self.client.disconnect()

        self.client.loop_stop()
        self._connected = False
