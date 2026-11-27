from datetime import UTC, datetime, timedelta, timezone

import pytest
from backend.app.services.trip_calculations import (
    calculate_average_speed,
    calculate_distance,
    calculate_duration,
    calculate_energy_consumed,
    normalize_utc_datetime,
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


def test_normalize_utc_datetime_naive_and_aware():
    naive = datetime(2026, 11, 26, 10, 0, 0)
    assert normalize_utc_datetime(naive) == datetime(2026, 11, 26, 10, 0, 0, tzinfo=UTC)

    ist = timezone(timedelta(hours=5, minutes=30))
    aware_ist = datetime(2026, 11, 26, 15, 30, 0, tzinfo=ist)
    assert normalize_utc_datetime(aware_ist) == datetime(
        2026, 11, 26, 10, 0, 0, tzinfo=UTC
    )


def test_calculate_duration_naive_start_aware_end():
    start = datetime(2026, 11, 26, 10, 0, 0)
    end = datetime(2026, 11, 26, 10, 30, 0, tzinfo=UTC)
    assert calculate_duration(start, end) == 1800


def test_calculate_duration_aware_start_naive_end():
    start = datetime(2026, 11, 26, 10, 0, 0, tzinfo=UTC)
    end = datetime(2026, 11, 26, 10, 45, 0)
    assert calculate_duration(start, end) == 2700


def test_calculate_duration_both_naive():
    start = datetime(2026, 11, 26, 10, 0, 0)
    end = datetime(2026, 11, 26, 10, 15, 0)
    assert calculate_duration(start, end) == 900


def test_calculate_duration_different_utc_offsets():
    ist = timezone(timedelta(hours=5, minutes=30))
    est = timezone(timedelta(hours=-5))

    # Same instant: 10:00 UTC == 15:30 IST == 05:00 EST
    start_same = datetime(2026, 11, 26, 15, 30, 0, tzinfo=ist)
    end_same = datetime(2026, 11, 26, 5, 0, 0, tzinfo=est)
    assert calculate_duration(start_same, end_same) == 0

    # Different instants: 10:00 UTC to 10:20 UTC
    end_later = datetime(2026, 11, 26, 5, 20, 0, tzinfo=est)
    assert calculate_duration(start_same, end_later) == 1200


def test_calculate_duration_mixed_timezone_reversed_raises():
    start = datetime(2026, 11, 26, 10, 30, 0)
    end = datetime(2026, 11, 26, 10, 0, 0, tzinfo=UTC)
    with pytest.raises(ValueError, match="Invalid trip timing"):
        calculate_duration(start, end)
