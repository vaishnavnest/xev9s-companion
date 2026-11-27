
import pytest
from simulator.scenarios.models import (
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)


def test_all_nine_api_scenarios_are_defined() -> None:
    assert len(ScenarioType) == 9


def test_scenario_status_values() -> None:
    assert ScenarioStatus.IDLE.value == "idle"
    assert ScenarioStatus.RUNNING.value == "running"
    assert ScenarioStatus.STOPPED.value == "stopped"
    assert ScenarioStatus.COMPLETED.value == "completed"


def test_default_scenario_configuration() -> None:
    config = ScenarioConfig()

    assert config.initial_battery_percentage == 80.0
    assert config.charging_target_percentage == 80.0
    assert config.battery_alert_threshold == 20.0
    assert config.route == ()


@pytest.mark.parametrize(
    "value",
    [-1.0, 100.1, float("nan"), float("inf")],
)
def test_rejects_invalid_battery_percentage(value: float) -> None:
    with pytest.raises(ValueError):
        ScenarioConfig(initial_battery_percentage=value)


@pytest.mark.parametrize(
    "value",
    [-1.0, 100.1, float("nan")],
)
def test_rejects_invalid_charging_target(value: float) -> None:
    with pytest.raises(ValueError):
        ScenarioConfig(charging_target_percentage=value)


@pytest.mark.parametrize(
    "value",
    [-1.0, 100.1, float("inf")],
)
def test_rejects_invalid_alert_threshold(value: float) -> None:
    with pytest.raises(ValueError):
        ScenarioConfig(battery_alert_threshold=value)


def test_accepts_valid_route() -> None:
    config = ScenarioConfig(
        route=((8.5241, 76.9366), (8.5580, 76.8810)),
    )

    assert len(config.route) == 2


def test_rejects_route_with_one_coordinate() -> None:
    with pytest.raises(ValueError, match="at least two"):
        ScenarioConfig(route=((8.5241, 76.9366),))


@pytest.mark.parametrize(
    "route",
    [
        ((91.0, 76.0), (8.0, 76.0)),
        ((8.0, 181.0), (8.0, 76.0)),
        ((float("nan"), 76.0), (8.0, 76.0)),
    ],
)
def test_rejects_invalid_route(route: tuple) -> None:
    with pytest.raises(ValueError):
        ScenarioConfig(route=route)
