import json
from unittest.mock import MagicMock, patch

import pytest
from simulator import mqtt_cli, mqtt_main
from simulator.scenarios.models import ScenarioStatus, ScenarioType
from simulator.vehicle.charging_tracker import ChargingEventTracker
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import ChargingStatus, OperatingState, VehicleState


@pytest.mark.parametrize(
    ("initial_battery", "target"),
    [
        (35.0, 80.0),
        (62.0, 90.0),
        (85.0, 95.0),
    ],
)
def test_dynamic_starting_battery_and_target_completion(
    initial_battery: float,
    target: float,
) -> None:
    state = VehicleState(vehicle_id="XEV-001", battery_percentage=initial_battery)
    engine = SimulationEngine(state)
    engine.update_charging_preferences(
        {"target_percentage": target, "stop_charging_at_target": True}
    )

    executor = mqtt_cli.create_scenario_executor(
        state, ScenarioType.CHARGING_TO_TARGET, engine=engine
    )
    assert state.battery_percentage == initial_battery
    assert executor.manager.config is not None
    assert executor.manager.config.initial_battery_percentage == initial_battery
    assert executor.manager.config.charging_target_percentage == target

    executor.start()
    assert state.battery_percentage == initial_battery
    assert state.operating_state == OperatingState.CHARGING

    for _ in range(100):
        if executor.manager.status != ScenarioStatus.RUNNING:
            break
        executor.advance(360.0)

    assert state.battery_percentage == target
    assert state.charging_status == ChargingStatus.DISCONNECTED
    assert state.charging_power_kw == 0
    assert state.operating_state == OperatingState.PARKED
    assert executor.manager.status == ScenarioStatus.COMPLETED


@pytest.mark.parametrize(
    ("initial_battery", "target"),
    [
        (90.0, 90.0),
        (95.0, 90.0),
    ],
)
def test_target_already_reached_does_not_start_charging(
    initial_battery: float,
    target: float,
) -> None:
    state = VehicleState(vehicle_id="XEV-001", battery_percentage=initial_battery)
    engine = SimulationEngine(state)
    engine.update_charging_preferences(
        {"target_percentage": target, "stop_charging_at_target": True}
    )
    tracker = ChargingEventTracker()

    executor = mqtt_cli.create_scenario_executor(
        state, ScenarioType.CHARGING_TO_TARGET, engine=engine
    )
    update = executor.start()
    events = tracker.evaluate(state, engine)

    assert events == []
    assert update.status == ScenarioStatus.COMPLETED
    assert state.battery_percentage == initial_battery
    assert state.charging_status == ChargingStatus.DISCONNECTED
    assert state.charging_power_kw == 0
    assert state.operating_state == OperatingState.PARKED
    assert executor.manager.status == ScenarioStatus.COMPLETED


@pytest.mark.parametrize("bad_value", [-1.0, 101.0, float("nan"), True])
def test_invalid_battery_or_target_raises_value_error(bad_value: object) -> None:
    state = VehicleState(vehicle_id="XEV-001", battery_percentage=50.0)
    engine = SimulationEngine(state)
    engine.target_percentage = bad_value  # type: ignore[assignment]

    with pytest.raises(ValueError, match="between 0 and 100"):
        mqtt_cli.create_scenario_executor(
            state, ScenarioType.CHARGING_TO_TARGET, engine=engine
        )


def test_mqtt_simulator_charging_to_target_publishes_final_state_and_event() -> None:
    state = VehicleState(vehicle_id="XEV-001", battery_percentage=85.0)
    engine = SimulationEngine(state)
    engine.update_charging_preferences(
        {"target_percentage": 95.0, "stop_charging_at_target": True}
    )
    client = MagicMock()
    client.is_connected = True
    client.telemetry_topic = "xev9s/vehicles/XEV-001/telemetry"
    client.charging_events_topic = "xev9s/vehicles/XEV-001/charging/events"
    handler = MagicMock(simulation_engine=engine)
    components = (state, MagicMock(), handler, client)

    with (
        patch.object(mqtt_main, "create_mqtt_simulator", return_value=components),
        patch.object(
            mqtt_main.time,
            "sleep",
            side_effect=[None, None, KeyboardInterrupt],
        ),
    ):
        mqtt_main.run_mqtt_simulator(
            "XEV-001",
            telemetry_interval=1800.0,
            scenario=ScenarioType.CHARGING_TO_TARGET,
        )

    telemetry_msgs = [
        json.loads(call.args[1])
        for call in client.publish.call_args_list
        if call.args[0] == client.telemetry_topic
    ]
    event_msgs = [
        json.loads(call.args[1])
        for call in client.publish.call_args_list
        if call.args[0] == client.charging_events_topic
    ]

    assert len(telemetry_msgs) == 3
    assert telemetry_msgs[0]["operating_state"] == "charging"
    assert telemetry_msgs[0]["battery_percentage"] > 85.0

    for final_msg in telemetry_msgs[1:]:
        assert final_msg["battery_percentage"] == 95.0
        assert final_msg["charging_status"] == "disconnected"
        assert final_msg["charging_power_kw"] == 0
        assert final_msg["operating_state"] == "parked"

    assert [e["event_type"] for e in event_msgs] == [
        "charging_started",
        "charging_progress",
        "completed",
    ]
    assert event_msgs[-1]["target_percentage"] == 95.0
    assert event_msgs[-1]["battery_percentage"] == 95.0


def test_dynamic_preference_update_during_charging_updates_target() -> None:
    state = VehicleState(vehicle_id="XEV-001", battery_percentage=50.0)
    engine = SimulationEngine(state)
    engine.update_charging_preferences(
        {"target_percentage": 80.0, "stop_charging_at_target": True}
    )
    executor = mqtt_cli.create_scenario_executor(
        state, ScenarioType.CHARGING_TO_TARGET, engine=engine
    )
    executor.start()

    engine.update_charging_preferences({"target_percentage": 60.0})
    executor.advance(3600.0)

    assert state.battery_percentage == 60.0
    assert state.charging_status == ChargingStatus.DISCONNECTED
    assert state.charging_power_kw == 0
    assert state.operating_state == OperatingState.PARKED
    assert executor.manager.status == ScenarioStatus.COMPLETED
