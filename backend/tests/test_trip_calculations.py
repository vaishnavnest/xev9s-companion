from datetime import UTC, datetime

import pytest
from backend.app.services.trip_calculations import (
    calculate_average_speed,
    calculate_distance,
    calculate_duration,
    calculate_energy_consumed,
)


def test_calculate_distance_valid():
    assert calculate_distance(100.0, 125.5) == 25.5
    assert calculate_distance(50.0, 50.0) == 0.0


def test_calculate_distance_invalid_decreased_odometer():
    with pytest.raises(ValueError, match="Invalid odometer reading"):
        calculate_distance(150.0, 140.0)


def test_calculate_duration_valid():
    start = datetime(2026, 11, 26, 10, 0, 0, tzinfo=UTC)
    end = datetime(2026, 11, 26, 10, 30, 0, tzinfo=UTC)
    assert calculate_duration(start, end) == 1800


def test_calculate_duration_invalid_reversed_timestamps():
    start = datetime(2026, 11, 26, 10, 30, 0, tzinfo=UTC)
    end = datetime(2026, 11, 26, 10, 0, 0, tzinfo=UTC)
    with pytest.raises(ValueError, match="Invalid trip timing"):
        calculate_duration(start, end)


def test_calculate_average_speed_normal():
    # 50 km in 3600 seconds (1 hour) -> 50 km/h
    assert calculate_average_speed(50.0, 3600) == 50.0
    # 25 km in 1800 seconds (0.5 hour) -> 50 km/h
    assert calculate_average_speed(25.0, 1800) == 50.0


def test_calculate_average_speed_zero_duration():
    assert calculate_average_speed(10.0, 0) == 0.0
    assert calculate_average_speed(0.0, -10) == 0.0


def test_calculate_energy_consumed_drop():
    # 10% drop on 60 kWh battery -> 6.0 kWh
    kwh, is_est = calculate_energy_consumed(80.0, 70.0, battery_capacity_kwh=60.0)
    assert kwh == 6.0
    assert is_est is True


def test_calculate_energy_consumed_no_drop_or_regen():
    kwh, is_est = calculate_energy_consumed(70.0, 75.0, battery_capacity_kwh=60.0)
    assert kwh == 0.0
    assert is_est is True


def test_calculate_energy_consumed_invalid_capacity():
    with pytest.raises(ValueError, match="Battery capacity must be positive"):
        calculate_energy_consumed(80.0, 70.0, battery_capacity_kwh=-10.0)
