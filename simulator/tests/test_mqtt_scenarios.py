import json
from unittest.mock import MagicMock, patch

from simulator import mqtt_main
from simulator.scenarios.models import ScenarioType
from simulator.vehicle.state import OperatingState, VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


def test_create_scenario_executor_prepares_driving_state():
    state = VehicleState(vehicle_id="XEV-001")
    executor = mqtt_main.create_scenario_executor(
        state, ScenarioType.DRIVING_ROUTE
    )

    assert executor.state is state
    assert executor.manager.selected_scenario == ScenarioType.DRIVING_ROUTE
    assert state.operating_state == OperatingState.DRIVING
    assert not state.is_locked


def test_create_scenario_executor_prepares_charging_to_target_state():
    state = VehicleState(vehicle_id="XEV-001")
    executor = mqtt_main.create_scenario_executor(
        state, ScenarioType.CHARGING_TO_TARGET
    )

    assert executor.state is state
    assert executor.manager.selected_scenario == ScenarioType.CHARGING_TO_TARGET
    assert executor.manager.config is not None
    assert executor.manager.config.initial_battery_percentage == 50.0
    assert executor.manager.config.charging_target_percentage == 90.0
    assert state.operating_state == OperatingState.CHARGING
    assert state.battery_percentage == 50.0


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
        mqtt_main.run_mqtt_simulator(
            "XEV-001", 5.0, ScenarioType.DRIVING_ROUTE
        )

    published = json.loads(client.publish.call_args.args[1])
    assert published["operating_state"] == "driving"
    assert published["speed_kph"] > 0
    assert published["odometer_km"] > 0
    client.disconnect.assert_called_once()
