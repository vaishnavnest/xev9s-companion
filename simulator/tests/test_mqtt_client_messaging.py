from unittest.mock import MagicMock

import paho.mqtt.client as mqtt
import pytest

from simulator.communication.mqtt_client import MQTTClient


def test_subscribe_successfully():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)
    client.client.subscribe = MagicMock(
        return_value=(mqtt.MQTT_ERR_SUCCESS, 1)
    )

    client.subscribe(client.command_topic)

    client.client.subscribe.assert_called_once_with(
        client.command_topic,
        qos=1,
    )


def test_subscribe_rejects_disconnected_client():
    client = MQTTClient()

    with pytest.raises(RuntimeError, match="disconnected"):
        client.subscribe(client.command_topic)


def test_subscribe_rejects_invalid_qos():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)

    with pytest.raises(ValueError, match="QoS"):
        client.subscribe(client.command_topic, qos=3)


def test_subscribe_rejects_broker_error():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)
    client.client.subscribe = MagicMock(return_value=(1, None))

    with pytest.raises(RuntimeError, match="subscription failed"):
        client.subscribe(client.command_topic)


def test_publish_successfully():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)
    message_info = MagicMock()
    message_info.rc = mqtt.MQTT_ERR_SUCCESS
    client.client.publish = MagicMock(return_value=message_info)

    result = client.publish(
        client.response_topic,
        '{"command_id": "cmd-001"}',
    )

    assert result is message_info
    client.client.publish.assert_called_once_with(
        client.response_topic,
        '{"command_id": "cmd-001"}',
        qos=1,
    )


def test_publish_rejects_disconnected_client():
    client = MQTTClient()

    with pytest.raises(RuntimeError, match="disconnected"):
        client.publish(client.response_topic, "test")


def test_publish_rejects_invalid_qos():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)

    with pytest.raises(ValueError, match="QoS"):
        client.publish(client.response_topic, "test", qos=3)


def test_publish_rejects_broker_error():
    client = MQTTClient()
    client.client.is_connected = MagicMock(return_value=True)
    message_info = MagicMock()
    message_info.rc = mqtt.MQTT_ERR_NO_CONN
    client.client.publish = MagicMock(return_value=message_info)

    with pytest.raises(RuntimeError, match="publication failed"):
        client.publish(client.response_topic, "test")
