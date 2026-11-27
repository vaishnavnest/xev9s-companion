from datetime import UTC, datetime, timedelta

from backend.app.core.command_config import VEHICLE_ONLINE_TIMEOUT_SECONDS
from backend.app.core.exceptions import VehicleOfflineError
from backend.app.repositories.telemetry_repository import TelemetryRepository


def ensure_vehicle_online(
    telemetry_repository: TelemetryRepository,
    vehicle_id: str,
) -> None:
    """Reject vehicles without sufficiently recent telemetry."""

    telemetry = telemetry_repository.get_latest_telemetry(vehicle_id)

    if telemetry is None:
        raise VehicleOfflineError("Vehicle has no recorded telemetry")

    timestamp = telemetry.get("timestamp")

    if not isinstance(timestamp, datetime):
        raise VehicleOfflineError("Vehicle telemetry timestamp is invalid")

    if timestamp.tzinfo is None or timestamp.utcoffset() is None:
        # PyMongo returns naive UTC datetimes by default.
        timestamp = timestamp.replace(tzinfo=UTC)

    now = datetime.now(UTC)
    age = now - timestamp

    if age < timedelta(0):
        raise VehicleOfflineError("Vehicle telemetry timestamp is in the future")

    if age > timedelta(seconds=VEHICLE_ONLINE_TIMEOUT_SECONDS):
        raise VehicleOfflineError("Vehicle is offline because telemetry is stale")
