import pytest

from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import (
    ChargingStatus,
    OperatingState,
    VehicleState,
)


def test_charging_updates_battery_and_range() -> None:
    state = VehicleState(
        vehicle_id="XEV-002",
        battery_percentage=50.0,
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
    )
    engine = SimulationEngine(state)

    engine.advance(3600)

    assert state.battery_percentage == pytest.approx(62.0)
    assert state.estimated_range_km == pytest.approx(232.5)
    assert state.charging_power_kw == 7.2


def test_charging_completion_stops_vehicle_charging() -> None:
    state = VehicleState(
        vehicle_id="XEV-003",
        battery_percentage=99.0,
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
    )
    engine = SimulationEngine(state)

    engine.advance(3600)

    assert state.battery_percentage == 100.0
    assert state.operating_state == OperatingState.PARKED
    assert state.charging_status == ChargingStatus.DISCONNECTED
    assert state.charging_power_kw == 0.0
    assert state.estimated_range_km == pytest.approx(375.0)


def test_already_full_battery_completes_charging() -> None:
    state = VehicleState(
        vehicle_id="XEV-004",
        battery_percentage=100.0,
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
    )
    engine = SimulationEngine(state)

    engine.advance(60)

    assert state.operating_state == OperatingState.PARKED
    assert state.charging_power_kw == 0.0


def test_charging_stops_at_configured_target_percentage() -> None:
    state = VehicleState(
        vehicle_id="XEV-012",
        battery_percentage=78.0,
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
    )
    engine = SimulationEngine(state)
    engine.update_charging_preferences(
        {
            "target_percentage": 80.0,
            "stop_charging_at_target": True,
            "schedule_enabled": True,
            "scheduled_start_time": "22:00:00",
            "scheduled_end_time": "06:00:00",
            "scheduled_days": ["monday"],
            "timezone": "Asia/Kolkata",
        }
    )

    engine.advance(3600)

    assert state.battery_percentage == 80.0
    assert state.operating_state == OperatingState.PARKED
    assert state.charging_status == ChargingStatus.DISCONNECTED
    assert state.charging_power_kw == 0.0
    assert engine.schedule_enabled is True
    assert engine.scheduled_days == ["monday"]


def test_charging_ignores_target_when_stop_at_target_disabled() -> None:
    state = VehicleState(
        vehicle_id="XEV-013",
        battery_percentage=78.0,
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
    )
    engine = SimulationEngine(state)
    engine.update_charging_preferences(
        {
            "target_percentage": 80.0,
            "stop_charging_at_target": False,
        }
    )

    engine.advance(3600)

    assert state.battery_percentage == pytest.approx(90.0)
    assert state.operating_state == OperatingState.CHARGING
