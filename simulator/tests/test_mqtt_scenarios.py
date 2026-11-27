import json
from unittest.mock import MagicMock, patch

from simulator import mqtt_main
from simulator.scenarios.models import ScenarioStatus, ScenarioType
from simulator.vehicle.state import OperatingState, VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


def test_create_scenario_executor_prepares_driving_state():
    state = VehicleState(vehicle_id="XEV-001")
    executor = mqtt_main.create_scenario_executor(state, ScenarioType.DRIVING_ROUTE)

    assert executor.state is state
    assert executor.manager.selected_scenario == ScenarioType.DRIVING_ROUTE
    assert state.operating_state == OperatingState.DRIVING
    assert not state.is_locked


def test_create_scenario_executor_prepares_charging_to_target_state():
    state = VehicleState(vehicle_id="XEV-001", battery_percentage=62.0)
    engine = mqtt_main.SimulationEngine(state)
    engine.update_charging_preferences(
        {"target_percentage": 90.0, "stop_charging_at_target": True}
    )
    executor = mqtt_main.create_scenario_executor(
        state, ScenarioType.CHARGING_TO_TARGET, engine=engine
    )

    assert executor.state is state
    assert executor.manager.selected_scenario == ScenarioType.CHARGING_TO_TARGET
    assert executor.manager.config is not None
    assert executor.manager.config.initial_battery_percentage == 62.0
    assert executor.manager.config.charging_target_percentage == 90.0
    assert state.operating_state == OperatingState.CHARGING
    assert state.battery_percentage == 62.0


def test_run_mqtt_simulator_publishes_scenario_telemetry():
    state = VehicleState(vehicle_id="XEV-001")
    client = MagicMock(is_connected=True)
    client.telemetry_topic = "xev9s/vehicles/XEV-001/telemetry"

    with (
        patch.object(
            mqtt_main,
            "create_mqtt_simulator",
            return_value=(state, VehicleStateManager(state), MagicMock(), client),
        ),
        patch.object(mqtt_main.time, "sleep", side_effect=KeyboardInterrupt),
    ):
        mqtt_main.run_mqtt_simulator("XEV-001", 5.0, ScenarioType.DRIVING_ROUTE)

    published = json.loads(client.publish.call_args.args[1])
    assert published["operating_state"] == "driving"
    assert published["speed_kph"] > 0
    assert published["odometer_km"] > 0
    client.disconnect.assert_called_once()


def test_driving_route_continues_beyond_short_distance_with_real_coords():
    state = VehicleState(
        vehicle_id="XEV-001",
        latitude=12.9716,
        longitude=77.5946,
    )
    executor = mqtt_main.create_scenario_executor(state, ScenarioType.DRIVING_ROUTE)
    executor.start()

    initial_battery = state.battery_percentage
    positions: list[tuple[float, float]] = []

    for _ in range(30):
        update = executor.advance(30.0)
        assert update.status == ScenarioStatus.RUNNING
        assert -90 <= state.latitude <= 90
        assert -180 <= state.longitude <= 180
        positions.append((state.latitude, state.longitude))

    assert state.odometer_km > 10.0
    assert state.battery_percentage < initial_battery
    assert len(set(positions)) > 1
    assert update.telemetry["latitude"] == state.latitude
    assert update.telemetry["longitude"] == state.longitude
    assert update.telemetry["battery_percentage"] == state.battery_percentage


def test_driving_route_respects_custom_starting_coordinates():
    state = VehicleState(
        vehicle_id="XEV-002",
        latitude=13.0827,
        longitude=80.2707,
    )
    executor = mqtt_main.create_scenario_executor(state, ScenarioType.DRIVING_ROUTE)

    assert state.latitude == 13.0827
    assert state.longitude == 80.2707
    assert executor.manager.config is not None
    assert executor.manager.config.route[0] == (13.0827, 80.2707)


def test_completed_journey_remains_finite():
    state = VehicleState(
        vehicle_id="XEV-003",
        latitude=12.9716,
        longitude=77.5946,
    )
    executor = mqtt_main.create_scenario_executor(state, ScenarioType.COMPLETED_JOURNEY)
    executor.start()

    update = executor.advance(300.0)

    assert update.status == ScenarioStatus.COMPLETED
    assert update.telemetry["operating_state"] == "parked"
    assert any(event.event_type == "JOURNEY_COMPLETED" for event in update.events)


def test_driving_route_battery_depletion_stops_safely():
    state = VehicleState(
        vehicle_id="XEV-004",
        latitude=12.9716,
        longitude=77.5946,
    )
    executor = mqtt_main.create_scenario_executor(state, ScenarioType.DRIVING_ROUTE)
    executor.start()
    state.battery_percentage = 0.5

    update = executor.advance(600.0)

    assert update.status == ScenarioStatus.COMPLETED
    assert state.battery_percentage == 0.0
    assert state.operating_state == OperatingState.PARKED
    assert state.speed_kph == 0.0
    assert update.telemetry["battery_percentage"] == 0.0
    assert any(
        event.event_type == "JOURNEY_ENDED"
        and event.details.get("reason") == "BATTERY_DEPLETED"
        for event in update.events
    )
