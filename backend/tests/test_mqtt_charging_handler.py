
import json
from unittest.mock import MagicMock

import pytest
from backend.app.communication.mqtt_charging_handler import (
    MQTTChargingHandler,
)
from backend.app.core.exceptions import (
    ChargingSessionAlreadyActiveError,
    ChargingSessionNotFoundError,
    DuplicateChargingEventError,
    InvalidChargingTransitionError,
)

TOPIC = "xev9s/vehicles/XEV-DEMO-001/charging/events"

PAYLOAD = {
    "event_id": "event-001",
    "vehicle_id": "XEV-DEMO-001",
    "event_type": "connected",
    "timestamp": "2026-11-26T04:00:00Z",
}


@pytest.fixture
def service():
    return MagicMock()


@pytest.fixture
def callback():
    return MagicMock()


@pytest.fixture
def handler(service, callback):
    return MQTTChargingHandler(service, callback)


def test_invalid_topic(handler, service):
    handler.handle_message("invalid/topic", b"{}")
    service.process_event.assert_not_called()


def test_invalid_json(handler, service):
    handler.handle_message(TOPIC, b"{invalid json")
    service.process_event.assert_not_called()


@pytest.mark.parametrize(
    "payload",
    [
        {"vehicle_id": "XEV-DEMO-001"},
        {
            **PAYLOAD,
            "event_type": "unknown_event",
        },
    ],
)
def test_invalid_event_schema(handler, service, payload):
    handler.handle_message(TOPIC, json.dumps(payload).encode())
    service.process_event.assert_not_called()


def test_vehicle_id_mismatch(handler, service):
    payload = {**PAYLOAD, "vehicle_id": "ANOTHER-VEHICLE"}
    handler.handle_message(TOPIC, json.dumps(payload).encode())
    service.process_event.assert_not_called()


def test_successful_processing(handler, service, callback):
    service.process_event.return_value = {"session_id": "session-001"}

    handler.handle_message(TOPIC, json.dumps(PAYLOAD).encode())

    service.process_event.assert_called_once()
    callback.assert_called_once()
    notification = callback.call_args.args[0]
    assert notification["type"] == "charging_update"
    assert notification["vehicle_id"] == "XEV-DEMO-001"
    assert notification["session"]["session_id"] == "session-001"


def test_success_without_callback(service):
    service.process_event.return_value = None
    handler = MQTTChargingHandler(service)

    handler.handle_message(TOPIC, json.dumps(PAYLOAD).encode())

    service.process_event.assert_called_once()


def test_duplicate_event(handler, service, callback):
    service.process_event.side_effect = DuplicateChargingEventError()

    handler.handle_message(TOPIC, json.dumps(PAYLOAD).encode())

    callback.assert_not_called()


@pytest.mark.parametrize(
    "exception",
    [
        ChargingSessionAlreadyActiveError(),
        ChargingSessionNotFoundError(),
        InvalidChargingTransitionError(),
    ],
)
def test_rejected_lifecycle_event(handler, service, callback, exception):
    service.process_event.side_effect = exception

    handler.handle_message(TOPIC, json.dumps(PAYLOAD).encode())

    callback.assert_not_called()


def test_unexpected_service_exception(handler, service, callback):
    service.process_event.side_effect = RuntimeError("Database failure")

    handler.handle_message(TOPIC, json.dumps(PAYLOAD).encode())

    callback.assert_not_called()


def test_invalid_utf8_payload(handler, service):
    handler.handle_message(TOPIC, b"\xff\xfe")

    service.process_event.assert_not_called()
