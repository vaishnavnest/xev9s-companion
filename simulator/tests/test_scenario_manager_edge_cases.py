
import pytest
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import ScenarioConfig, ScenarioType
from simulator.vehicle.state import VehicleState


@pytest.fixture
def manager() -> ScenarioManager:
    return ScenarioManager(VehicleState(vehicle_id="XEV-002"))


def test_new_scenario_uses_original_baseline(
    manager: ScenarioManager,
) -> None:
    manager.select_scenario(
        ScenarioType.PARKED_BATTERY_LEVEL,
        ScenarioConfig(initial_battery_percentage=65.0),
    )
    manager.state.battery_percentage = 10.0

    state = manager.select_scenario(ScenarioType.DRIVING_ROUTE)

    assert state.battery_percentage == 80.0
    assert state.estimated_range_km == 300.0


def test_invalid_selection_preserves_manager_state(
    manager: ScenarioManager,
) -> None:
    manager.select_scenario(ScenarioType.PARKED_BATTERY_LEVEL)
    original_battery = manager.state.battery_percentage
    original_scenario = manager.selected_scenario
    original_config = manager.config

    with pytest.raises(TypeError, match="Invalid scenario type"):
        manager.select_scenario("INVALID")  # type: ignore[arg-type]

    assert manager.state.battery_percentage == original_battery
    assert manager.selected_scenario == original_scenario
    assert manager.config == original_config


def test_low_battery_threshold_below_one(
    manager: ScenarioManager,
) -> None:
    state = manager.select_scenario(
        ScenarioType.LOW_BATTERY,
        ScenarioConfig(battery_alert_threshold=0.5),
    )

    assert state.battery_percentage == 0.0


@pytest.mark.parametrize(
    "charging_power",
    [0.0, -1.0, float("nan"), float("inf")],
)
def test_invalid_charging_power_is_rejected(
    charging_power: float,
) -> None:
    with pytest.raises(ValueError, match="positive finite"):
        ScenarioManager(
            VehicleState(vehicle_id="XEV-003"),
            charging_power_kw=charging_power,
        )
