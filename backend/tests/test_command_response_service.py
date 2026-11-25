
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import InvalidCommandResponseError
from backend.app.schemas.command import CommandStatus
from backend.app.services.command_response_service import (
    CommandResponseService,
)


@pytest.fixture
def setup_service():
    repository = MagicMock()
    timeout_manager = MagicMock()

    repository.get_command_for_response.return_value = {
        "command_id": "cmd-123",
        "vehicle_id": "vehicle-123",
        "operation": "lock",
        "status": "submitted",
        "requested_at": datetime.now(UTC),
    }
    repository.update_command_result.return_value = True

    notification_callback = MagicMock()
    service = CommandResponseService(
        repository,
        timeout_manager,
        notification_callback,
    )

    response = {
        "command_id": "cmd-123",
        "vehicle_id": "vehicle-123",
        "operation": "LOCK",
        "status": "SUCCESS",
        "timestamp": datetime.now(UTC).isoformat(),
        "details": None,
    }

    return service, repository, timeout_manager, response, notification_callback


def test_successful_response_updates_command(setup_service):
    service, repository, timeout_manager, response, callback = setup_service

    assert service.handle_response(response) is True

    repository.update_command_result.assert_called_once()
    args = repository.update_command_result.call_args.args
    assert args[2] == CommandStatus.SUCCEEDED
    assert args[4] is None
    timeout_manager.cancel.assert_called_once_with("cmd-123")
    callback.assert_called_once()

    notification = callback.call_args.args[0]
    assert notification["event"] == "command_updated"
    assert notification["command_id"] == "cmd-123"
    assert notification["vehicle_id"] == "vehicle-123"
    assert notification["operation"] == "lock"
    assert notification["status"] == "succeeded"
    assert notification["failure_reason"] is None


def test_failed_response_records_failure_reason(setup_service):
    service, repository, _, response, callback = setup_service
    response["status"] = "FAILED"
    response["details"] = {"reason": "Vehicle is moving"}

    assert service.handle_response(response) is True

    args = repository.update_command_result.call_args.args
    assert args[2] == CommandStatus.FAILED
    assert args[4] == "Vehicle is moving"

    notification = callback.call_args.args[0]
    assert notification["status"] == "failed"
    assert notification["failure_reason"] == "Vehicle is moving"


@pytest.mark.parametrize(
    "field,value",
    [
        ("command_id", ""),
        ("vehicle_id", ""),
        ("operation", ""),
        ("status", ""),
        ("timestamp", ""),
        ("status", "UNKNOWN"),
        ("timestamp", "invalid"),
        ("timestamp", "2026-11-25T12:00:00"),
    ],
)
def test_invalid_response_is_rejected(setup_service, field, value):
    service, repository, _, response, callback = setup_service
    response[field] = value

    with pytest.raises(InvalidCommandResponseError):
        service.handle_response(response)

    repository.update_command_result.assert_not_called()
    callback.assert_not_called()


def test_unknown_command_is_rejected(setup_service):
    service, repository, _, response, callback = setup_service
    repository.get_command_for_response.return_value = None

    with pytest.raises(InvalidCommandResponseError):
        service.handle_response(response)

    repository.update_command_result.assert_not_called()
    callback.assert_not_called()


def test_operation_mismatch_is_rejected(setup_service):
    service, repository, _, response, callback = setup_service
    response["operation"] = "UNLOCK"

    with pytest.raises(InvalidCommandResponseError):
        service.handle_response(response)

    repository.update_command_result.assert_not_called()
    callback.assert_not_called()


def test_invalid_details_are_rejected(setup_service):
    service, repository, _, response, callback = setup_service
    response["details"] = "invalid"

    with pytest.raises(InvalidCommandResponseError):
        service.handle_response(response)

    repository.update_command_result.assert_not_called()
    callback.assert_not_called()


def test_late_response_does_not_overwrite_final_status(setup_service):
    service, repository, timeout_manager, response, callback = setup_service
    repository.update_command_result.return_value = False

    assert service.handle_response(response) is False

    repository.update_command_result.assert_called_once()
    timeout_manager.cancel.assert_called_once_with("cmd-123")
    callback.assert_not_called()


def test_response_without_notification_callback():
    repository = MagicMock()
    repository.get_command_for_response.return_value = {
        "command_id": "cmd-123",
        "vehicle_id": "vehicle-123",
        "operation": "lock",
    }
    repository.update_command_result.return_value = True

    service = CommandResponseService(repository, MagicMock())
    response = {
        "command_id": "cmd-123",
        "vehicle_id": "vehicle-123",
        "operation": "LOCK",
        "status": "SUCCESS",
        "timestamp": datetime.now(UTC).isoformat(),
        "details": None,
    }

    assert service.handle_response(response) is True
