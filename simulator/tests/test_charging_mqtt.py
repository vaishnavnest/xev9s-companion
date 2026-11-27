import json
from unittest.mock import MagicMock

from backend.app.schemas.charging_event import ChargingEvent
from simulator import mqtt_main
from simulator.vehicle.simulation_engine import SimulationEngine
from simulator.vehicle.state import ChargingStatus, OperatingState, VehicleState


def test_handle_mqtt_command_routes_charging_preferences():
    state = VehicleState(vehicle_id="XEV-001")
    engine = SimulationEngine(state)
    handler = MagicMock()
    client = MagicMock()
    client.command_topic = "xev9s/vehicles/XEV-001/commands"
    client.charging_preferences_topic = (
        "xev9s/vehicles/XEV-001/charging/preferences"
    )

    payload = json.dumps(
        {
            "vehicle_id": "XEV-001",
            "target_percentage": 85.0,
            "stop_charging_at_target": True,
            "schedule_enabled": False,
        }
    ).encode("utf-8")

    mqtt_main.handle_mqtt_command(
        client.charging_preferences_topic,
        payload,
        handler,
        client,
        engine=engine,
    )

    handler.handle_message.assert_not_called()
    assert engine.target_percentage == 85.0
    assert engine.stop_charging_at_target is True


def test_charging_event_tracker_emits_lifecycle_events():
    state = VehicleState(
        vehicle_id="XEV-001",
        battery_percentage=75.0,
        operating_state=OperatingState.CHARGING,
        charging_status=ChargingStatus.CHARGING,
        charging_power_kw=7.2,
    )
    engine = SimulationEngine(state)
    engine.target_percentage = 80.0
    tracker = mqtt_main.ChargingEventTracker()

    # 1. Start charging
    events = tracker.evaluate(state, engine)
    assert len(events) == 1
    assert events[0]["event_type"] == "charging_started"
    session_id = events[0]["session_id"]
    assert session_id is not None
    ChargingEvent.model_validate(events[0])

    # 2. Progress
    state.battery_percentage = 77.0
    events = tracker.evaluate(state, engine)
    assert len(events) == 1
    assert events[0]["event_type"] == "charging_progress"
    assert events[0]["session_id"] == session_id
    ChargingEvent.model_validate(events[0])

    # 3. Interrupt
    state.operating_state = OperatingState.INTERRUPTED
    state.charging_status = ChargingStatus.INTERRUPTED
    state.charging_power_kw = 0.0
    events = tracker.evaluate(state, engine)
    assert len(events) == 1
    assert events[0]["event_type"] == "interrupted"
    assert events[0]["session_id"] == session_id
    assert events[0]["interruption_reason"] is not None
    ChargingEvent.model_validate(events[0])

    # 4. Resume
    state.operating_state = OperatingState.CHARGING
    state.charging_status = ChargingStatus.CHARGING
    state.charging_power_kw = 7.2
    events = tracker.evaluate(state, engine)
    assert len(events) == 1
    assert events[0]["event_type"] == "resumed"
    assert events[0]["session_id"] == session_id
    ChargingEvent.model_validate(events[0])

    # 5. Complete at target
    state.battery_percentage = 80.0
    state.operating_state = OperatingState.PARKED
    state.charging_status = ChargingStatus.DISCONNECTED
    state.charging_power_kw = 0.0
    events = tracker.evaluate(state, engine)
    assert len(events) == 1
    assert events[0]["event_type"] == "completed"
    assert events[0]["session_id"] == session_id
    ChargingEvent.model_validate(events[0])
    assert tracker.active_session_id is None
