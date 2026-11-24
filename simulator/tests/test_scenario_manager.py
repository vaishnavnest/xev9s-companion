
import pytest

from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import (
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)
from simulator.vehicle.state import (
    ChargingStatus,
    OperatingState,
    VehicleState,
)


@pytest.fixture
def manager() -> ScenarioManager:
    return ScenarioManager(VehicleState(vehicle_id="XEV-001"))


def test_select_parked_scenario(manager: ScenarioManager) -> None:
    state = manager.select_scenario(
        ScenarioType.PARKED_BATTERY_LEVEL,
        ScenarioConfig(initial_battery_percentage=65.0),
    )

    assert state.battery_percentage == 65.0
    assert state.operating_state == OperatingState.PARKED
    assert manager.status == ScenarioStatus.IDLE


def test_select_driving_scenario(manager: ScenarioManager) -> None:
    route = ((8.5241, 76.9366), (8.5580, 76.8810))

    state = manager.select_scenario(
        ScenarioType.DRIVING_ROUTE,
        ScenarioConfig(route=route),
    )

    assert state.operating_state == OperatingState.DRIVING
    assert state.latitude == 8.5241
    assert state.longitude == 76.9366


@pytest.mark.parametrize(
    "scenario",
    [
        ScenarioType.CHARGING_TO_TARGET,
        ScenarioType.CHARGING_INTERRUPTION,
    ],
)
def test_select_charging_scenarios(
    manager: ScenarioManager,
    scenario: ScenarioType,
) -> None:
    state = manager.select_scenario(scenario)

    assert state.operating_state == OperatingState.CHARGING
    assert state.charging_status == ChargingStatus.CHARGING


def test_select_low_battery_scenario(manager: ScenarioManager) -> None:
    state = manager.select_scenario(
        ScenarioType.LOW_BATTERY,
        ScenarioConfig(
            initial_battery_percentage=80.0,
            battery_alert_threshold=20.0,
        ),
    )

    assert state.battery_percentage == 19.0


def test_low_battery_requires_positive_threshold(
    manager: ScenarioManager,
) -> None:
    with pytest.raises(ValueError, match="positive threshold"):
        manager.select_scenario(
            ScenarioType.LOW_BATTERY,
            ScenarioConfig(battery_alert_threshold=0.0),
        )


@pytest.mark.parametrize(
    "scenario",
    [
        ScenarioType.REMOTE_OP_SUCCESS,
        ScenarioType.REMOTE_OP_FAILURE,
    ],
)
def test_select_remote_operation_scenarios(
    manager: ScenarioManager,
    scenario: ScenarioType,
) -> None:
    state = manager.select_scenario(scenario)

    assert state.is_locked is True


def test_start_requires_selected_scenario(
    manager: ScenarioManager,
) -> None:
    with pytest.raises(ValueError, match="No scenario"):
        manager.start()


def test_start_and_stop_scenario(manager: ScenarioManager) -> None:
    manager.select_scenario(ScenarioType.DRIVING_ROUTE)

    manager.start()
    assert manager.status == ScenarioStatus.RUNNING

    manager.stop()

    assert manager.status == ScenarioStatus.STOPPED
    assert manager.state.operating_state == OperatingState.PARKED
    assert manager.state.speed_kph == 0.0


def test_cannot_start_running_scenario(
    manager: ScenarioManager,
) -> None:
    manager.select_scenario(ScenarioType.PARKED_BATTERY_LEVEL)
    manager.start()

    with pytest.raises(ValueError, match="already running"):
        manager.start()


def test_cannot_stop_idle_scenario(manager: ScenarioManager) -> None:
    with pytest.raises(ValueError, match="No scenario"):
        manager.stop()


def test_cannot_select_while_running(manager: ScenarioManager) -> None:
    manager.select_scenario(ScenarioType.PARKED_BATTERY_LEVEL)
    manager.start()

    with pytest.raises(ValueError, match="Stop the running"):
        manager.select_scenario(ScenarioType.DRIVING_ROUTE)


def test_reset_restores_initial_state(manager: ScenarioManager) -> None:
    manager.select_scenario(
        ScenarioType.PARKED_BATTERY_LEVEL,
        ScenarioConfig(initial_battery_percentage=70.0),
    )
    manager.start()

    manager.state.battery_percentage = 30.0
    manager.state.odometer_km = 100.0
    manager.state.is_locked = False

    state = manager.reset()

    assert state.battery_percentage == 70.0
    assert state.odometer_km == 0.0
    assert state.is_locked is True
    assert manager.status == ScenarioStatus.IDLE


def test_reset_does_not_replace_state_object(
    manager: ScenarioManager,
) -> None:
    original_state = manager.state
    manager.select_scenario(ScenarioType.PARKED_BATTERY_LEVEL)
    manager.start()

    manager.reset()

    assert manager.state is original_state


def test_reset_requires_selected_scenario(
    manager: ScenarioManager,
) -> None:
    with pytest.raises(ValueError, match="before resetting"):
        manager.reset()


def test_reset_restores_charging_without_completing_it(
    manager: ScenarioManager,
) -> None:
    manager.select_scenario(ScenarioType.CHARGING_TO_TARGET)
    manager.start()

    manager.state.battery_percentage = 100.0
    manager.reset()

    assert manager.state.operating_state == OperatingState.CHARGING
    assert manager.state.charging_status == ChargingStatus.CHARGING
    assert manager.state.battery_percentage == 80.0
    assert manager.status == ScenarioStatus.IDLE
