
from unittest.mock import MagicMock

from simulator.communication.mqtt_client import MQTTClient


def test_successful_connection_invokes_on_connected_callback():
    callback = MagicMock()
    client = MQTTClient(on_connected=callback)

    reason_code = MagicMock()
    reason_code.is_failure = False

    client._on_connect(
        client.client,
        None,
        MagicMock(),
        reason_code,
        None,
    )

    callback.assert_called_once_with()


def test_failed_connection_does_not_invoke_on_connected_callback():
    callback = MagicMock()
    client = MQTTClient(on_connected=callback)

    reason_code = MagicMock()
    reason_code.is_failure = True

    client._on_connect(
        client.client,
        None,
        MagicMock(),
        reason_code,
        None,
    )

    callback.assert_not_called()


def test_connection_callback_error_does_not_break_connection(caplog):
    def failing_callback():
        raise RuntimeError("Subscription failed")

    client = MQTTClient(on_connected=failing_callback)

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
    assert "MQTT connection callback failed" in caplog.text
