
import pytest
from simulator.vehicle.state import ChargingStatus, OperatingState, VehicleState
from simulator.vehicle.state_manager import VehicleStateManager


@pytest.fixture
def manager() -> VehicleStateManager:
    return VehicleStateManager(VehicleState(vehicle_id="XEV-001"))


@pytest.mark.parametrize(
    ("operation", "expected_state", "expected_charging"),
    [
        ("start_driving", OperatingState.DRIVING, ChargingStatus.DISCONNECTED),
        ("start_charging", OperatingState.CHARGING, ChargingStatus.CHARGING),
    ],
)
def test_start_operations(
    manager: VehicleStateManager,
    operation: str,
    expected_state: OperatingState,
    expected_charging: ChargingStatus,
) -> None:
    state = getattr(manager, operation)()
    assert state.operating_state == expected_state
    assert state.charging_status == expected_charging


def test_stop_driving(manager: VehicleStateManager) -> None:
    manager.start_driving()
    manager.state.speed_kph = 45.0
    state = manager.stop_driving()

    assert state.operating_state == OperatingState.PARKED
    assert state.speed_kph == 0.0


def test_stop_charging(manager: VehicleStateManager) -> None:
    manager.start_charging()
    manager.state.charging_power_kw = 7.0
    state = manager.stop_charging()

    assert state.operating_state == OperatingState.PARKED
    assert state.charging_status == ChargingStatus.DISCONNECTED
    assert state.charging_power_kw == 0.0


def test_interrupt_charging(manager: VehicleStateManager) -> None:
    manager.start_charging()
    state = manager.interrupt_charging()

    assert state.operating_state == OperatingState.INTERRUPTED
    assert state.charging_status == ChargingStatus.INTERRUPTED
    assert state.charging_power_kw == 0.0


@pytest.mark.parametrize(
    ("operation", "expected"),
    [
        ("lock_vehicle", True),
        ("unlock_vehicle", False),
    ],
)
def test_lock_operations(
    manager: VehicleStateManager, operation: str, expected: bool
) -> None:
    if operation == "lock_vehicle":
        manager.unlock_vehicle()

    assert getattr(manager, operation)().is_locked is expected


@pytest.mark.parametrize(
    ("operation", "expected"),
    [
        ("start_cabin_preconditioning", True),
        ("stop_cabin_preconditioning", False),
    ],
)
def test_cabin_operations(
    manager: VehicleStateManager, operation: str, expected: bool
) -> None:
    if operation == "stop_cabin_preconditioning":
        manager.start_cabin_preconditioning()

    assert (
        getattr(manager, operation)().cabin_preconditioning_active is expected
    )


@pytest.mark.parametrize(
    ("operation", "message"),
    [
        ("stop_driving", "requires vehicle to be driving"),
        ("stop_charging", "requires vehicle to be charging"),
        ("interrupt_charging", "requires vehicle to be charging"),
        ("lock_vehicle", "already locked"),
        ("stop_cabin_preconditioning", "not active"),
    ],
)
def test_invalid_operations(
    manager: VehicleStateManager, operation: str, message: str
) -> None:
    with pytest.raises(ValueError, match=message):
        getattr(manager, operation)()


def test_cannot_drive_while_connected() -> None:
    state = VehicleState(
        vehicle_id="XEV-002",
        charging_status=ChargingStatus.CONNECTED,
    )

    with pytest.raises(ValueError, match="disconnected from the charger"):
        VehicleStateManager(state).start_driving()


def test_cannot_charge_while_driving(manager: VehicleStateManager) -> None:
    manager.start_driving()

    with pytest.raises(ValueError, match="requires vehicle to be parked"):
        manager.start_charging()


def test_cannot_restart_interrupted_charging(
    manager: VehicleStateManager,
) -> None:
    manager.start_charging()
    manager.interrupt_charging()

    with pytest.raises(
        ValueError, match="requires vehicle to be parked"
    ):
        manager.start_charging()


def test_cannot_unlock_already_unlocked(manager: VehicleStateManager) -> None:
    manager.unlock_vehicle()

    with pytest.raises(ValueError, match="already unlocked"):
        manager.unlock_vehicle()


def test_cannot_restart_active_cabin(manager: VehicleStateManager) -> None:
    manager.start_cabin_preconditioning()

    with pytest.raises(ValueError, match="already active"):
        manager.start_cabin_preconditioning()


def test_connected_vehicle_can_start_charging() -> None:
    state = VehicleState(
        vehicle_id="XEV-003",
        charging_status=ChargingStatus.CONNECTED,
    )

    result = VehicleStateManager(state).start_charging()

    assert result.operating_state == OperatingState.CHARGING


def test_successful_transition_updates_timestamp(
    manager: VehicleStateManager,
) -> None:
    previous = manager.state.updated_at
    result = manager.unlock_vehicle()

    assert result.updated_at >= previous
    assert result.updated_at.tzinfo is not None


def test_failed_transition_preserves_timestamp(
    manager: VehicleStateManager,
) -> None:
    previous = manager.state.updated_at

    with pytest.raises(ValueError):
        manager.stop_driving()

    assert manager.state.updated_at == previous
