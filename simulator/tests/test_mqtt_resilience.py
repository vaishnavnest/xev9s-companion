import json
from unittest.mock import MagicMock, patch

from simulator import mqtt_main
from simulator.communication.mqtt_client import MQTTClient


def test_connect_uses_connect_async_when_broker_unavailable():
    client = MQTTClient(vehicle_id="XEV-001")
    client.client.connect = MagicMock(side_effect=ConnectionRefusedError("down"))
    client.client.connect_async = MagicMock()
    client.client.loop_start = MagicMock()

    client.connect()

    client.client.connect_async.assert_called_once_with(
        client.host, client.port, client.keepalive
    )
    client.client.loop_start.assert_called_once()


def test_run_mqtt_simulator_survives_disconnect_between_telemetry_and_event():
    state = MagicMock()
    client = MagicMock()
    client.is_connected = True
    client.telemetry_topic = "xev9s/vehicles/XEV-001/telemetry"
    client.charging_events_topic = "xev9s/vehicles/XEV-001/charging/events"
    event = {"event_id": "evt-1", "event_type": "charging_started"}

    # 1st loop: telemetry succeeds, event publish fails with RuntimeError.
    # 2nd loop: both succeed (retry delivers queued event).
    client.publish.side_effect = [
        MagicMock(),
        RuntimeError("disconnected"),
        MagicMock(),
        MagicMock(),
    ]

    tracker = MagicMock()
    tracker.evaluate.side_effect = [[event], []]
    components = (state, MagicMock(), MagicMock(), client)

    with (
        patch.object(mqtt_main, "create_mqtt_simulator", return_value=components),
        patch.object(mqtt_main, "ChargingEventTracker", return_value=tracker),
        patch.object(
            mqtt_main,
            "generate_telemetry",
            return_value={"vehicle_id": "XEV-001"},
        ),
        patch.object(
            mqtt_main.time,
            "sleep",
            side_effect=[None, KeyboardInterrupt],
        ),
    ):
        mqtt_main.run_mqtt_simulator("XEV-001")

    assert client.publish.call_count == 4
    client.publish.assert_any_call(
        client.charging_events_topic,
        json.dumps(event),
        qos=1,
    )
    client.disconnect.assert_called_once()
