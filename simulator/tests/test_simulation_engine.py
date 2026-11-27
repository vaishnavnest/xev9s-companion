
from datetime import UTC, datetime

import pytest

from simulator.vehicle.simulation_engine import (
    SimulationConfig,
    SimulationEngine,
)
from simulator.vehicle.state import (
    OperatingState,
    VehicleState,
)


def test_driving_updates_vehicle_measurements() -> None:
    state = VehicleState(
        vehicle_id="XEV-001",
        operating_state=OperatingState.DRIVING,
    )
    engine = SimulationEngine(state)

    engine.advance(3600)

    assert state.speed_kph == 60.0
    assert state.odometer_km == pytest.approx(60.0)
    assert state.battery_percentage == pytest.approx(64.0)
    assert state.estimated_range_km == pytest.approx(240.0)


def test_parked_vehicle_measurements_remain_unchanged() -> None:
    state = VehicleState(vehicle_id="XEV-005")
    engine = SimulationEngine(state)

    engine.advance(60)

    assert state.battery_percentage == 80.0
    assert state.odometer_km == 0.0
    assert state.speed_kph == 0.0


def test_custom_simulation_configuration() -> None:
    state = VehicleState(
        vehicle_id="XEV-006",
        operating_state=OperatingState.DRIVING,
    )
    config = SimulationConfig(
        driving_speed_kph=100.0,
        energy_consumption_kwh_per_100km=20.0,
        battery_capacity_kwh=80.0,
        charging_power_kw=11.0,
    )

    SimulationEngine(state, config).advance(3600)

    assert state.odometer_km == pytest.approx(100.0)
    assert state.battery_percentage == pytest.approx(55.0)


def test_battery_depletion_stops_driving_safely() -> None:
    state = VehicleState(
        vehicle_id="XEV-007",
        battery_percentage=1.0,
        operating_state=OperatingState.DRIVING,
    )
    engine = SimulationEngine(state)

    engine.advance(3600)

    assert state.battery_percentage == 0.0
    assert state.operating_state == OperatingState.PARKED
    assert state.speed_kph == 0.0
    assert state.odometer_km == pytest.approx(3.75)
    assert state.estimated_range_km == 0.0


def test_insufficient_battery_does_not_overshoot() -> None:
    state = VehicleState(
        vehicle_id="XEV-008",
        battery_percentage=1.0,
        operating_state=OperatingState.DRIVING,
    )
    engine = SimulationEngine(state)

    engine.advance(3600)

    assert state.battery_percentage >= 0.0
    assert state.odometer_km <= 3.75


def test_simulation_updates_timestamp() -> None:
    previous = datetime(2026, 1, 1, tzinfo=UTC)
    state = VehicleState(
        vehicle_id="XEV-009",
        operating_state=OperatingState.DRIVING,
        updated_at=previous,
    )

    SimulationEngine(state).advance(60)

    assert state.updated_at > previous
    assert state.updated_at.tzinfo is not None


def test_failed_validation_does_not_change_state() -> None:
    state = VehicleState(
        vehicle_id="XEV-010",
        operating_state=OperatingState.DRIVING,
    )
    previous_timestamp = state.updated_at
    engine = SimulationEngine(state)

    with pytest.raises(ValueError, match="elapsed_seconds"):
        engine.advance(0)

    assert state.battery_percentage == 80.0
    assert state.odometer_km == 0.0
    assert state.updated_at == previous_timestamp


@pytest.mark.parametrize(
    "elapsed",
    [0, -1, float("nan"), float("inf")],
)
def test_rejects_invalid_elapsed_time(elapsed: float) -> None:
    engine = SimulationEngine(VehicleState(vehicle_id="XEV-011"))

    with pytest.raises(ValueError, match="elapsed_seconds"):
        engine.advance(elapsed)


@pytest.mark.parametrize(
    "config",
    [
        {"driving_speed_kph": 0},
        {"energy_consumption_kwh_per_100km": -1},
        {"battery_capacity_kwh": float("inf")},
        {"charging_power_kw": float("nan")},
    ],
)
def test_rejects_invalid_simulation_configuration(
    config: dict[str, float],
) -> None:
    with pytest.raises(ValueError, match="finite and positive"):
        SimulationConfig(**config)
