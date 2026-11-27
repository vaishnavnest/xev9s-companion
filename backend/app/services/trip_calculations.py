from datetime import UTC, datetime

from backend.app.core.trip_config import DEFAULT_BATTERY_CAPACITY_KWH


def normalize_utc_datetime(value: datetime) -> datetime:
    """Normalize a datetime to UTC, interpreting naive datetimes as UTC."""
    if value.tzinfo is None or value.utcoffset() is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def calculate_distance(start_odometer: float, end_odometer: float) -> float:
    """Calculate net trip distance from odometer readings without masking negatives."""
    if end_odometer < start_odometer:
        raise ValueError(
            f"Invalid odometer reading: ending ({end_odometer}) "
            f"cannot be less than starting ({start_odometer})"
        )
    return round(end_odometer - start_odometer, 2)


def calculate_duration(started_at: datetime, ended_at: datetime) -> int:
    """Calculate trip duration in integer seconds."""
    normalized_start = normalize_utc_datetime(started_at)
    normalized_end = normalize_utc_datetime(ended_at)
    if normalized_end < normalized_start:
        raise ValueError(
            f"Invalid trip timing: ending timestamp ({normalized_end}) "
            f"cannot precede starting timestamp ({normalized_start})"
        )
    return int((normalized_end - normalized_start).total_seconds())


def calculate_average_speed(distance_km: float, duration_seconds: int) -> float:
    """Calculate average speed in km/h when duration exceeds zero."""
    if duration_seconds <= 0:
        return 0.0
    hours = duration_seconds / 3600.0
    return round(distance_km / hours, 1)


def calculate_energy_consumed(
    start_battery: float,
    end_battery: float,
    battery_capacity_kwh: float = DEFAULT_BATTERY_CAPACITY_KWH,
) -> tuple[float, bool]:
    """Calculate estimated energy consumed from battery percentage drop.

    Returns:
        tuple of (energy_consumed_kwh, is_estimated)
    """
    if battery_capacity_kwh <= 0:
        raise ValueError("Battery capacity must be positive")

    delta_battery = start_battery - end_battery
    if delta_battery > 0:
        kwh = round((delta_battery / 100.0) * battery_capacity_kwh, 2)
        return kwh, True

    return 0.0, True
