
from types import SimpleNamespace
from unittest.mock import Mock

import pytest
import simulator.main as simulator_main
from simulator.main import (
    build_parser,
    build_scenario_config,
    create_simulator,
    display_update,
    main,
    run_scenario,
)
from simulator.scenarios.models import (
    ScenarioConfig,
    ScenarioStatus,
    ScenarioType,
)


@pytest.mark.parametrize("scenario", [
    ScenarioType.PARKED_BATTERY_LEVEL,
    ScenarioType.LOW_BATTERY,
])
def test_static_scenarios(scenario, monkeypatch):
    update = SimpleNamespace(status=ScenarioStatus.RUNNING)
    executor = Mock()
    executor.start.return_value = update
    display = Mock()
    monkeypatch.setattr(simulator_main, "display_update", display)

    run_scenario(executor, scenario, 10, 30)

    executor.start.assert_called_once()
    executor.advance.assert_not_called()
    executor.stop.assert_not_called()
    display.assert_called_once_with(update)


def test_dynamic_scenario_completes(monkeypatch):
    running = SimpleNamespace(status=ScenarioStatus.RUNNING)
    completed = SimpleNamespace(status=ScenarioStatus.COMPLETED)
    executor = Mock()
    executor.start.return_value = running
    executor.advance.return_value = completed
    display = Mock()
    monkeypatch.setattr(simulator_main, "display_update", display)

    run_scenario(executor, ScenarioType.DRIVING_ROUTE, 10, 30)

    executor.advance.assert_called_once_with(10)
    executor.stop.assert_not_called()
    assert display.call_count == 2


def test_scenario_stops_at_max_steps(monkeypatch, caplog):
    running = SimpleNamespace(status=ScenarioStatus.RUNNING)
    executor = Mock()
    executor.start.return_value = running
    executor.advance.return_value = running
    monkeypatch.setattr(simulator_main, "display_update", Mock())

    run_scenario(executor, ScenarioType.DRIVING_ROUTE, 10, 2)

    assert executor.advance.call_count == 2
    executor.stop.assert_called_once()
    assert "did not complete within 2 steps" in caplog.text


@pytest.mark.parametrize("events", [
    [],
    [SimpleNamespace(
        event_type="JOURNEY_COMPLETED",
        details={"distance_km": 5},
    )],
])
def test_display_update(events, capsys):
    update = SimpleNamespace(
        status=ScenarioStatus.COMPLETED,
        connectivity=SimpleNamespace(value="ONLINE"),
        telemetry={"vehicle_id": "XEV-001"},
        events=events,
    )

    display_update(update)
    output = capsys.readouterr().out

    assert "Scenario status: completed" in output
    assert "XEV-001" in output
    assert ("Scenario events:" in output) == bool(events)


def test_parser_defaults_and_invalid_scenario():
    args = build_parser().parse_args(["--scenario", "DRIVING_ROUTE"])
    assert (args.vehicle_id, args.time_step, args.max_steps) == (
        "XEV-001", 10.0, 30
    )

    with pytest.raises(SystemExit):
        build_parser().parse_args(["--scenario", "UNKNOWN"])


@pytest.mark.parametrize(("scenario", "expected"), [
    (ScenarioType.DRIVING_ROUTE, {"route": ((0.0, 0.0), (0.0, 0.01))}),
    (ScenarioType.COMPLETED_JOURNEY, {"route": ((0.0, 0.0), (0.0, 0.01))}),
    (ScenarioType.CHARGING_TO_TARGET, {
        "initial_battery_percentage": 50.0,
        "charging_target_percentage": 60.0,
    }),
    (ScenarioType.CONNECTIVITY_LOSS_RESTORE, {
        "offline_duration_seconds": 20,
    }),
])
def test_special_scenario_configs(scenario, expected):
    config = build_scenario_config(scenario)
    assert all(getattr(config, key) == value for key, value in expected.items())


@pytest.mark.parametrize("scenario", [
    ScenarioType.PARKED_BATTERY_LEVEL,
    ScenarioType.CHARGING_INTERRUPTION,
    ScenarioType.REMOTE_OP_SUCCESS,
    ScenarioType.REMOTE_OP_FAILURE,
    ScenarioType.LOW_BATTERY,
])
def test_default_scenario_configs(scenario):
    assert build_scenario_config(scenario) == ScenarioConfig()


def test_create_simulator():
    executor = create_simulator(
        "XEV-TEST",
        ScenarioType.PARKED_BATTERY_LEVEL,
        ScenarioConfig(),
    )
    assert executor.start().telemetry["vehicle_id"] == "XEV-TEST"


def test_main_runs_scenario(monkeypatch, capsys):
    create = Mock(return_value=Mock())
    run = Mock()
    monkeypatch.setattr(simulator_main, "create_simulator", create)
    monkeypatch.setattr(simulator_main, "run_scenario", run)

    assert main(["--scenario", "DRIVING_ROUTE"]) == 0
    create.assert_called_once()
    run.assert_called_once()
    assert "Starting XEV 9S simulator" in capsys.readouterr().out


@pytest.mark.parametrize("value", ["0", "-1", "nan", "inf", "-inf"])
def test_main_rejects_invalid_time_step(value):
    with pytest.raises(SystemExit):
        main(["--scenario", "DRIVING_ROUTE", "--time-step", value])


def test_main_rejects_invalid_max_steps():
    with pytest.raises(SystemExit):
        main(["--scenario", "DRIVING_ROUTE", "--max-steps", "0"])
