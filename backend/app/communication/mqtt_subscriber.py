import json
import logging
import os
import re
from collections.abc import Callable
from typing import Any
from uuid import uuid4

import paho.mqtt.client as mqtt
from backend.app.communication.mqtt_charging_handler import (
    CHARGING_EVENTS_TOPIC,
    MQTTChargingHandler,
)
from backend.app.communication.mqtt_command_handler import MQTTCommandHandler
from backend.app.core.exceptions import MQTTUnavailableError, VehicleNotActiveError
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.telemetry_service import TelemetryService
from dotenv import load_dotenv
from pydantic import ValidationError

load_dotenv()

logger = logging.getLogger(__name__)
TELEMETRY_TOPIC = "xev9s/vehicles/+/telemetry"
TOPIC_PATTERN = re.compile(r"^xev9s/vehicles/([A-Za-z0-9_-]+)/telemetry$")


class MQTTSubscriber:
    """Receive telemetry, charging events, and command responses."""

    def __init__(
        self,
        telemetry_service: TelemetryService,
        on_connect_callback: Callable[[], None] | None = None,
        on_telemetry: Callable[[dict[str, Any]], None] | None = None,
        charging_handler: MQTTChargingHandler | None = None,
    ) -> None:
        self.telemetry_service = telemetry_service
        self.on_connect_callback = on_connect_callback
        self.on_telemetry = on_telemetry
        self.charging_handler = charging_handler
        self.command_handler: MQTTCommandHandler | None = None
        self.host = os.getenv("MQTT_BROKER_HOST", "127.0.0.1")
        self.port = int(os.getenv("MQTT_BROKER_PORT", "1884"))
        self.keepalive = int(os.getenv("MQTT_KEEPALIVE", "60"))

        if not self.host.strip():
            raise ValueError("MQTT broker host cannot be empty")
        if not 1 <= self.port <= 65535:
            raise ValueError("MQTT broker port must be between 1 and 65535")
        if self.keepalive <= 0:
            raise ValueError("MQTT keepalive must be positive")

        self._connected = False
        client_id = (
            os.getenv("MQTT_CLIENT_ID", "").strip()
            or f"xev9s-backend-telemetry-{uuid4().hex[:8]}"
        )
        self.client = mqtt.Client(
            callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
            client_id=client_id,
            protocol=mqtt.MQTTv311,
        )
        self.client.reconnect_delay_set(min_delay=1, max_delay=30)
        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message

    @property
    def is_connected(self) -> bool:
        """Return whether the subscriber is connected and subscribed."""
        return self._connected

    def _on_connect(
        self,
        client: mqtt.Client,
        userdata: object,
        flags: mqtt.ConnectFlags,
        reason_code: mqtt.ReasonCode,
        properties: mqtt.Properties | None,
    ) -> None:
        """Subscribe to telemetry and charging topics."""
        self._connected = False
        if reason_code.is_failure:
            logger.error("MQTT connection rejected: %s", reason_code)
            return

        for topic in (TELEMETRY_TOPIC, CHARGING_EVENTS_TOPIC):
            result, _ = client.subscribe(topic, qos=0)
            if result != mqtt.MQTT_ERR_SUCCESS:
                logger.error("Failed to subscribe to %s", topic)
                return
            logger.info("Subscribed to %s", topic)

        if self.command_handler is not None:
            try:
                self.command_handler.subscribe_responses()
            except MQTTUnavailableError:
                logger.exception("Failed to subscribe to command responses")
                return

        self._connected = True
        if self.on_connect_callback is not None:
            try:
                self.on_connect_callback()
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
        """Update connection state after disconnection."""
        self._connected = False
        logger.info("MQTT subscriber disconnected: %s", reason_code)

    def _on_message(
        self,
        client: mqtt.Client,
        userdata: object,
        message: mqtt.MQTTMessage,
    ) -> None:
        """Route messages to their respective handlers."""
        if message.topic.endswith("/responses"):
            if self.command_handler is not None:
                self.command_handler.handle_response(message.topic, message.payload)
        elif message.topic.endswith("/charging/events"):
            if self.charging_handler is not None:
                self.charging_handler.handle_message(message.topic, message.payload)
        else:
            self._handle_telemetry(message)

    def _handle_telemetry(self, message: mqtt.MQTTMessage) -> None:
        """Validate and persist vehicle telemetry."""
        match = TOPIC_PATTERN.fullmatch(message.topic)
        if match is None:
            logger.warning("Ignoring invalid telemetry topic: %s", message.topic)
            return

        vehicle_id = match.group(1)
        try:
            telemetry = TelemetryPayload.model_validate(json.loads(message.payload))
            if telemetry.vehicle_id != vehicle_id:
                logger.warning("Telemetry vehicle ID does not match topic")
                return

            saved = self.telemetry_service.ingest_telemetry(telemetry)
            if self.on_telemetry is not None:
                try:
                    self.on_telemetry(saved)
                except Exception:
                    logger.exception("Failed to notify WebSocket clients")
        except (json.JSONDecodeError, ValidationError, UnicodeDecodeError):
            logger.warning(
                "Rejected invalid telemetry message on %s",
                message.topic,
                exc_info=True,
            )
        except VehicleNotActiveError:
            logger.warning("Rejected telemetry from inactive vehicle: %s", vehicle_id)
        except Exception:
            logger.exception("Failed to process telemetry from vehicle %s", vehicle_id)

    def start(self) -> None:
        """Connect to the broker and start its network loop."""
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

    def stop(self) -> None:
        """Disconnect from the broker and stop its network loop."""
        if self.client.is_connected():
            self.client.disconnect()
        self.client.loop_stop()
        self._connected = False
