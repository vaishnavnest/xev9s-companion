from datetime import UTC, datetime
from typing import TypedDict

from simulator.vehicle.state import VehicleState


class TelemetryPayload(TypedDict):
    """Structure of a simulated vehicle telemetry record."""

    vehicle_id: str
    timestamp: str
    battery_percentage: float
    estimated_range_km: float
    speed_kph: float
    odometer_km: float
    latitude: float | None
    longitude: float | None
    operating_state: str
    is_locked: bool
    charging_status: str
    charging_power_kw: float
    cabin_preconditioning_active: bool


def generate_telemetry(state: VehicleState) -> TelemetryPayload:
    """Generate telemetry using the vehicle's current state."""

    return {
        "vehicle_id": state.vehicle_id,
        "timestamp": datetime.now(UTC).isoformat(),
        "battery_percentage": state.battery_percentage,
        "estimated_range_km": state.estimated_range_km,
        "speed_kph": state.speed_kph,
        "odometer_km": state.odometer_km,
        "latitude": state.latitude,
        "longitude": state.longitude,
        "operating_state": state.operating_state.value,
        "is_locked": state.is_locked,
        "charging_status": state.charging_status.value,
        "charging_power_kw": state.charging_power_kw,
        "cabin_preconditioning_active": (
            state.cabin_preconditioning_active
        ),
    }
