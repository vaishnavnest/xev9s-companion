from datetime import UTC, datetime
from uuid import uuid4

from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.schemas.trip import TripStatus


def create_route_point_document(
    latitude: float,
    longitude: float,
    timestamp: datetime | None = None,
    speed_kmh: float | None = None,
) -> dict:
    """Build a route point document for inclusion in trip route history."""
    return {
        "latitude": latitude,
        "longitude": longitude,
        "timestamp": timestamp,
        "speed_kmh": speed_kmh,
    }


def create_trip_document(
    telemetry: TelemetryPayload,
    trip_id: str | None = None,
) -> dict:
    """Build a MongoDB document for a newly instantiated vehicle trip."""
    now = datetime.now(UTC)
    start_time = telemetry.timestamp
    start_lat = telemetry.latitude
    start_lon = telemetry.longitude

    route = []
    if start_lat is not None and start_lon is not None:
        route.append(
            create_route_point_document(
                latitude=start_lat,
                longitude=start_lon,
                timestamp=start_time,
                speed_kmh=telemetry.speed_kph,
            )
        )

    return {
        "trip_id": trip_id or f"trp_{uuid4().hex[:8]}",
        "vehicle_id": telemetry.vehicle_id,
        "status": TripStatus.ONGOING.value,
        "started_at": start_time,
        "ended_at": None,
        "start_location": {
            "latitude": start_lat,
            "longitude": start_lon,
            "description": None,
        },
        "end_location": None,
        "start_odometer_km": telemetry.odometer_km,
        "end_odometer_km": None,
        "battery": {
            "start_percent": telemetry.battery_percentage,
            "end_percent": None,
        },
        "distance_km": None,
        "duration_seconds": None,
        "average_speed_kmh": None,
        "energy_consumed_kwh": None,
        "energy_consumed_is_estimated": True,
        "route": route,
        "last_telemetry_at": start_time,
        "created_at": now,
        "updated_at": now,
    }
