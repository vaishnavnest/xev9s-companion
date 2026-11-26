
import asyncio
import logging
from unittest.mock import MagicMock, patch

from backend.app.services.charging_runtime import (
    create_charging_notification_callback,
    create_charging_runtime,
)
from bson import ObjectId


def test_notification_callback_broadcasts_update():
    websocket = MagicMock()
    websocket.broadcast.return_value = asyncio.sleep(0)
    loop = asyncio.new_event_loop()

    try:
        callback = create_charging_notification_callback(websocket, loop)
        callback({"vehicle_id": "XEV-001", "status": "charging"})

        loop.run_until_complete(asyncio.sleep(0.01))

        websocket.broadcast.assert_called_once_with(
            "XEV-001",
            {"vehicle_id": "XEV-001", "status": "charging"},
        )
    finally:
        loop.close()


def test_notification_callback_converts_object_id():
    websocket = MagicMock()
    websocket.broadcast.return_value = asyncio.sleep(0)
    loop = asyncio.new_event_loop()
    object_id = ObjectId()

    try:
        callback = create_charging_notification_callback(websocket, loop)
        callback({"vehicle_id": "XEV-001", "id": object_id})

        loop.run_until_complete(asyncio.sleep(0.01))

        message = websocket.broadcast.call_args.args[1]
        assert message["id"] == str(object_id)
    finally:
        loop.close()


def test_notification_callback_logs_broadcast_failure(caplog):
    websocket = MagicMock()

    async def fail_broadcast(*args):
        raise RuntimeError("WebSocket unavailable")

    websocket.broadcast.side_effect = fail_broadcast
    loop = asyncio.new_event_loop()

    try:
        callback = create_charging_notification_callback(websocket, loop)

        with caplog.at_level(logging.ERROR):
            callback({"vehicle_id": "XEV-001"})

            loop.run_until_complete(asyncio.sleep(0.01))

        assert "WebSocket charging broadcast failed" in caplog.text
    finally:
        loop.close()


@patch("backend.app.services.charging_runtime.MQTTChargingHandler")
@patch("backend.app.services.charging_runtime.ChargingEventService")
@patch("backend.app.services.charging_runtime.ChargingSessionRepository")
@patch("backend.app.services.charging_runtime.ChargingEventRepository")
def test_create_charging_runtime(
    event_repository,
    session_repository,
    event_service,
    mqtt_handler,
):
    database = MagicMock()
    database.client = MagicMock()
    callback = MagicMock()

    service_instance = event_service.return_value
    handler_instance = mqtt_handler.return_value

    service, handler = create_charging_runtime(database, callback)

    event_repository.assert_called_once_with(
        database["charging_events"]
    )
    session_repository.assert_called_once_with(
        database["charging_sessions"]
    )
    event_service.assert_called_once_with(
        event_repository.return_value,
        session_repository.return_value,
        database.client,
    )
    mqtt_handler.assert_called_once_with(
        service_instance,
        on_charging=callback,
    )

    assert service is service_instance
    assert handler is handler_instance


@patch("backend.app.services.charging_runtime.MQTTChargingHandler")
@patch("backend.app.services.charging_runtime.ChargingEventService")
@patch("backend.app.services.charging_runtime.ChargingSessionRepository")
@patch("backend.app.services.charging_runtime.ChargingEventRepository")
def test_create_charging_runtime_without_callback(
    event_repository,
    session_repository,
    event_service,
    mqtt_handler,
):
    database = MagicMock()

    create_charging_runtime(database)

    mqtt_handler.assert_called_once_with(
        event_service.return_value,
        on_charging=None,
    )
