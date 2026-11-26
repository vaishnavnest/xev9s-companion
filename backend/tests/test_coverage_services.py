from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleOfflineError,
)
from backend.app.schemas.command import CommandRequest, RemoteOperation
from backend.app.services.command_service import CommandService
from backend.app.services.telemetry_service import TelemetryService


def test_telemetry_service_empty_vehicle_id_validations():
    telemetry_repo = MagicMock()
    vehicle_repo = MagicMock()
    service = TelemetryService(telemetry_repo, vehicle_repo)

    mock_payload = MagicMock()
    mock_payload.vehicle_id = "   "
    with pytest.raises(ValueError, match="Vehicle identifier cannot be empty"):
        service.ingest_telemetry(mock_payload)

    with pytest.raises(ValueError, match="Vehicle identifier cannot be empty"):
        service.get_latest_telemetry("user-01", "   ")

    now = datetime.now(UTC)
    with pytest.raises(ValueError, match="Vehicle identifier cannot be empty"):
        service.get_telemetry_history("user-01", "   ", now, now)


def test_telemetry_service_get_history_access_denied():
    telemetry_repo = MagicMock()
    vehicle_repo = MagicMock()
    vehicle_repo.is_vehicle_associated_with_user.return_value = False
    service = TelemetryService(telemetry_repo, vehicle_repo)

    now = datetime.now(UTC)
    with pytest.raises(
        VehicleAccessDeniedError,
        match="You do not have access to this vehicle",
    ):
        service.get_telemetry_history(
            "user-01",
            "XEV-001",
            now - timedelta(hours=1),
            now,
        )


def test_command_service_invalid_and_naive_telemetry_timestamp():
    command_repo = MagicMock()
    vehicle_repo = MagicMock()
    telemetry_repo = MagicMock()
    publish_cmd = MagicMock()

    service = CommandService(
        command_repo,
        vehicle_repo,
        telemetry_repo,
        publish_cmd,
    )

    telemetry_repo.get_latest_telemetry.return_value = {
        "timestamp": "invalid_string_timestamp"
    }
    with pytest.raises(
        VehicleOfflineError,
        match="Vehicle telemetry timestamp is invalid",
    ):
        service._ensure_vehicle_online("XEV-001")

    # Naive timestamp should be normalized to UTC and pass if recent
    recent_naive = datetime.now(UTC).replace(tzinfo=None) - timedelta(seconds=2)
    telemetry_repo.get_latest_telemetry.return_value = {
        "timestamp": recent_naive
    }
    # Should complete without error
    service._ensure_vehicle_online("XEV-001")


def test_command_service_timeout_manager_lifecycle():
    command_repo = MagicMock()
    vehicle_repo = MagicMock()
    telemetry_repo = MagicMock()
    publish_cmd = MagicMock()
    timeout_manager = MagicMock()

    vehicle_repo.is_vehicle_associated_with_user.return_value = True
    vehicle_repo.get_active_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    telemetry_repo.get_latest_telemetry.return_value = {
        "timestamp": datetime.now(UTC) - timedelta(seconds=1)
    }
    command_repo.create_command.return_value = {
        "command_id": "cmd-test-123",
        "vehicle_id": "XEV-001",
        "operation": "lock",
    }

    service = CommandService(
        command_repo,
        vehicle_repo,
        telemetry_repo,
        publish_cmd,
        timeout_manager=timeout_manager,
    )

    request = CommandRequest(operation=RemoteOperation.LOCK)
    res = service.submit_command("user-01", "XEV-001", request)

    assert res["command_id"] == "cmd-test-123"
    timeout_manager.start.assert_called_once_with("cmd-test-123", "XEV-001")

    # Now test MQTT failure cancels timeout_manager
    publish_cmd.side_effect = MQTTUnavailableError("Broker down")
    with pytest.raises(MQTTUnavailableError):
        service.submit_command("user-01", "XEV-001", request)

    timeout_manager.cancel.assert_called_once_with("cmd-test-123")
