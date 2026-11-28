import http.client
import threading
from concurrent.futures import Future
from unittest.mock import MagicMock
from urllib.error import HTTPError

from backend.app.services.geocoding_service import (
    DEFAULT_USER_AGENT,
    GeocodingService,
    format_nominatim_address,
)


class _ImmediateExecutor:
    def submit(self, fn, *args, **kwargs):
        future: Future = Future()
        future.set_result(fn(*args, **kwargs))
        return future


def test_format_nominatim_address_concise_and_deduplicated():
    payload = {
        "address": {
            "road": "MG Road",
            "neighbourhood": "Ashok Nagar",
            "suburb": "Ashok Nagar",
            "city": "Bengaluru",
            "state": "Karnataka",
            "country": "India",
        },
        "display_name": "MG Road, Ashok Nagar, Bengaluru, Karnataka, India",
    }

    assert (
        format_nominatim_address(payload)
        == "MG Road, Ashok Nagar, Bengaluru, Karnataka"
    )


def test_format_nominatim_address_display_name_fallback_and_truncation():
    long_name = ", ".join(f"Segment {i}" for i in range(25))
    result = format_nominatim_address({"display_name": long_name})

    assert result is not None
    assert len(result) <= 120
    assert result.endswith("...")


def test_cache_hits_for_rounded_coordinates():
    http_get = MagicMock(
        return_value={"address": {"road": "MG Road", "city": "Bengaluru"}}
    )
    service = GeocodingService(http_get=http_get)

    first = service.reverse_geocode(12.97161, 77.59461)
    second = service.reverse_geocode(12.97164, 77.59464)

    assert first == "MG Road, Bengaluru"
    assert second == "MG Road, Bengaluru"
    assert http_get.call_count == 1
    assert http_get.call_args.kwargs["headers"]["User-Agent"] == DEFAULT_USER_AGENT
    assert 2.0 <= http_get.call_args.kwargs["timeout"] <= 3.0


def test_timeout_returns_none():
    http_get = MagicMock(side_effect=TimeoutError("timed out"))
    service = GeocodingService(http_get=http_get)

    assert service.reverse_geocode(12.9716, 77.5946) is None


def test_http_error_returns_none():
    http_get = MagicMock(
        side_effect=HTTPError(
            "https://nominatim.openstreetmap.org/reverse",
            503,
            "Service Unavailable",
            None,
            None,
        )
    )
    service = GeocodingService(http_get=http_get)

    assert service.reverse_geocode(12.9716, 77.5946) is None


def test_malformed_response_returns_none():
    service = GeocodingService(http_get=MagicMock(side_effect=ValueError("bad json")))
    assert service.reverse_geocode(12.9716, 77.5946) is None

    service2 = GeocodingService(http_get=MagicMock(return_value=["unexpected", "list"]))
    assert service2.reverse_geocode(12.9716, 77.5946) is None


def test_rate_limit_enforces_minimum_interval():
    now = [10.0]
    sleeps: list[float] = []

    def fake_time() -> float:
        return now[0]

    def fake_sleep(seconds: float) -> None:
        sleeps.append(seconds)
        now[0] += seconds

    http_get = MagicMock(return_value={"display_name": "Bengaluru"})
    service = GeocodingService(
        min_interval_seconds=1.0,
        http_get=http_get,
        time_fn=fake_time,
        sleep_fn=fake_sleep,
    )

    service.reverse_geocode(12.9716, 77.5946)
    now[0] += 0.25
    service.reverse_geocode(13.0827, 80.2707)

    assert sleeps == [0.75]
    assert http_get.call_count == 2


def test_schedule_lookup_deduplicates_pending_requests():
    gate = threading.Event()
    started = threading.Event()

    def slow_http_get(*_args, **_kwargs):
        started.set()
        gate.wait(timeout=2.0)
        return {"display_name": "Cubbon Park, Bengaluru"}

    service = GeocodingService(http_get=slow_http_get)

    first = service.schedule_lookup(12.9716, 77.5946)
    assert started.wait(timeout=1.0)
    second = service.schedule_lookup(12.97161, 77.59461)

    gate.set()
    service._executor.shutdown(wait=True)

    assert first is True
    assert second is False
    assert service.get_cached(12.9716, 77.5946) == "Cubbon Park, Bengaluru"


def test_schedule_lookup_invokes_on_success_and_caches():
    http_get = MagicMock(return_value={"display_name": "Indiranagar, Bengaluru"})
    results: list[str] = []
    service = GeocodingService(
        http_get=http_get,
        executor=_ImmediateExecutor(),
    )

    scheduled = service.schedule_lookup(12.9784, 77.6408, on_success=results.append)

    assert scheduled is True
    assert results == ["Indiranagar, Bengaluru"]
    assert service.get_cached(12.9784, 77.6408) == "Indiranagar, Bengaluru"
    assert service._pending_keys == set()


def test_oserror_and_http_exception_return_none():
    os_err_service = GeocodingService(
        http_get=MagicMock(side_effect=OSError("net down"))
    )
    assert os_err_service.reverse_geocode(12.9716, 77.5946) is None

    http_exc_service = GeocodingService(
        http_get=MagicMock(side_effect=http.client.HTTPException("bad response"))
    )
    assert http_exc_service.reverse_geocode(12.9716, 77.5946) is None


def test_pending_key_cleaned_up_after_failure():
    service = GeocodingService(http_get=MagicMock(side_effect=TimeoutError("timeout")))

    assert service.schedule_lookup(12.9716, 77.5946) is True
    service._executor.shutdown(wait=True)

    assert service._pending_keys == set()
    assert service._pending_futures == set()
