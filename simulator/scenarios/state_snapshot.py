
from copy import deepcopy
from dataclasses import fields

from simulator.vehicle.state import VehicleState


def copy_vehicle_state(state: VehicleState) -> VehicleState:
    """Create an independent vehicle-state copy."""

    values = {
        item.name: deepcopy(getattr(state, item.name))
        for item in fields(VehicleState)
    }
    return VehicleState(**values)


def restore_vehicle_state(
    target: VehicleState,
    source: VehicleState,
) -> None:
    """Restore state without replacing the target object."""

    for item in fields(VehicleState):
        setattr(
            target,
            item.name,
            deepcopy(getattr(source, item.name)),
        )
