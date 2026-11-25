import json
from unittest.mock import MagicMock

import paho.mqtt.client as mqtt
import pytest
from backend.app.communication import mqtt_command_handler as handler_module
from backend.app.communication.mqtt_command_handler import MQTTCommandHandler
from backend.app.core.exceptions import MQTTUnavailableError


@pytest.fixture
def setup_handler():
    client = MagicMock()
    callback = MagicMock()
    handler = MQTTCommandHandler(client, callback)
    return handler, client, callback


def test_subscribe_responses_success(setup_handler):
    handler, client, _callback = setup_handler
    client.is_connected.return_value = True
    client.subscribe.return_value = (mqtt.MQTT_ERR_SUCCESS, 1)

    handler.subscribe_responses()

    client.subscribe.assert_called_once_with(
        handler_module.RESPONSE_TOPIC,
        qos=1,
    )


def test_subscribe_responses_disconnected(setup_handler):
    handler, client, _callback = setup_handler
    client.is_connected.return_value = False

    with pytest.raises(MQTTUnavailableError, match="disconnected"):
        handler.subscribe_responses()

    client.subscribe.assert_not_called()


def test_subscribe_responses_failure(setup_handler):
    handler, client, _callback = setup_handler
    client.is_connected.return_value = True
    client.subscribe.return_value = (1, None)

    with pytest.raises(MQTTUnavailableError, match="subscribe"):
        handler.subscribe_responses()


def test_publish_command_success(setup_handler):
    handler, client, _callback = setup_handler
    client.is_connected.return_value = True
    client.publish.return_value.rc = mqtt.MQTT_ERR_SUCCESS

    payload = {"command_id": "cmd-1", "operation": "LOCK"}
    handler.publish_command("XEV9S-001", payload)

    client.publish.assert_called_once_with(
        "xev9s/vehicles/XEV9S-001/commands",
        payload=json.dumps(payload),
        qos=1,
    )


def test_publish_command_disconnected(setup_handler):
    handler, client, _callback = setup_handler
    client.is_connected.return_value = False

    with pytest.raises(MQTTUnavailableError, match="disconnected"):
        handler.publish_command("XEV9S-001", {})

    client.publish.assert_not_called()


def test_publish_command_serialization_failure(setup_handler):
    handler, client, _callback = setup_handler
    client.is_connected.return_value = True

    with pytest.raises(MQTTUnavailableError, match="serialized"):
        handler.publish_command("XEV9S-001", {"value": object()})


def test_publish_command_failure(setup_handler):
    handler, client, _callback = setup_handler
    client.is_connected.return_value = True
    client.publish.return_value.rc = 1

    with pytest.raises(MQTTUnavailableError, match="publish"):
        handler.publish_command("XEV9S-001", {})


def test_handle_response_success(setup_handler):
    handler, _client, callback = setup_handler
    response = {
        "command_id": "cmd-1",
        "vehicle_id": "XEV9S-001",
        "operation": "LOCK",
        "status": "SUCCESS",
    }

    handler.handle_response(
        "xev9s/vehicles/XEV9S-001/responses",
        json.dumps(response).encode(),
    )

    callback.assert_called_once_with(response)


def test_handle_response_invalid_topic(setup_handler):
    handler, _client, callback = setup_handler

    handler.handle_response(
        "xev9s/vehicles/XEV9S-001/commands",
        b"{}",
    )

    callback.assert_not_called()


def test_handle_response_vehicle_mismatch(setup_handler):
    handler, _client, callback = setup_handler

    handler.handle_response(
        "xev9s/vehicles/XEV9S-001/responses",
        b'{"vehicle_id": "XEV9S-002"}',
    )

    callback.assert_not_called()


@pytest.mark.parametrize("payload", [b"invalid-json", b"\xff"])
def test_handle_response_invalid_json(setup_handler, payload):
    handler, _client, callback = setup_handler

    handler.handle_response(
        "xev9s/vehicles/XEV9S-001/responses",
        payload,
    )

    callback.assert_not_called()


def test_handle_response_non_object(setup_handler):
    handler, _client, callback = setup_handler

    handler.handle_response(
        "xev9s/vehicles/XEV9S-001/responses",
        b'["invalid"]',
    )

    callback.assert_not_called()


def test_handle_response_callback_failure(setup_handler):
    handler, _client, callback = setup_handler
    callback.side_effect = RuntimeError("Response processing failed")

    handler.handle_response(
        "xev9s/vehicles/XEV9S-001/responses",
        b'{"vehicle_id": "XEV9S-001"}',
    )

    callback.assert_called_once()
