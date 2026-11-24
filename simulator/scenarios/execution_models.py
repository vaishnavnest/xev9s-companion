from dataclasses import dataclass
from enum import Enum

from simulator.scenarios.models import ScenarioStatus
from simulator.telemetry.generator import TelemetryPayload


class ConnectivityStatus(str, Enum):
    """Connectivity state reported by the simulator."""

    ONLINE = "ONLINE"
    OFFLINE = "OFFLINE"


@dataclass(frozen=True, slots=True)
class ScenarioEvent:
    """An event produced during scenario execution."""

    event_type: str
    timestamp: str
    details: dict[str, str | float | bool]


@dataclass(frozen=True, slots=True)
class ScenarioExecutionUpdate:
    """Snapshot returned after an execution operation."""

    status: ScenarioStatus
    connectivity: ConnectivityStatus
    telemetry: TelemetryPayload
    events: tuple[ScenarioEvent, ...]