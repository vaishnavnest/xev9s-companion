import json
from unittest.mock import MagicMock, patch

import pytest
from simulator import mqtt_main


def test_on_mqtt_connected_subscribes_to_command_and_preferences_topics():
    client = MagicMock()
    client.command_topic = "xev9s/vehicles/XEV-001/commands"
    client.charging_preferences_topic = "xev9s/vehicles/XEV-001/charging/preferences"

    mqtt_main.on_mqtt_connected(client)

    assert client.subscribe.call_count == 2
    client.subscribe.assert_any_call(client.command_topic, qos=1)
    client.subscribe.assert_any_call(client.charging_preferences_topic, qos=1)


def test_handle_mqtt_command_publishes_response():
    handler = MagicMock()
    handler.handle_message.return_value = {
        "command_id": "cmd-001",
        "status": "REMOTE_OPERATION_SUCCEEDED",
    }

    client = MagicMock()
    client.command_topic = "xev9s/vehicles/XEV-001/commands"
    client.response_topic = "xev9s/vehicles/XEV-001/responses"

    mqtt_main.handle_mqtt_command(
        client.command_topic,
        b'{"command_id":"cmd-001","operation":"LOCK"}',
        handler,
        client,
    )

    handler.handle_message.assert_called_once()
    client.publish.assert_called_once_with(
        client.response_topic,
        json.dumps(handler.handle_message.return_value),
        qos=1,
    )


def test_handle_mqtt_command_ignores_unexpected_topic():
    handler = MagicMock()
    client = MagicMock()
    client.command_topic = "xev9s/vehicles/XEV-001/commands"

    mqtt_main.handle_mqtt_command(
        "xev9s/unexpected",
        b"{}",
        handler,
        client,
    )

    handler.handle_message.assert_not_called()
    client.publish.assert_not_called()


def test_handle_mqtt_command_handles_publish_failure():
    handler = MagicMock()
    handler.handle_message.return_value = {"status": "SUCCESS"}

    client = MagicMock()
    client.command_topic = "xev9s/vehicles/XEV-001/commands"
    client.publish.side_effect = RuntimeError("Broker disconnected")

    mqtt_main.handle_mqtt_command(
        client.command_topic,
        b"{}",
        handler,
        client,
    )

    client.publish.assert_called_once()


def test_run_mqtt_simulator_publishes_telemetry():
    state = MagicMock()
    client = MagicMock()
    client.is_connected = True
    client.telemetry_topic = "xev9s/vehicles/XEV-001/telemetry"

    components = (state, MagicMock(), MagicMock(), client)

    with (
        patch.object(mqtt_main, "create_mqtt_simulator", return_value=components),
        patch.object(
            mqtt_main,
            "generate_telemetry",
            return_value={"vehicle_id": "XEV-001", "battery_percentage": 80},
        ),
        patch.object(mqtt_main.time, "sleep", side_effect=KeyboardInterrupt),
    ):
        mqtt_main.run_mqtt_simulator("XEV-001")

    client.connect.assert_called_once()
    client.publish.assert_called_once_with(
        client.telemetry_topic,
        json.dumps(
            {"vehicle_id": "XEV-001", "battery_percentage": 80}
        ),
        qos=0,
    )
    client.disconnect.assert_called_once()


@pytest.mark.parametrize("interval", [0, -1, float("inf"), float("nan")])
def test_run_mqtt_simulator_rejects_invalid_interval(interval):
    with pytest.raises(ValueError, match="positive finite number"):
        mqtt_main.run_mqtt_simulator("XEV-001", interval)


def test_create_mqtt_simulator_initializes_components():
    with patch.object(mqtt_main, "MQTTClient") as mock_client:
        state, state_manager, handler, client = (
            mqtt_main.create_mqtt_simulator("XEV-001")
        )

    assert state.vehicle_id == "XEV-001"
    assert state.latitude == mqtt_main.DEFAULT_LATITUDE
    assert state.longitude == mqtt_main.DEFAULT_LONGITUDE
    assert state_manager is not None
    assert handler is not None
    assert client is mock_client.return_value


def test_create_mqtt_simulator_wires_connection_callback():
    with patch.object(mqtt_main, "MQTTClient") as mock_client:
        mqtt_main.create_mqtt_simulator("XEV-001")

    callback = mock_client.call_args.kwargs["on_connected"]

    callback()

    assert mock_client.return_value.subscribe.call_count == 2
    mock_client.return_value.subscribe.assert_any_call(
        mock_client.return_value.command_topic,
        qos=1,
    )
    mock_client.return_value.subscribe.assert_any_call(
        mock_client.return_value.charging_preferences_topic,
        qos=1,
    )


def test_main_starts_simulator_with_default_arguments():
    with patch.object(mqtt_main, "run_mqtt_simulator") as mock_run:
        result = mqtt_main.main([])

    assert result == 0
    mock_run.assert_called_once_with(
        "XEV-001",
        5.0,
        None,
        latitude=mqtt_main.DEFAULT_LATITUDE,
        longitude=mqtt_main.DEFAULT_LONGITUDE,
    )


def test_main_starts_simulator_with_custom_arguments():
    with patch.object(mqtt_main, "run_mqtt_simulator") as mock_run:
        result = mqtt_main.main(
            [
                "--vehicle-id",
                "XEV-005",
                "--telemetry-interval",
                "10",
                "--lat",
                "13.0827",
                "--lon",
                "80.2707",
            ]
        )

    assert result == 0
    mock_run.assert_called_once_with(
        "XEV-005",
        10.0,
        None,
        latitude=13.0827,
        longitude=80.2707,
    )
