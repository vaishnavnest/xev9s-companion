
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
    VehicleOfflineError,
)
from backend.app.schemas.command import CommandRequest, CommandStatus
from backend.app.services.command_service import CommandService


@pytest.fixture
def setup():
    command_repo = MagicMock()
    vehicle_repo = MagicMock()
    telemetry_repo = MagicMock()
    publisher = MagicMock()

    vehicle_repo.is_vehicle_associated_with_user.return_value = True
    vehicle_repo.get_active_vehicle_by_id.return_value = {
        "vehicle_id": "XEV9S-001",
        "is_active": True,
    }
    telemetry_repo.get_latest_telemetry.return_value = {
        "timestamp": datetime.now(UTC),
    }

    service = CommandService(
        command_repo, vehicle_repo, telemetry_repo, publisher
    )
    return service, command_repo, vehicle_repo, telemetry_repo, publisher


@pytest.fixture
def request_data():
    return CommandRequest(operation="lock")


def test_submit_command_success(setup, request_data):
    service, command_repo, _, _, publisher = setup
    expected = {
        "command_id": "command-123",
        "vehicle_id": "XEV9S-001",
        "operation": "lock",
        "status": "submitted",
    }
    command_repo.create_command.return_value = expected

    result = service.submit_command(
        "user-123", " XEV9S-001 ", request_data
    )

    assert result == expected
    command_repo.create_command.assert_called_once_with(
        "user-123", "XEV9S-001", request_data
    )
    publisher.assert_called_once_with(
        "XEV9S-001",
        {
            "command_id": "command-123",
            "vehicle_id": "XEV9S-001",
            "operation": "LOCK",
        },
    )


@pytest.mark.parametrize(
    ("access", "active", "timestamp", "error"),
    [
        (False, True, datetime.now(UTC), VehicleAccessDeniedError),
        (True, False, datetime.now(UTC), VehicleNotActiveError),
        (True, True, None, VehicleOfflineError),
        (
            True,
            True,
            datetime.now(UTC) - timedelta(seconds=31),
            VehicleOfflineError,
        ),
        (
            True,
            True,
            datetime.now(UTC) + timedelta(seconds=5),
            VehicleOfflineError,
        ),
    ],
)
def test_submit_command_validation(
    setup, request_data, access, active, timestamp, error
):
    service, command_repo, vehicle_repo, telemetry_repo, _ = setup
    vehicle_repo.is_vehicle_associated_with_user.return_value = access
    vehicle_repo.get_active_vehicle_by_id.return_value = (
        {"vehicle_id": "XEV9S-001"} if active else None
    )
    telemetry_repo.get_latest_telemetry.return_value = (
        {"timestamp": timestamp} if timestamp else None
    )

    with pytest.raises(error):
        service.submit_command("user-123", "XEV9S-001", request_data)

    command_repo.create_command.assert_not_called()


def test_submit_command_mqtt_failure(setup, request_data):
    service, command_repo, _, _, publisher = setup
    command_repo.create_command.return_value = {
        "command_id": "command-123"
    }
    publisher.side_effect = MQTTUnavailableError("Broker unavailable")

    with pytest.raises(MQTTUnavailableError):
        service.submit_command("user-123", "XEV9S-001", request_data)

    command_repo.update_command_result.assert_called_once()
    assert (
        command_repo.update_command_result.call_args.args[2]
        == CommandStatus.FAILED
    )


def test_submit_command_rejects_empty_vehicle_id(setup, request_data):
    service, command_repo, vehicle_repo, _, _ = setup

    with pytest.raises(ValueError, match="Vehicle identifier"):
        service.submit_command("user-123", " ", request_data)

    vehicle_repo.is_vehicle_associated_with_user.assert_not_called()
    command_repo.create_command.assert_not_called()
