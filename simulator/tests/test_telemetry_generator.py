
from datetime import UTC, datetime

from simulator.telemetry.generator import generate_telemetry
from simulator.vehicle.state import (
    ChargingStatus,
    OperatingState,
    VehicleState,
)


def test_generates_telemetry_from_default_state() -> None:
    state = VehicleState(vehicle_id="XEV-001")

    telemetry = generate_telemetry(state)

    assert telemetry["vehicle_id"] == "XEV-001"
    assert telemetry["battery_percentage"] == 80.0
    assert telemetry["estimated_range_km"] == 300.0
    assert telemetry["speed_kph"] == 0.0
    assert telemetry["odometer_km"] == 0.0
    assert telemetry["operating_state"] == "parked"
    assert telemetry["charging_status"] == "disconnected"
    assert telemetry["is_locked"] is True
    assert telemetry["charging_power_kw"] == 0.0
    assert telemetry["cabin_preconditioning_active"] is False


def test_generates_telemetry_from_custom_state() -> None:
    state = VehicleState(
        vehicle_id="XEV-002",
        battery_percentage=65.0,
        estimated_range_km=240.0,
        odometer_km=1250.5,
        latitude=8.5241,
        longitude=76.9366,
        speed_kph=45.0,
        operating_state=OperatingState.DRIVING,
        is_locked=False,
    )

    telemetry = generate_telemetry(state)

    assert telemetry["vehicle_id"] == "XEV-002"
    assert telemetry["battery_percentage"] == 65.0
    assert telemetry["estimated_range_km"] == 240.0
    assert telemetry["odometer_km"] == 1250.5
    assert telemetry["latitude"] == 8.5241
    assert telemetry["longitude"] == 76.9366
    assert telemetry["speed_kph"] == 45.0
    assert telemetry["operating_state"] == "driving"
    assert telemetry["is_locked"] is False


def test_generates_charging_telemetry() -> None:
    state = VehicleState(
        vehicle_id="XEV-003",
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
        charging_power_kw=7.2,
    )

    telemetry = generate_telemetry(state)

    assert telemetry["operating_state"] == "charging"
    assert telemetry["charging_status"] == "charging"
    assert telemetry["charging_power_kw"] == 7.2


def test_generates_interrupted_charging_telemetry() -> None:
    state = VehicleState(
        vehicle_id="XEV-004",
        operating_state=OperatingState.INTERRUPTED,
        charging_status=ChargingStatus.INTERRUPTED,
    )

    telemetry = generate_telemetry(state)

    assert telemetry["operating_state"] == "interrupted"
    assert telemetry["charging_status"] == "interrupted"


def test_timestamp_is_iso_formatted() -> None:
    telemetry = generate_telemetry(
        VehicleState(vehicle_id="XEV-005")
    )

    parsed_timestamp = datetime.fromisoformat(telemetry["timestamp"])

    assert parsed_timestamp.tzinfo == UTC


def test_missing_location_is_preserved() -> None:
    state = VehicleState(vehicle_id="XEV-006")

    telemetry = generate_telemetry(state)

    assert telemetry["latitude"] is None
    assert telemetry["longitude"] is None


def test_updated_state_generates_updated_telemetry() -> None:
    state = VehicleState(vehicle_id="XEV-007")

    first_record = generate_telemetry(state)

    state.battery_percentage = 55.0
    state.estimated_range_km = 200.0
    state.odometer_km = 150.0

    second_record = generate_telemetry(state)

    assert first_record["battery_percentage"] == 80.0
    assert second_record["battery_percentage"] == 55.0
    assert second_record["estimated_range_km"] == 200.0
    assert second_record["odometer_km"] == 150.0
