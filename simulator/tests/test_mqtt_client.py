
from unittest.mock import MagicMock

import pytest

from simulator.communication.mqtt_client import MQTTClient


def test_client_initializes_with_default_vehicle_id():
    client = MQTTClient()

    assert client.vehicle_id == "XEV-001"
    assert client.host
    assert client.port == 1884
    assert client.keepalive == 60
    assert client.is_connected is False


def test_client_creates_vehicle_specific_topics():
    client = MQTTClient(vehicle_id="XEV-123")

    assert client.command_topic == "xev9s/vehicles/XEV-123/commands"
    assert client.response_topic == "xev9s/vehicles/XEV-123/responses"
    assert client.telemetry_topic == "xev9s/vehicles/XEV-123/telemetry"


@pytest.mark.parametrize(
    "vehicle_id",
    ["", " ", "XEV/123", "XEV+123", "XEV#123"],
)
def test_client_rejects_invalid_vehicle_id(vehicle_id):
    with pytest.raises(ValueError, match="Vehicle ID is invalid"):
        MQTTClient(vehicle_id=vehicle_id)

def test_client_rejects_empty_broker_host(monkeypatch):
    monkeypatch.setenv("MQTT_BROKER_HOST", "   ")

    with pytest.raises(ValueError, match="host cannot be empty"):
        MQTTClient()

@pytest.mark.parametrize("port", ["0", "65536"])
def test_client_rejects_invalid_broker_port(monkeypatch, port):
    monkeypatch.setenv("MQTT_BROKER_PORT", port)

    with pytest.raises(ValueError, match="port must be between"):
        MQTTClient()


@pytest.mark.parametrize("keepalive", ["0", "-1"])
def test_client_rejects_invalid_keepalive(monkeypatch, keepalive):
    monkeypatch.setenv("MQTT_KEEPALIVE", keepalive)

    with pytest.raises(ValueError, match="keepalive must be positive"):
        MQTTClient()


def test_client_uses_environment_configuration(monkeypatch):
    monkeypatch.setenv("MQTT_BROKER_HOST", "localhost")
    monkeypatch.setenv("MQTT_BROKER_PORT", "1885")
    monkeypatch.setenv("MQTT_KEEPALIVE", "30")

    client = MQTTClient()

    assert client.host == "localhost"
    assert client.port == 1885
    assert client.keepalive == 30


def test_connect_starts_mqtt_network_loop(monkeypatch):
    client = MQTTClient()
    client.client.connect = MagicMock()
    client.client.loop_start = MagicMock()

    client.connect()

    client.client.connect.assert_called_once_with(
        client.host,
        client.port,
        client.keepalive,
    )
    client.client.loop_start.assert_called_once()


def test_connect_does_nothing_if_already_connected():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)
    client.client.connect = MagicMock()
    client.client.loop_start = MagicMock()

    client.connect()

    client.client.connect.assert_not_called()
    client.client.loop_start.assert_not_called()


def test_disconnect_stops_mqtt_network_loop():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)
    client.client.disconnect = MagicMock()
    client.client.loop_stop = MagicMock()

    client.disconnect()

    client.client.disconnect.assert_called_once()
    client.client.loop_stop.assert_called_once()
    assert client.is_connected is False


def test_disconnect_when_already_disconnected():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=False)
    client.client.disconnect = MagicMock()
    client.client.loop_stop = MagicMock()

    client.disconnect()

    client.client.disconnect.assert_not_called()
    client.client.loop_stop.assert_called_once()
    assert client.is_connected is False

def test_successful_connection_updates_status():
    client = MQTTClient()
    reason_code = MagicMock()
    reason_code.is_failure = False

    client._on_connect(
        client.client,
        None,
        MagicMock(),
        reason_code,
        None,
    )

    assert client.is_connected is True


def test_failed_connection_keeps_status_disconnected():
    client = MQTTClient()
    reason_code = MagicMock()
    reason_code.is_failure = True

    client._on_connect(
        client.client,
        None,
        MagicMock(),
        reason_code,
        None,
    )

    assert client.is_connected is False


def test_disconnect_callback_updates_status():
    client = MQTTClient()
    client._connected = True

    client._on_disconnect(
        client.client,
        None,
        MagicMock(),
        MagicMock(),
        None,
    )

    assert client.is_connected is False


def test_message_callback_receives_topic_and_payload():
    callback = MagicMock()
    client = MQTTClient(message_callback=callback)

    message = MagicMock()
    message.topic = client.command_topic
    message.payload = b'{"command_id": "cmd-001"}'

    client._on_message(client.client, None, message)

    callback.assert_called_once_with(
        client.command_topic,
        b'{"command_id": "cmd-001"}',
    )


def test_message_without_callback_does_not_raise():
    client = MQTTClient()
    message = MagicMock()

    client._on_message(client.client, None, message)
