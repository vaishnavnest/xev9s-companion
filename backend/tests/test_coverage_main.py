from datetime import UTC, datetime
from unittest.mock import MagicMock, patch

import pytest
from backend.app.main import _log_broadcast_error, lifespan


def test_log_broadcast_error_variants():
    # Success branch
    res_ok = MagicMock()
    res_ok.result.return_value = None
    _log_broadcast_error(res_ok, "Broadcast succeeded")

    # Exception branch
    res_err = MagicMock()
    res_err.result.side_effect = RuntimeError("Connection dropped")
    _log_broadcast_error(res_err, "Broadcast failed")


@pytest.mark.anyio
async def test_lifespan_websocket_callbacks_execution():
    fake_app = MagicMock()
    mock_db = MagicMock()
    mock_sub = MagicMock()

    captured = {}

    def fake_command_response_service(_repo, _tm, cb):
        captured["command_cb"] = cb
        return MagicMock()

    def fake_mqtt_subscriber(_service, on_telemetry=None, charging_handler=None):
        captured["telemetry_cb"] = on_telemetry
        return mock_sub

    with (
        patch("backend.app.main.connect_to_database", return_value=mock_db),
        patch("backend.app.main.ensure_database_indexes"),
        patch(
            "backend.app.main.CommandResponseService",
            side_effect=fake_command_response_service,
        ),
        patch(
            "backend.app.main.MQTTSubscriber",
            side_effect=fake_mqtt_subscriber,
        ),
        patch("backend.app.main.close_database_connection"),
    ):
        async with lifespan(fake_app):
            # Execute notify_websocket_command_clients callback
            cmd_data = {
                "command_id": "cmd-live-1",
                "vehicle_id": "XEV-9S-001",
                "operation": "LOCK",
                "status": "SUCCEEDED",
                "requested_at": datetime.now(UTC),
                "completed_at": datetime.now(UTC),
            }
            captured["command_cb"](cmd_data)

            # Execute notify_websocket_clients callback
            telem_data = {
                "_id": "674000000000000000000001",
                "vehicle_id": "XEV-9S-001",
                "timestamp": datetime.now(UTC),
                "battery_percentage": 85.0,
                "estimated_range_km": 320.0,
                "speed_kph": 0.0,
                "odometer_km": 1500.0,
                "latitude": None,
                "longitude": None,
                "operating_state": "parked",
                "is_locked": True,
                "charging_status": "disconnected",
                "charging_power_kw": 0.0,
                "cabin_preconditioning_active": False,
                "received_at": datetime.now(UTC),
            }
            captured["telemetry_cb"](telem_data)
