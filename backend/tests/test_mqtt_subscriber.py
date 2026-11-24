
import json
from datetime import UTC, datetime
from unittest.mock import MagicMock, patch

import paho.mqtt.client as mqtt
import pytest
from backend.app.communication.mqtt_subscriber import (
    TELEMETRY_TOPIC,
    MQTTSubscriber,
)
from backend.app.core.exceptions import VehicleNotActiveError
from backend.app.schemas.telemetry import TelemetryPayload


@pytest.fixture
def setup():
    service = MagicMock()
    with patch.dict("os.environ", {
        "MQTT_BROKER_HOST": "127.0.0.1",
        "MQTT_BROKER_PORT": "1884",
        "MQTT_KEEPALIVE": "60",
    }):
        yield MQTTSubscriber(service), service


@pytest.fixture
def payload():
    return {
        "vehicle_id": "XEV9S-001",
        "timestamp": datetime.now(UTC).isoformat(),
        "battery_percentage": 80.0,
        "estimated_range_km": 300.0,
        "speed_kph": 0.0,
        "odometer_km": 1200.5,
        "latitude": 8.5241,
        "longitude": 76.9366,
        "operating_state": "parked",
        "is_locked": True,
        "charging_status": "disconnected",
        "charging_power_kw": 0.0,
        "cabin_preconditioning_active": False,
    }


def message(payload, topic="xev9s/vehicles/XEV9S-001/telemetry"):
    result = MagicMock()
    result.topic = topic
    result.payload = (
        payload if isinstance(payload, bytes)
        else json.dumps(payload).encode()
    )
    return result


def test_initialization(setup):
    subscriber, _ = setup
    assert (subscriber.host, subscriber.port, subscriber.keepalive) == (
        "127.0.0.1", 1884, 60
    )
    assert not subscriber.is_connected


def test_successful_connection_subscribes(setup):
    subscriber, _ = setup
    client = MagicMock()
    client.subscribe.return_value = (mqtt.MQTT_ERR_SUCCESS, 1)
    reason = MagicMock(is_failure=False)

    subscriber._on_connect(client, None, MagicMock(), reason, None)

    client.subscribe.assert_called_once_with(TELEMETRY_TOPIC, qos=0)
    assert subscriber.is_connected


def test_rejected_connection(setup):
    subscriber, _ = setup
    subscriber._on_connect(
        MagicMock(), None, MagicMock(), MagicMock(is_failure=True), None
    )
    assert not subscriber.is_connected


def test_subscription_failure(setup):
    subscriber, _ = setup
    client = MagicMock()
    client.subscribe.return_value = (mqtt.MQTT_ERR_NO_CONN, None)

    subscriber._on_connect(
        client, None, MagicMock(), MagicMock(is_failure=False), None
    )

    assert not subscriber.is_connected


def test_valid_message_is_ingested(setup, payload):
    subscriber, service = setup
    subscriber._on_message(MagicMock(), None, message(payload))

    service.ingest_telemetry.assert_called_once()
    saved = service.ingest_telemetry.call_args.args[0]
    assert isinstance(saved, TelemetryPayload)
    assert saved.vehicle_id == "XEV9S-001"


def test_telemetry_callback_runs_after_persistence(setup, payload):
    subscriber, service = setup
    events = []
    saved_telemetry = {
        **payload,
        "received_at": datetime.now(UTC),
        "_id": "test-id",
    }

    service.ingest_telemetry.side_effect = (
        lambda telemetry: events.append("persisted") or saved_telemetry
    )
    subscriber.on_telemetry = (
        lambda telemetry: events.append("broadcast")
    )

    subscriber._on_message(MagicMock(), None, message(payload))

    assert events == ["persisted", "broadcast"]


def test_telemetry_callback_not_called_when_persistence_fails(
    setup,
    payload,
):
    subscriber, service = setup
    callback = MagicMock()
    subscriber.on_telemetry = callback
    service.ingest_telemetry.side_effect = RuntimeError(
        "Database unavailable"
    )

    subscriber._on_message(MagicMock(), None, message(payload))

    callback.assert_not_called()


@pytest.mark.parametrize("raw", [
    b"{invalid-json",
    b"\xff\xfe",
    json.dumps({"vehicle_id": "XEV9S-001"}).encode(),
])
def test_invalid_payload_is_rejected(setup, raw):
    subscriber, service = setup
    subscriber._on_message(MagicMock(), None, message(raw))
    service.ingest_telemetry.assert_not_called()


def test_vehicle_id_mismatch_is_rejected(setup, payload):
    subscriber, service = setup
    payload["vehicle_id"] = "XEV9S-002"
    subscriber._on_message(MagicMock(), None, message(payload))
    service.ingest_telemetry.assert_not_called()


def test_invalid_topic_is_rejected(setup, payload):
    subscriber, service = setup
    subscriber._on_message(
        MagicMock(), None,
        message(payload, "xev9s/vehicles/+/telemetry"),
    )
    service.ingest_telemetry.assert_not_called()


def test_inactive_vehicle_is_handled(setup, payload):
    subscriber, service = setup
    service.ingest_telemetry.side_effect = VehicleNotActiveError
    subscriber._on_message(MagicMock(), None, message(payload))
    service.ingest_telemetry.assert_called_once()


def test_service_error_is_handled(setup, payload):
    subscriber, service = setup
    service.ingest_telemetry.side_effect = RuntimeError("Database unavailable")
    subscriber._on_message(MagicMock(), None, message(payload))
    service.ingest_telemetry.assert_called_once()


def test_disconnect_updates_state(setup):
    subscriber, _ = setup
    subscriber._connected = True
    subscriber._on_disconnect(
        MagicMock(), None, MagicMock(), MagicMock(), None
    )
    assert not subscriber.is_connected
