
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
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

    service = CommandService(
        command_repo,
        vehicle_repo,
        telemetry_repo,
        publisher,
    )
    return service, command_repo, vehicle_repo


def test_get_commands_success(setup):
    service, command_repo, _ = setup
    expected = [
        {
            "command_id": "command-123",
            "operation": "lock",
            "status": "succeeded",
        },
        {
            "command_id": "command-124",
            "operation": "unlock",
            "status": "failed",
        },
    ]
    command_repo.get_vehicle_commands.return_value = expected

    result = service.get_commands("user-123", "XEV9S-001")

    assert result == expected
    command_repo.get_vehicle_commands.assert_called_once_with(
        "XEV9S-001",
        "user-123",
    )


def test_get_command_success(setup):
    service, command_repo, _ = setup
    expected = {
        "command_id": "command-123",
        "vehicle_id": "XEV9S-001",
        "operation": "lock",
        "status": "succeeded",
        "requested_at": datetime.now(UTC),
        "completed_at": datetime.now(UTC),
        "failure_reason": None,
    }
    command_repo.get_command.return_value = expected

    result = service.get_command(
        "user-123",
        "XEV9S-001",
        "command-123",
    )

    assert result == expected
    command_repo.get_command.assert_called_once_with(
        "XEV9S-001",
        "command-123",
        "user-123",
    )


@pytest.mark.parametrize("method", ["get_commands", "get_command"])
def test_retrieval_denies_vehicle_access(setup, method):
    service, command_repo, vehicle_repo = setup
    vehicle_repo.is_vehicle_associated_with_user.return_value = False

    with pytest.raises(VehicleAccessDeniedError):
        if method == "get_commands":
            service.get_commands("user-123", "XEV9S-001")
        else:
            service.get_command(
                "user-123",
                "XEV9S-001",
                "command-123",
            )

    command_repo.get_vehicle_commands.assert_not_called()
    command_repo.get_command.assert_not_called()


@pytest.mark.parametrize("method", ["get_commands", "get_command"])
def test_retrieval_rejects_inactive_vehicle(setup, method):
    service, command_repo, vehicle_repo = setup
    vehicle_repo.get_active_vehicle_by_id.return_value = None

    with pytest.raises(VehicleNotActiveError):
        if method == "get_commands":
            service.get_commands("user-123", "XEV9S-001")
        else:
            service.get_command(
                "user-123",
                "XEV9S-001",
                "command-123",
            )

    command_repo.get_vehicle_commands.assert_not_called()
    command_repo.get_command.assert_not_called()
