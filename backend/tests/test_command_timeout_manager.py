from unittest.mock import MagicMock

import pytest
from backend.app.services import command_timeout_manager as timeout_module
from backend.app.services.command_timeout_manager import CommandTimeoutManager


@pytest.fixture
def setup_manager(monkeypatch):
    repository = MagicMock()
    timers = []

    def create_timer(*args, **kwargs):
        timer = MagicMock()
        timer.args = args
        timer.kwargs = kwargs
        timers.append(timer)
        return timer

    monkeypatch.setattr(timeout_module, "Timer", create_timer)

    manager = CommandTimeoutManager(repository)
    return manager, repository, timers


def test_start_creates_and_starts_timer(setup_manager):
    manager, _repository, timers = setup_manager

    manager.start("command-1", "vehicle-1")

    assert len(timers) == 1
    timer = timers[0]
    assert timer.args[0] == timeout_module.COMMAND_EXECUTION_TIMEOUT_SECONDS
    assert timer.args[1] == manager._expire
    assert timer.kwargs["args"] == ("command-1", "vehicle-1")
    assert timer.daemon is True
    timer.start.assert_called_once()


def test_cancel_removes_and_cancels_timer(setup_manager):
    manager, _repository, timers = setup_manager

    manager.start("command-1", "vehicle-1")
    manager.cancel("command-1")

    timers[0].cancel.assert_called_once()
    assert "command-1" not in manager._timers


def test_cancel_unknown_command_is_safe(setup_manager):
    manager, _repository, _timers = setup_manager

    manager.cancel("unknown-command")


def test_expire_marks_command_timed_out(setup_manager):
    manager, repository, _timers = setup_manager

    manager._expire("command-1", "vehicle-1")

    repository.mark_command_timed_out.assert_called_once()
    args = repository.mark_command_timed_out.call_args.args

    assert args[:2] == ("command-1", "vehicle-1")
    assert args[2].tzinfo is not None


def test_expire_removes_timer(setup_manager):
    manager, _repository, timers = setup_manager

    manager.start("command-1", "vehicle-1")
    manager._expire("command-1", "vehicle-1")

    assert "command-1" not in manager._timers
    timers[0].start.assert_called_once()


def test_expire_removes_timer_when_repository_fails(setup_manager):
    manager, repository, _timers = setup_manager
    repository.mark_command_timed_out.side_effect = RuntimeError("DB error")

    manager.start("command-1", "vehicle-1")

    with pytest.raises(RuntimeError, match="DB error"):
        manager._expire("command-1", "vehicle-1")

    assert "command-1" not in manager._timers


def test_stop_all_cancels_every_timer(setup_manager):
    manager, _repository, timers = setup_manager

    manager.start("command-1", "vehicle-1")
    manager.start("command-2", "vehicle-2")

    manager.stop_all()

    assert manager._timers == {}
    for timer in timers:
        timer.cancel.assert_called_once()
