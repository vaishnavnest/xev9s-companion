from datetime import UTC, datetime

import pytest
from backend.app.models.trip import (
    create_route_point_document,
    create_trip_document,
)
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.schemas.trip import (
    BatteryRange,
    NamedLocation,
    Pagination,
    RoutePoint,
    Trip,
    TripDetail,
    TripListResponse,
    TripStatus,
)
from pydantic import ValidationError


def make_telemetry(**kwargs):
    defaults = {
        "vehicle_id": "XEV-001",
        "timestamp": datetime.now(UTC),
        "battery_percentage": 85.0,
        "estimated_range_km": 320.0,
        "speed_kph": 50.0,
        "odometer_km": 1500.0,
        "latitude": 12.9716,
        "longitude": 77.5946,
        "operating_state": "driving",
        "is_locked": False,
        "charging_status": "disconnected",
        "charging_power_kw": 0.0,
        "cabin_preconditioning_active": False,
    }
    defaults.update(kwargs)
    return TelemetryPayload(**defaults)


def test_create_route_point_document():
    doc = create_route_point_document(
        latitude=12.9716,
        longitude=77.5946,
        timestamp=datetime.now(UTC),
        speed_kmh=45.0,
    )
    assert doc["latitude"] == 12.9716
    assert doc["longitude"] == 77.5946
    assert doc["speed_kmh"] == 45.0


def test_create_trip_document_with_coordinates():
    tel = make_telemetry()
    doc = create_trip_document(tel, trip_id="trp_custom1")
    assert doc["trip_id"] == "trp_custom1"
    assert doc["vehicle_id"] == "XEV-001"
    assert doc["status"] == TripStatus.ONGOING.value
    assert doc["start_location"]["latitude"] == 12.9716
    assert doc["start_location"]["longitude"] == 77.5946
    assert doc["start_odometer_km"] == 1500.0
    assert doc["battery"]["start_percent"] == 85.0
    assert len(doc["route"]) == 1
    assert doc["route"][0]["speed_kmh"] == 50.0


def test_create_trip_document_without_coordinates():
    tel = make_telemetry(latitude=None, longitude=None)
    doc = create_trip_document(tel)
    assert doc["start_location"]["latitude"] is None
    assert doc["start_location"]["longitude"] is None
    assert doc["route"] == []
    assert doc["trip_id"].startswith("trp_")


def test_trip_schema_validation_success():
    now = datetime.now(UTC)
    trip = Trip(
        trip_id="trp_001",
        status=TripStatus.ONGOING,
        started_at=now,
        start_location=NamedLocation(latitude=12.97, longitude=77.59),
    )
    assert trip.status == TripStatus.ONGOING
    assert trip.distance_km is None
    assert trip.ended_at is None


def test_trip_detail_schema_validation():
    now = datetime.now(UTC)
    detail = TripDetail(
        trip_id="trp_001",
        status=TripStatus.COMPLETED,
        started_at=now,
        ended_at=now,
        start_location=NamedLocation(latitude=12.97, longitude=77.59),
        end_location=NamedLocation(latitude=13.08, longitude=80.27),
        distance_km=25.5,
        duration_seconds=1800,
        energy_consumed_kwh=4.2,
        average_speed_kmh=51.0,
        battery=BatteryRange(start_percent=80.0, end_percent=73.0),
        route=[RoutePoint(latitude=12.97, longitude=77.59, speed_kmh=40.0)],
    )
    assert detail.average_speed_kmh == 51.0
    assert len(detail.route) == 1
    assert detail.battery.start_percent == 80.0


def test_route_point_validation_error():
    with pytest.raises(ValidationError):
        RoutePoint(latitude=95.0, longitude=77.59)


def test_trip_list_response_schema():
    now = datetime.now(UTC)
    trip = Trip(
        trip_id="trp_001",
        status=TripStatus.COMPLETED,
        started_at=now,
        start_location=NamedLocation(latitude=12.97, longitude=77.59),
    )
    pagination = Pagination(page=1, page_size=20, total_items=1, total_pages=1)
    res = TripListResponse(trips=[trip], pagination=pagination)
    assert len(res.trips) == 1
    assert res.pagination.total_items == 1
