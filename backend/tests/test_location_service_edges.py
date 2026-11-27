from concurrent.futures import Future
from datetime import UTC, datetime
from unittest.mock import MagicMock

import pytest
from backend.app.services.geocoding_service import GeocodingService
from backend.app.services.location_service import LocationService


class _ImmediateExecutor:
    def submit(self, fn, *args, **kwargs):
        future: Future = Future()
        future.set_result(fn(*args, **kwargs))
        return future


@pytest.fixture
def mock_repos():
    return MagicMock(), MagicMock()


def _setup_vehicle(vehicle_repo, telemetry_repo, lat, lon):
    now = datetime.now(UTC)
    vehicle_repo.get_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-001",
        "is_active": True,
    }
    vehicle_repo.is_vehicle_associated_with_user.return_value = True
    telemetry_repo.get_latest_telemetry.return_value = {
        "vehicle_id": "XEV-001",
        "timestamp": now,
        "operating_state": "driving",
    }
    telemetry_repo.get_latest_valid_location.return_value = {
        "vehicle_id": "XEV-001",
        "latitude": lat,
        "longitude": lon,
        "timestamp": now,
    }


def test_distance_gating_reuses_description_below_150m_and_refreshes_above(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    http_get = MagicMock(
        side_effect=[
            {"display_name": "Start Point, Bengaluru"},
            {"display_name": "New Point, Bengaluru"},
        ]
    )
    geocoder = GeocodingService(
        min_interval_seconds=1.0,
        http_get=http_get,
        executor=_ImmediateExecutor(),
        time_fn=lambda: 100.0,
        sleep_fn=lambda _s: None,
    )
    service = LocationService(vehicle_repo, telemetry_repo, geocoding_service=geocoder)

    _setup_vehicle(vehicle_repo, telemetry_repo, 12.9716, 77.5946)
    first = service.get_vehicle_location("user-1", "XEV-001")
    assert first.description is None
    assert http_get.call_count == 1

    _setup_vehicle(vehicle_repo, telemetry_repo, 12.9721, 77.5946)
    second = service.get_vehicle_location("user-1", "XEV-001")
    assert second.description == "Start Point, Bengaluru"
    assert http_get.call_count == 1

    _setup_vehicle(vehicle_repo, telemetry_repo, 12.9770, 77.5946)
    third = service.get_vehicle_location("user-1", "XEV-001")
    assert third.description is None
    assert http_get.call_count == 2

    fourth = service.get_vehicle_location("user-1", "XEV-001")
    assert fourth.description == "New Point, Bengaluru"


def test_geocoder_failure_returns_none_and_allows_retry(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    _setup_vehicle(vehicle_repo, telemetry_repo, 12.9716, 77.5946)

    http_get = MagicMock(side_effect=TimeoutError("timeout"))
    geocoder = GeocodingService(
        http_get=http_get,
        executor=_ImmediateExecutor(),
        time_fn=lambda: 100.0,
        sleep_fn=lambda _s: None,
    )
    service = LocationService(vehicle_repo, telemetry_repo, geocoding_service=geocoder)

    result = service.get_vehicle_location("user-1", "XEV-001")

    assert result.description is None
    assert result.latitude == 12.9716
    assert http_get.call_count == 1


@pytest.mark.parametrize(
    "lat,lon",
    [
        (None, None),
        (12.9716, None),
        (95.0, 77.5946),
        (12.9716, 200.0),
        (float("nan"), 77.5946),
    ],
)
def test_null_or_invalid_coordinates_skip_geocoding(mock_repos, lat, lon):
    vehicle_repo, telemetry_repo = mock_repos
    _setup_vehicle(vehicle_repo, telemetry_repo, lat, lon)
    geocoder = MagicMock(spec=GeocodingService)
    service = LocationService(vehicle_repo, telemetry_repo, geocoding_service=geocoder)

    assert service._resolve_description("XEV-001", lat, lon) is None
    geocoder.get_cached.assert_not_called()
    geocoder.schedule_lookup.assert_not_called()


def test_real_thread_pool_executor_populates_cache_for_subsequent_request(mock_repos):
    vehicle_repo, telemetry_repo = mock_repos
    _setup_vehicle(vehicle_repo, telemetry_repo, 12.9716, 77.5946)

    http_get = MagicMock(
        return_value={"address": {"road": "Vittal Mallya Road", "city": "Bengaluru"}}
    )
    geocoder = GeocodingService(http_get=http_get)
    service = LocationService(vehicle_repo, telemetry_repo, geocoding_service=geocoder)

    first = service.get_vehicle_location("user-1", "XEV-001")
    assert first.description is None

    geocoder._executor.shutdown(wait=True)

    second = service.get_vehicle_location("user-1", "XEV-001")
    assert second.description == "Vittal Mallya Road, Bengaluru"
    assert http_get.call_count == 1
