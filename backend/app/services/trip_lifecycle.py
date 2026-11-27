import logging
from collections.abc import Callable
from datetime import datetime

from backend.app.core.exceptions import TripAlreadyActiveError
from backend.app.core.trip_config import (
    DEFAULT_BATTERY_CAPACITY_KWH,
    TRIP_END_STATE,
    TRIP_START_STATE,
)
from backend.app.models.trip import create_route_point_document
from backend.app.repositories.trip_repository import TripRepository
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.trip_calculations import (
    calculate_average_speed,
    calculate_distance,
    calculate_duration,
    calculate_energy_consumed,
)

logger = logging.getLogger(__name__)


class TripLifecycleManager:
    """Manages trip detection, in-transit updates, and completion."""

    def __init__(
        self,
        trip_repository: TripRepository,
        on_trip_completed: Callable[[dict], None] | None = None,
        battery_capacity_kwh: float = DEFAULT_BATTERY_CAPACITY_KWH,
    ) -> None:
        self.trip_repository = trip_repository
        self.on_trip_completed = on_trip_completed
        self.battery_capacity_kwh = battery_capacity_kwh

    def process_telemetry(self, telemetry: TelemetryPayload) -> dict | None:
        """Process incoming vehicle telemetry to detect or advance trips."""
        state = telemetry.operating_state

        if state == TRIP_START_STATE:
            return self._handle_driving_telemetry(telemetry)

        if state == TRIP_END_STATE:
            return self._handle_parked_telemetry(telemetry)

        return None

    def _handle_driving_telemetry(self, telemetry: TelemetryPayload) -> dict:
        """Create a new trip or associate telemetry with an existing active trip."""
        active_trip = self.trip_repository.get_active_trip(telemetry.vehicle_id)

        if active_trip is None:
            try:
                trip = self.trip_repository.create_trip(telemetry)
                logger.info(
                    "Started trip %s for vehicle %s",
                    trip["trip_id"],
                    telemetry.vehicle_id,
                )
                return trip
            except TripAlreadyActiveError:
                active_trip = self.trip_repository.get_active_trip(telemetry.vehicle_id)
                if active_trip is not None:
                    return self._append_route_sample(active_trip, telemetry)
                raise

        return self._append_route_sample(active_trip, telemetry)

    def _append_route_sample(
        self,
        active_trip: dict,
        telemetry: TelemetryPayload,
    ) -> dict:
        """Record GPS and speed telemetry samples for an active trip."""
        trip_id = active_trip["trip_id"]

        if telemetry.latitude is not None and telemetry.longitude is not None:
            point = create_route_point_document(
                latitude=telemetry.latitude,
                longitude=telemetry.longitude,
                timestamp=telemetry.timestamp,
                speed_kmh=telemetry.speed_kph,
            )
            self.trip_repository.append_route_point(
                trip_id=trip_id,
                point=point,
                telemetry_timestamp=telemetry.timestamp,
            )

        return active_trip

    def _handle_parked_telemetry(
        self,
        telemetry: TelemetryPayload,
    ) -> dict | None:
        """Complete an active trip upon vehicle parking."""
        active_trip = self.trip_repository.get_active_trip(telemetry.vehicle_id)
        if active_trip is None:
            return None

        trip_id = active_trip["trip_id"]
        started_at = active_trip["started_at"]
        start_odo = active_trip["start_odometer_km"]
        start_battery = active_trip["battery"]["start_percent"]

        # Ensure timezone compatibility for calculation
        ended_at = telemetry.timestamp
        if isinstance(started_at, str):
            started_at = datetime.fromisoformat(started_at)

        distance = calculate_distance(start_odo, telemetry.odometer_km)
        duration = calculate_duration(started_at, ended_at)
        avg_speed = calculate_average_speed(distance, duration)
        energy_kwh, is_estimated = calculate_energy_consumed(
            start_battery=start_battery,
            end_battery=telemetry.battery_percentage,
            battery_capacity_kwh=self.battery_capacity_kwh,
        )

        updates = {
            "ended_at": ended_at,
            "end_location": {
                "latitude": telemetry.latitude,
                "longitude": telemetry.longitude,
                "description": None,
            },
            "end_odometer_km": telemetry.odometer_km,
            "battery.end_percent": telemetry.battery_percentage,
            "distance_km": distance,
            "duration_seconds": duration,
            "average_speed_kmh": avg_speed,
            "energy_consumed_kwh": energy_kwh,
            "energy_consumed_is_estimated": is_estimated,
        }

        if telemetry.latitude is not None and telemetry.longitude is not None:
            final_point = create_route_point_document(
                latitude=telemetry.latitude,
                longitude=telemetry.longitude,
                timestamp=ended_at,
                speed_kmh=telemetry.speed_kph,
            )
            self.trip_repository.append_route_point(
                trip_id=trip_id,
                point=final_point,
                telemetry_timestamp=ended_at,
            )

        completed_trip = self.trip_repository.complete_trip(trip_id, updates)

        if completed_trip is not None:
            logger.info(
                "Completed trip %s for vehicle %s", trip_id, telemetry.vehicle_id
            )
            if self.on_trip_completed is not None:
                try:
                    self.on_trip_completed(completed_trip)
                except Exception:
                    logger.exception("Failed to dispatch trip.completed event")

        return completed_trip
