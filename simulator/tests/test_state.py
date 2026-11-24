
from datetime import datetime

import pytest

from simulator.vehicle.state import (
    ChargingStatus,
    OperatingState,
    VehicleState,
)


def test_default_vehicle_state():
    vehicle = VehicleState(vehicle_id="XEV001")

    assert vehicle.vehicle_id == "XEV001"
    assert vehicle.battery_percentage == 80.0
    assert vehicle.operating_state == OperatingState.PARKED
    assert vehicle.charging_status == ChargingStatus.DISCONNECTED
    assert vehicle.updated_at.tzinfo is not None


def test_custom_vehicle_state():
    vehicle = VehicleState(
        vehicle_id="XEV002",
        battery_percentage=65.0,
        estimated_range_km=250.0,
        odometer_km=1200.0,
        latitude=8.5241,
        longitude=76.9366,
        speed_kph=40.0,
        is_locked=False,
    )

    assert vehicle.battery_percentage == 65.0
    assert vehicle.estimated_range_km == 250.0
    assert vehicle.odometer_km == 1200.0
    assert vehicle.speed_kph == 40.0


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("battery_percentage", 101.0),
        ("battery_percentage", -1.0),
        ("estimated_range_km", -10.0),
        ("odometer_km", -1.0),
        ("speed_kph", -5.0),
        ("charging_power_kw", -2.0),
        ("speed_kph", float("nan")),
        ("odometer_km", float("inf")),
    ],
)
def test_rejects_invalid_measurements(field, value):
    with pytest.raises(ValueError):
        VehicleState(vehicle_id="XEV003", **{field: value})


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [
        (91.0, 76.0),
        (-91.0, 76.0),
        (8.0, 181.0),
        (8.0, -181.0),
        (8.0, None),
        (None, 76.0),
    ],
)
def test_rejects_invalid_coordinates(latitude, longitude):
    with pytest.raises(ValueError):
        VehicleState(
            vehicle_id="XEV004",
            latitude=latitude,
            longitude=longitude,
        )


def test_rejects_empty_vehicle_id():
    with pytest.raises(ValueError):
        VehicleState(vehicle_id="   ")


def test_rejects_driving_while_charging():
    with pytest.raises(ValueError):
        VehicleState(
            vehicle_id="XEV005",
            operating_state=OperatingState.DRIVING,
            charging_status=ChargingStatus.CHARGING,
        )


def test_rejects_charging_without_active_status():
    with pytest.raises(ValueError):
        VehicleState(
            vehicle_id="XEV006",
            operating_state=OperatingState.CHARGING,
            charging_status=ChargingStatus.CONNECTED,
        )


def test_rejects_nonzero_power_when_not_charging():
    with pytest.raises(ValueError):
        VehicleState(
            vehicle_id="XEV007",
            charging_power_kw=7.2,
        )


def test_rejects_naive_timestamp():
    with pytest.raises(ValueError):
        VehicleState(
            vehicle_id="XEV008",
            updated_at=datetime.now(),
        )


def test_accepts_valid_charging_state():
    vehicle = VehicleState(
        vehicle_id="XEV009",
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
        charging_power_kw=7.2,
    )

    assert vehicle.operating_state == OperatingState.CHARGING
    assert vehicle.charging_power_kw == 7.2


def test_accepts_interrupted_charging_state():
    vehicle = VehicleState(
        vehicle_id="XEV010",
        operating_state=OperatingState.INTERRUPTED,
        charging_status=ChargingStatus.INTERRUPTED,
    )

    assert vehicle.charging_status == ChargingStatus.INTERRUPTED

@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("battery_percentage", True),
        ("estimated_range_km", False),
        ("odometer_km", float("nan")),
        ("charging_power_kw", float("inf")),
    ],
)
def test_rejects_invalid_numeric_types(field, value):
    with pytest.raises(ValueError):
        VehicleState(vehicle_id="XEV011", **{field: value})


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [
        (float("nan"), 76.0),
        (8.0, float("inf")),
        (float("-inf"), 76.0),
    ],
)
def test_rejects_non_finite_coordinates(latitude, longitude):
    with pytest.raises(ValueError):
        VehicleState(
            vehicle_id="XEV012",
            latitude=latitude,
            longitude=longitude,
        )