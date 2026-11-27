
import pytest
from simulator.scenarios.route import (
    advance_route,
    calculate_distance,
)

ROUTE = (
    (8.5241, 76.9366),
    (8.5300, 76.9400),
    (8.5350, 76.9450),
)


def test_distance_between_identical_coordinates_is_zero() -> None:
    assert calculate_distance(ROUTE[0], ROUTE[0]) == 0


def test_distance_between_coordinates_is_positive() -> None:
    assert calculate_distance(ROUTE[0], ROUTE[1]) > 0


def test_zero_distance_preserves_start_position() -> None:
    progress = advance_route(ROUTE, 0, 0)

    assert progress.latitude == ROUTE[0][0]
    assert progress.longitude == ROUTE[0][1]
    assert progress.completed is False


def test_partial_distance_advances_position() -> None:
    segment_distance = calculate_distance(ROUTE[0], ROUTE[1])

    progress = advance_route(ROUTE, 0, segment_distance / 2)

    assert progress.latitude > ROUTE[0][0]
    assert progress.longitude > ROUTE[0][1]
    assert progress.completed is False


def test_distance_beyond_route_finishes_at_destination() -> None:
    progress = advance_route(ROUTE, 0, 100)

    assert progress.latitude == ROUTE[-1][0]
    assert progress.longitude == ROUTE[-1][1]
    assert progress.completed is True


@pytest.mark.parametrize("distance", [-1, float("nan"), float("inf")])
def test_invalid_distance_is_rejected(distance: float) -> None:
    with pytest.raises(ValueError):
        advance_route(ROUTE, 0, distance)


def test_invalid_route_is_rejected() -> None:
    with pytest.raises(ValueError):
        advance_route(((8.5241, 76.9366),), 0, 1)
