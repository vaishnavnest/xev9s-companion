
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.repositories.command_repository import CommandRepository
from backend.app.schemas.command import (
    CommandRequest,
    CommandStatus,
)


def create_repository():
    """Create a command repository with a mocked MongoDB collection."""

    collection = MagicMock()
    repository = CommandRepository(collection)
    return repository, collection


def test_create_command():
    repository, collection = create_repository()

    result = repository.create_command(
        "user-123",
        "XEV-DEMO-001",
        CommandRequest(operation="lock"),
    )

    collection.insert_one.assert_called_once_with(result)
    assert result["user_id"] == "user-123"
    assert result["vehicle_id"] == "XEV-DEMO-001"
    assert result["operation"] == "lock"
    assert result["status"] == "submitted"
    assert result["command_id"]
    assert result["requested_at"].tzinfo == UTC


def test_get_command():
    repository, collection = create_repository()
    expected = {"command_id": "command-123"}
    collection.find_one.return_value = expected

    result = repository.get_command(
        "XEV-DEMO-001",
        "command-123",
        "user-123",
    )

    assert result == expected
    collection.find_one.assert_called_once_with(
        {
            "command_id": "command-123",
            "vehicle_id": "XEV-DEMO-001",
            "user_id": "user-123",
        },
        {"_id": 0},
    )


def test_get_vehicle_commands():
    repository, collection = create_repository()
    expected = [{"command_id": "command-123"}]
    cursor = collection.find.return_value
    cursor.sort.return_value.limit.return_value = expected

    result = repository.get_vehicle_commands(
        "XEV-DEMO-001",
        "user-123",
    )

    assert result == expected
    cursor.sort.assert_called_once_with("requested_at", -1)
    cursor.sort.return_value.limit.assert_called_once_with(100)


def test_update_command_result():
    repository, collection = create_repository()
    collection.update_one.return_value.modified_count = 1
    completed_at = datetime.now(UTC)

    result = repository.update_command_result(
        "command-123",
        "XEV-DEMO-001",
        CommandStatus.SUCCEEDED,
        completed_at,
    )

    assert result is True
    collection.update_one.assert_called_once_with(
        {
            "command_id": "command-123",
            "vehicle_id": "XEV-DEMO-001",
            "status": "submitted",
        },
        {
            "$set": {
                "status": "succeeded",
                "completed_at": completed_at,
                "failure_reason": None,
            }
        },
    )


def test_update_command_result_rejects_invalid_status():
    repository, collection = create_repository()

    with pytest.raises(ValueError, match="Invalid execution result status"):
        repository.update_command_result(
            "command-123",
            "XEV-DEMO-001",
            CommandStatus.TIMED_OUT,
            datetime.now(UTC),
        )

    collection.update_one.assert_not_called()


def test_update_command_result_does_not_overwrite_final_status():
    repository, collection = create_repository()
    collection.update_one.return_value.modified_count = 0

    result = repository.update_command_result(
        "command-123",
        "XEV-DEMO-001",
        CommandStatus.SUCCEEDED,
        datetime.now(UTC),
    )

    assert result is False


def test_mark_command_timed_out():
    repository, collection = create_repository()
    collection.update_one.return_value.modified_count = 1
    completed_at = datetime.now(UTC)

    result = repository.mark_command_timed_out(
        "command-123",
        "XEV-DEMO-001",
        completed_at,
    )

    assert result is True
    collection.update_one.assert_called_once_with(
        {
            "command_id": "command-123",
            "vehicle_id": "XEV-DEMO-001",
            "status": "submitted",
        },
        {
            "$set": {
                "status": "timed_out",
                "completed_at": completed_at,
                "failure_reason": "Command execution timed out",
            }
        },
    )


def test_mark_command_timed_out_does_not_overwrite_final_status():
    repository, collection = create_repository()
    collection.update_one.return_value.modified_count = 0

    result = repository.mark_command_timed_out(
        "command-123",
        "XEV-DEMO-001",
        datetime.now(UTC),
    )

    assert result is False
