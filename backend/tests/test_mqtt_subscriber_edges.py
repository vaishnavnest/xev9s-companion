from types import SimpleNamespace
from unittest.mock import MagicMock

import paho.mqtt.client as mqtt
import pytest
from backend.app.communication import mqtt_subscriber
from backend.app.core.exceptions import MQTTUnavailableError


@pytest.fixture
def subscriber(monkeypatch):
    client = MagicMock()
    client.subscribe.return_value = (mqtt.MQTT_ERR_SUCCESS, 1)

    monkeypatch.setattr(
        mqtt_subscriber.mqtt,
        "Client",
        lambda **kwargs: client,
    )

    service = mqtt_subscriber.MQTTSubscriber(MagicMock())
    return service, client


@pytest.mark.parametrize(
    ("variable", "value", "message"),
    [
        ("MQTT_BROKER_HOST", " ", "host cannot be empty"),
        ("MQTT_BROKER_PORT", "65536", "port must be between"),
        ("MQTT_KEEPALIVE", "0", "keepalive must be positive"),
    ],
)
def test_invalid_mqtt_configuration(monkeypatch, variable, value, message):
    monkeypatch.setenv(variable, value)

    with pytest.raises(ValueError, match=message):
        mqtt_subscriber.MQTTSubscriber(MagicMock())


def test_command_subscription_failure(subscriber):
    service, client = subscriber
    service.command_handler = MagicMock()
    service.command_handler.subscribe_responses.side_effect = (
        MQTTUnavailableError("subscription failed")
    )

    service._on_connect(
        client, None, None, SimpleNamespace(is_failure=False), None
    )

    assert service.is_connected is False


def test_connection_callback_failure(subscriber):
    service, client = subscriber
    service.on_connect_callback = MagicMock(
        side_effect=RuntimeError("callback failed")
    )

    service._on_connect(
        client, None, None, SimpleNamespace(is_failure=False), None
    )

    assert service.is_connected is True
    service.on_connect_callback.assert_called_once()


def test_routes_command_response(subscriber):
    service, _ = subscriber
    service.command_handler = MagicMock()
    message = SimpleNamespace(
        topic="xev9s/vehicles/car-001/responses",
        payload=b'{"status": "success"}',
    )

    service._on_message(None, None, message)

    service.command_handler.handle_response.assert_called_once_with(
        message.topic, message.payload
    )


def test_routes_charging_event(subscriber):
    service, _ = subscriber
    service.charging_handler = MagicMock()
    message = SimpleNamespace(
        topic="xev9s/vehicles/car-001/charging/events",
        payload=b"{}",
    )

    service._on_message(None, None, message)

    service.charging_handler.handle_message.assert_called_once_with(
        message.topic, message.payload
    )


def test_websocket_callback_failure(subscriber, monkeypatch):
    service, _ = subscriber
    service.on_telemetry = MagicMock(
        side_effect=RuntimeError("websocket failed")
    )
    service.telemetry_service.ingest_telemetry.return_value = {
        "vehicle_id": "car-001"
    }
    monkeypatch.setattr(
        mqtt_subscriber.TelemetryPayload,
        "model_validate",
        lambda payload: SimpleNamespace(vehicle_id="car-001"),
    )

    message = SimpleNamespace(
        topic="xev9s/vehicles/car-001/telemetry",
        payload=b"{}",
    )

    service._handle_telemetry(message)

    service.on_telemetry.assert_called_once()


def test_start_skips_already_connected_client(subscriber):
    service, client = subscriber
    client.is_connected.return_value = True

    service.start()

    client.connect.assert_not_called()
    client.loop_start.assert_not_called()


def test_start_connects_and_starts_loop(subscriber):
    service, client = subscriber
    client.is_connected.return_value = False

    service.start()

    client.connect.assert_called_once_with(
        service.host, service.port, service.keepalive
    )
    client.loop_start.assert_called_once()


def test_stop_disconnects_and_stops_loop(subscriber):
    service, client = subscriber
    client.is_connected.return_value = True
    service._connected = True

    service.stop()

    client.disconnect.assert_called_once()
    client.loop_stop.assert_called_once()
    assert service.is_connected is False