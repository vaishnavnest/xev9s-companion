
import pytest
from simulator.scenarios.manager import ScenarioManager
from simulator.scenarios.models import RemoteOperation, ScenarioConfig, ScenarioType
from simulator.vehicle.state import VehicleState


def create_manager() -> ScenarioManager:
    return ScenarioManager(VehicleState(vehicle_id="XEV-TEST-001"))


def test_lock_state_defaults_to_scenario_behavior() -> None:
    manager = create_manager()

    manager.select_scenario(ScenarioType.DRIVING_ROUTE)

    assert manager.state.is_locked is False


def test_explicit_lock_state_overrides_scenario_default() -> None:
    manager = create_manager()
    config = ScenarioConfig(initial_lock_state=True)

    manager.select_scenario(ScenarioType.DRIVING_ROUTE, config)

    assert manager.state.is_locked is True


def test_explicit_unlock_overrides_remote_scenario_default() -> None:
    manager = create_manager()
    config = ScenarioConfig(initial_lock_state=False)

    manager.select_scenario(ScenarioType.REMOTE_OP_SUCCESS, config)

    assert manager.state.is_locked is False


@pytest.mark.parametrize("value", [0, 1, "true"])
def test_invalid_lock_state_is_rejected(value: object) -> None:
    with pytest.raises(TypeError):
        ScenarioConfig(initial_lock_state=value)


@pytest.mark.parametrize("duration", [0, -1, float("nan"), float("inf")])
def test_invalid_offline_duration_is_rejected(duration: float) -> None:
    with pytest.raises(ValueError):
        ScenarioConfig(offline_duration_seconds=duration)


def test_positive_offline_duration_is_accepted() -> None:
    config = ScenarioConfig(offline_duration_seconds=30)

    assert config.offline_duration_seconds == 30

def test_scenario_config_accepts_valid_remote_operation():
    config = ScenarioConfig(
        remote_operation=RemoteOperation.UNLOCK
    )

    assert config.remote_operation == RemoteOperation.UNLOCK


def test_scenario_config_rejects_invalid_remote_operation():
    with pytest.raises(
        TypeError,
        match="remote_operation must be a RemoteOperation or None",
    ):
        ScenarioConfig(remote_operation="UNLOCK")