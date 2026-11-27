from unittest.mock import MagicMock, patch

import paho.mqtt.client as mqtt
from backend.app.communication import mqtt_subscriber


def test_start_uses_connect_async_when_broker_unavailable(monkeypatch):
    client = MagicMock()
    client.is_connected.return_value = False
    client.connect.side_effect = ConnectionRefusedError("broker down")
    monkeypatch.setattr(mqtt_subscriber.mqtt, "Client", lambda **kwargs: client)

    sub = mqtt_subscriber.MQTTSubscriber(MagicMock())
    sub.start()

    client.reconnect_delay_set.assert_called_once_with(min_delay=1, max_delay=30)
    client.connect_async.assert_called_once_with(sub.host, sub.port, sub.keepalive)
    client.loop_start.assert_called_once()
    sub.stop()
    client.loop_stop.assert_called_once()


def test_multiple_backend_instances_generate_distinct_client_ids():
    client_ids = []

    def capture_client(**kwargs):
        client_ids.append(kwargs["client_id"])
        return MagicMock()

    with patch.object(mqtt_subscriber.mqtt, "Client", side_effect=capture_client):
        mqtt_subscriber.MQTTSubscriber(MagicMock())
        mqtt_subscriber.MQTTSubscriber(MagicMock())

    assert len(client_ids) == 2
    assert client_ids[0] != client_ids[1]


def test_custom_mqtt_client_id_from_env(monkeypatch):
    monkeypatch.setenv("MQTT_CLIENT_ID", "backend-worker-1")
    with patch.object(mqtt_subscriber.mqtt, "Client") as mock_client:
        mqtt_subscriber.MQTTSubscriber(MagicMock())
    assert mock_client.call_args.kwargs["client_id"] == "backend-worker-1"


def test_reconnection_restores_subscriptions(monkeypatch):
    client = MagicMock()
    client.subscribe.return_value = (mqtt.MQTT_ERR_SUCCESS, 1)
    monkeypatch.setattr(mqtt_subscriber.mqtt, "Client", lambda **kwargs: client)

    sub = mqtt_subscriber.MQTTSubscriber(MagicMock())
    reason = MagicMock(is_failure=False)
    sub._on_connect(client, None, MagicMock(), reason, None)
    assert sub.is_connected is True
    sub._on_disconnect(client, None, MagicMock(), MagicMock(), None)
    assert sub.is_connected is False
    sub._on_connect(client, None, MagicMock(), reason, None)
    assert sub.is_connected is True
    assert client.subscribe.call_count == 4
