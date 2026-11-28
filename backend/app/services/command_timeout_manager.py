import logging
from collections.abc import Callable
from datetime import UTC, datetime
from threading import Lock, Timer
from typing import Any

from backend.app.core.command_config import (
    COMMAND_EXECUTION_TIMEOUT_SECONDS,
)
from backend.app.repositories.command_repository import (
    CommandRepository,
)
from backend.app.schemas.command import CommandStatus

logger = logging.getLogger(__name__)


class CommandTimeoutManager:
    """Manage execution deadlines for submitted vehicle commands."""

    def __init__(
        self,
        repository: CommandRepository,
        on_command_timed_out: Callable[[dict[str, Any]], None] | None = None,
    ) -> None:
        self.repository = repository
        self.on_command_timed_out = on_command_timed_out
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
        completed_at = datetime.now(UTC)
        try:
            updated = self.repository.mark_command_timed_out(
                command_id,
                vehicle_id,
                completed_at,
            )
            if updated is True and self.on_command_timed_out is not None:
                command = self.repository.get_command_for_response(
                    command_id, vehicle_id
                )
                if command is not None:
                    try:
                        self.on_command_timed_out(
                            {
                                "event": "command_updated",
                                "command_id": command_id,
                                "vehicle_id": vehicle_id,
                                "operation": command["operation"],
                                "status": CommandStatus.TIMED_OUT.value,
                                "requested_at": command["requested_at"],
                                "completed_at": completed_at,
                                "failure_reason": command.get("failure_reason"),
                            }
                        )
                    except Exception:
                        logger.exception("Failed to emit command timeout notification")
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
