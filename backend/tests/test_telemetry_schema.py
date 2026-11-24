
import pytest
from backend.app.schemas.telemetry import TelemetryPayload
from pydantic import ValidationError


@pytest.fixture
def valid_telemetry():
    return {
        "vehicle_id": "XEV9S-001",
        "timestamp": "2026-11-23T09:30:00+00:00",
        "battery_percentage": 80.0,
        "estimated_range_km": 300.0,
        "speed_kph": 0.0,
        "odometer_km": 1200.5,
        "latitude": 8.5241,
        "longitude": 76.9366,
        "operating_state": "parked",
        "is_locked": True,
        "charging_status": "disconnected",
        "charging_power_kw": 0.0,
        "cabin_preconditioning_active": False,
    }


def test_valid_telemetry_payload(valid_telemetry):
    telemetry = TelemetryPayload(**valid_telemetry)

    assert telemetry.vehicle_id == "XEV9S-001"
    assert telemetry.battery_percentage == 80.0
    assert telemetry.operating_state == "parked"


def test_missing_required_field_rejected(valid_telemetry):
    valid_telemetry.pop("battery_percentage")

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)


@pytest.mark.parametrize("battery", [-1, 101])
def test_invalid_battery_percentage_rejected(valid_telemetry, battery):
    valid_telemetry["battery_percentage"] = battery

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [(91, 0), (-91, 0), (0, 181), (0, -181)],
)
def test_invalid_coordinates_rejected(
    valid_telemetry,
    latitude,
    longitude,
):
    valid_telemetry["latitude"] = latitude
    valid_telemetry["longitude"] = longitude

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [(None, 76.9366), (8.5241, None)],
)
def test_incomplete_coordinates_rejected(
    valid_telemetry,
    latitude,
    longitude,
):
    valid_telemetry["latitude"] = latitude
    valid_telemetry["longitude"] = longitude

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)


@pytest.mark.parametrize(
    "operating_state",
    ["unknown", "idle", "offline"],
)
def test_invalid_operating_state_rejected(
    valid_telemetry,
    operating_state,
):
    valid_telemetry["operating_state"] = operating_state

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)


@pytest.mark.parametrize(
    "charging_status",
    ["unknown", "offline"],
)
def test_invalid_charging_status_rejected(
    valid_telemetry,
    charging_status,
):
    valid_telemetry["charging_status"] = charging_status

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)


def test_unexpected_field_rejected(valid_telemetry):
    valid_telemetry["unexpected_field"] = "not-allowed"

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)


def test_negative_measurement_rejected(valid_telemetry):
    valid_telemetry["speed_kph"] = -10

    with pytest.raises(ValidationError):
        TelemetryPayload(**valid_telemetry)
