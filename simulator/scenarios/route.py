from dataclasses import dataclass
from math import asin, cos, isfinite, radians, sin, sqrt

Coordinate = tuple[float, float]

EARTH_RADIUS_KM = 6371.0088


@dataclass(frozen=True, slots=True)
class RouteProgress:
    """Vehicle position and progress along a predefined route."""

    latitude: float
    longitude: float
    segment_index: int
    completed: bool


def calculate_distance(start: Coordinate, end: Coordinate) -> float:
    """Calculate the distance between two GPS coordinates in kilometres."""

    latitude_1, longitude_1 = map(radians, start)
    latitude_2, longitude_2 = map(radians, end)

    latitude_delta = latitude_2 - latitude_1
    longitude_delta = longitude_2 - longitude_1

    haversine = (
        sin(latitude_delta / 2) ** 2
        + cos(latitude_1) * cos(latitude_2) * sin(longitude_delta / 2) ** 2
    )

    return 2 * EARTH_RADIUS_KM * asin(sqrt(haversine))


def advance_route(
    route: tuple[Coordinate, ...],
    segment_index: int,
    distance_km: float,
) -> RouteProgress:
    """Advance a vehicle along a route by a specified distance."""

    if len(route) < 2:
        raise ValueError("A route must contain at least two coordinates")

    if not 0 <= segment_index < len(route) - 1:
        raise ValueError("Invalid route segment index")

    if not isfinite(distance_km) or distance_km < 0:
        raise ValueError("Distance must be finite and non-negative")

    remaining = distance_km
    index = segment_index

    while index < len(route) - 1:
        start = route[index]
        end = route[index + 1]
        segment_distance = calculate_distance(start, end)

        if segment_distance == 0:
            index += 1
            continue

        if remaining >= segment_distance:
            remaining -= segment_distance
            index += 1
            continue

        fraction = remaining / segment_distance
        latitude = start[0] + (end[0] - start[0]) * fraction
        longitude = start[1] + (end[1] - start[1]) * fraction

        return RouteProgress(latitude, longitude, index, False)

    final_latitude, final_longitude = route[-1]
    return RouteProgress(
        final_latitude,
        final_longitude,
        len(route) - 2,
        True,
    )


def _offset_coordinate(
    latitude: float,
    longitude: float,
    delta_lat: float,
    delta_lon: float,
) -> Coordinate:
    lat_step = delta_lat if -90 <= latitude + delta_lat <= 90 else -delta_lat
    lon_step = delta_lon if -180 <= longitude + delta_lon <= 180 else -delta_lon
    return (round(latitude + lat_step, 6), round(longitude + lon_step, 6))


def build_route(
    start_latitude: float,
    start_longitude: float,
    loop: bool = False,
) -> tuple[Coordinate, ...]:
    """Build a valid geographic route starting at the given coordinates."""
    start = (start_latitude, start_longitude)
    if loop:
        return (
            start,
            _offset_coordinate(start_latitude, start_longitude, 0.008, 0.004),
            _offset_coordinate(start_latitude, start_longitude, 0.004, 0.012),
            _offset_coordinate(start_latitude, start_longitude, -0.004, 0.006),
            start,
        )
    return (
        start,
        _offset_coordinate(start_latitude, start_longitude, 0.005, 0.008),
    )
