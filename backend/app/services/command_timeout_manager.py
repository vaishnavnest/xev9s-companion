
from datetime import UTC, datetime
from threading import Lock, Timer

from backend.app.core.command_config import (
    COMMAND_EXECUTION_TIMEOUT_SECONDS,
)
from backend.app.repositories.command_repository import (
    CommandRepository,
)


class CommandTimeoutManager:
    """Manage execution deadlines for submitted vehicle commands."""

    def __init__(self, repository: CommandRepository) -> None:
        self.repository = repository
        self._timers: dict[str, Timer] = {}
        self._lock = Lock()

    def start(self, command_id: str, vehicle_id: str) -> None:
        """Start the execution timeout for a command."""
        timer = Timer(
            COMMAND_EXECUTION_TIMEOUT_SECONDS,
            self._expire,
            args=(command_id, vehicle_id),
        )
        timer.daemon = True

        with self._lock:
            self._timers[command_id] = timer

        timer.start()

    def cancel(self, command_id: str) -> None:
        """Cancel a command's execution timeout."""
        with self._lock:
            timer = self._timers.pop(command_id, None)

        if timer is not None:
            timer.cancel()

    def _expire(self, command_id: str, vehicle_id: str) -> None:
        """Mark a command timed out if it is still submitted."""
        try:
            self.repository.mark_command_timed_out(
                command_id,
                vehicle_id,
                datetime.now(UTC),
            )
        finally:
            with self._lock:
                self._timers.pop(command_id, None)

    def stop_all(self) -> None:
        """Cancel all active timeout timers during shutdown."""
        with self._lock:
            timers = list(self._timers.values())
            self._timers.clear()

        for timer in timers:
            timer.cancel()
