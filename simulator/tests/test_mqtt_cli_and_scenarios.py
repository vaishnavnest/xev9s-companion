import json
from unittest.mock import MagicMock, patch

import pytest

from simulator import mqtt_cli, mqtt_main
from simulator.scenarios.models import ScenarioType
from simulator.vehicle.charging_tracker import ChargingEventTracker
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import VehicleState


def test_parse_args_uses_env_vars_and_allows_cli_override(monkeypatch):
    monkeypatch.setenv("VEHICLE_ID", "XEV-DEMO-001")
    monkeypatch.setenv("TELEMETRY_INTERVAL", "2.5")

    args = mqtt_cli.parse_mqtt_args([])
    assert args.vehicle_id == "XEV-DEMO-001"
    assert args.telemetry_interval == 2.5

    overridden = mqtt_cli.parse_mqtt_args(
        ["--vehicle-id", "XEV-999", "--telemetry-interval", "1.0"]
    )
    assert overridden.vehicle_id == "XEV-999"
    assert overridden.telemetry_interval == 1.0


@pytest.mark.parametrize("bad_interval", ["0", "-5", "nan", "inf", "abc"])
def test_parse_args_rejects_invalid_env_interval(monkeypatch, bad_interval):
    monkeypatch.setenv("TELEMETRY_INTERVAL", bad_interval)
    with pytest.raises(SystemExit):
        mqtt_cli.parse_mqtt_args([])


@pytest.mark.parametrize("bad_id", ["", "   ", "XEV/1", "XEV+1", "XEV#1"])
def test_parse_args_rejects_invalid_env_vehicle_id(monkeypatch, bad_id):
    monkeypatch.setenv("VEHICLE_ID", bad_id)
    with pytest.raises(SystemExit):
        mqtt_cli.parse_mqtt_args([])


def test_charging_to_target_syncs_engine_and_emits_completed():
    state = VehicleState(vehicle_id="XEV-001", battery_percentage=62.0)
    engine = SimulationEngine(state)
    engine.update_charging_preferences(
        {"target_percentage": 90.0, "stop_charging_at_target": True}
    )
    executor = mqtt_cli.create_scenario_executor(
        state, ScenarioType.CHARGING_TO_TARGET, engine=engine
    )
    assert engine.target_percentage == 90.0
    assert state.battery_percentage == 62.0

    tracker = ChargingEventTracker()
    executor.start()
    events = tracker.evaluate(state, engine)
    assert [e["event_type"] for e in events] == ["charging_started"]

    emitted = []
    for _ in range(50):
        if executor.manager.status.value != "running":
            break
        executor.advance(360.0)
        emitted.extend(tracker.evaluate(state, engine))

    assert emitted[-1]["event_type"] == "completed"
    assert emitted[-1]["target_percentage"] == 90.0
    assert state.battery_percentage == 90.0


def test_charging_interruption_emits_started_then_interrupted():
    client = MagicMock()
    client.is_connected = True
    client.telemetry_topic = "xev9s/vehicles/XEV-001/telemetry"
    client.charging_events_topic = "xev9s/vehicles/XEV-001/charging/events"
    state = VehicleState(vehicle_id="XEV-001")
    engine = SimulationEngine(state)
    handler = MagicMock(simulation_engine=engine)
    components = (state, MagicMock(), handler, client)

    with (
        patch.object(mqtt_main, "create_mqtt_simulator", return_value=components),
        patch.object(mqtt_main.time, "sleep", side_effect=KeyboardInterrupt),
    ):
        mqtt_main.run_mqtt_simulator(
            "XEV-001",
            telemetry_interval=5.0,
            scenario=ScenarioType.CHARGING_INTERRUPTION,
        )

    event_calls = [
        json.loads(call.args[1])["event_type"]
        for call in client.publish.call_args_list
        if call.args[0] == client.charging_events_topic
    ]
    assert event_calls == ["charging_started", "interrupted"]


def test_connectivity_loss_restore_suppresses_telemetry_while_offline():
    client = MagicMock()
    client.is_connected = True
    client.telemetry_topic = "xev9s/vehicles/XEV-001/telemetry"
    client.charging_events_topic = "xev9s/vehicles/XEV-001/charging/events"
    state = VehicleState(vehicle_id="XEV-001")
    engine = SimulationEngine(state)
    handler = MagicMock(simulation_engine=engine)
    components = (state, MagicMock(), handler, client)

    # offline_duration_seconds defaults to None in mqtt_cli for CONNECTIVITY_LOSS_RESTORE?
    # Inject a 10s offline scenario executor directly via create_scenario_executor mock.
    from simulator.scenarios.executor import ScenarioExecutor
    from simulator.scenarios.manager import ScenarioManager
    from simulator.scenarios.models import ScenarioConfig

    mgr = ScenarioManager(state)
    mgr.select_scenario(
        ScenarioType.CONNECTIVITY_LOSS_RESTORE,
        ScenarioConfig(offline_duration_seconds=10),
    )
    executor = ScenarioExecutor(mgr, engine)

    with (
        patch.object(mqtt_main, "create_mqtt_simulator", return_value=components),
        patch.object(mqtt_main, "create_scenario_executor", return_value=executor),
        patch.object(
            mqtt_main.time,
            "sleep",
            side_effect=[None, KeyboardInterrupt],
        ),
    ):
        mqtt_main.run_mqtt_simulator(
            "XEV-001",
            telemetry_interval=5.0,
            scenario=ScenarioType.CONNECTIVITY_LOSS_RESTORE,
        )

    telemetry_publishes = [
        call
        for call in client.publish.call_args_list
        if call.args[0] == client.telemetry_topic
    ]
    # Loop 1 (t=5s): OFFLINE -> suppressed. Loop 2 (t=10s): ONLINE -> published once.
    assert len(telemetry_publishes) == 1
