
import json
from unittest.mock import MagicMock

import paho.mqtt.client as mqtt
import pytest
from backend.app.communication.mqtt_charging_publisher import (
    CHARGING_PREFERENCES_TOPIC,
    MQTTChargingPublisher,
)
from backend.app.core.exceptions import MQTTUnavailableError


@pytest.fixture
def client():
    mock = MagicMock()
    mock.is_connected.return_value = True
    mock.publish.return_value.rc = mqtt.MQTT_ERR_SUCCESS
    return mock


@pytest.fixture
def publisher(client):
    return MQTTChargingPublisher(client)


@pytest.fixture
def preferences():
    return {
        "target_percentage": 90,
        "schedule_enabled": False,
        "timezone": "Asia/Kolkata",
        "stop_charging_at_target": True,
    }


def test_successful_publish(publisher, client, preferences):
    publisher.publish_preferences("XEV-DEMO-001", preferences)

    topic = CHARGING_PREFERENCES_TOPIC.format(
        vehicle_id="XEV-DEMO-001"
    )
    client.publish.assert_called_once()
    args = client.publish.call_args

    assert args.args[0] == topic
    assert json.loads(args.kwargs["payload"]) == {
        **preferences,
        "vehicle_id": "XEV-DEMO-001",
    }
    assert args.kwargs["qos"] == 1


def test_disconnected_broker(publisher, client, preferences):
    client.is_connected.return_value = False

    with pytest.raises(MQTTUnavailableError, match="disconnected"):
        publisher.publish_preferences("XEV-DEMO-001", preferences)

    client.publish.assert_not_called()


@pytest.mark.parametrize(
    "invalid_value",
    [object()],
)
def test_serialization_failure(publisher, preferences, invalid_value):
    preferences["invalid_value"] = invalid_value

    with pytest.raises(
        MQTTUnavailableError,
        match="could not be serialized",
    ):
        publisher.publish_preferences("XEV-DEMO-001", preferences)


def test_mqtt_publish_failure(publisher, client, preferences):
    client.publish.return_value.rc = -1

    with pytest.raises(MQTTUnavailableError, match="Failed to publish"):
        publisher.publish_preferences("XEV-DEMO-001", preferences)
