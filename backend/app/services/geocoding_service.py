import http.client
import logging
import threading
import time
from collections import OrderedDict
from collections.abc import Callable
from concurrent.futures import Executor, Future, ThreadPoolExecutor
from urllib.parse import parse_qsl, urlencode, urlsplit

import httpx
from backend.app.services.geocoding_formatter import format_nominatim_address

logger = logging.getLogger(__name__)
NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"
NOMINATIM_HOST = "nominatim.openstreetmap.org"
DEFAULT_USER_AGENT = "xev9s-companion/1.0"


def _cache_key(latitude: float, longitude: float) -> tuple[float, float]:
    return round(latitude, 4), round(longitude, 4)


def _default_http_get(url: str, headers: dict[str, str], timeout: float) -> object:
    """Perform a validated HTTPS request to the Nominatim endpoint."""
    parsed = urlsplit(url)
    if (
        parsed.scheme != "https"
        or parsed.netloc != NOMINATIM_HOST
        or parsed.path != "/reverse"
        or parsed.username
        or parsed.password
        or parsed.fragment
    ):
        raise ValueError("Invalid geocoding URL")

    with httpx.Client(timeout=timeout, verify=True, follow_redirects=False) as client:
        response = client.get(
            NOMINATIM_URL,
            params=parse_qsl(parsed.query),
            headers=headers,
        )
        response.raise_for_status()
        return response.json()


class GeocodingService:
    """Thread-safe, rate-limited reverse geocoding with caching."""

    def __init__(
        self,
        user_agent: str = DEFAULT_USER_AGENT,
        timeout_seconds: float = 2.5,
        min_interval_seconds: float = 1.0,
        cache_max_size: int = 512,
        cache_ttl_seconds: float = 3600.0,
        http_get: Callable[..., object] | None = None,
        executor: Executor | None = None,
        time_fn: Callable[[], float] | None = None,
        sleep_fn: Callable[[float], None] | None = None,
    ) -> None:
        self._user_agent = user_agent
        self._timeout_seconds = timeout_seconds
        self._min_interval_seconds = max(1.0, min_interval_seconds)
        self._cache_max_size = max(1, cache_max_size)
        self._cache_ttl_seconds = cache_ttl_seconds
        self._http_get = http_get or _default_http_get
        self._owns_executor = executor is None
        self._executor = executor or ThreadPoolExecutor(
            max_workers=2, thread_name_prefix="geocoder"
        )
        self._time = time_fn or time.monotonic
        self._sleep = sleep_fn or time.sleep
        self._lock = threading.Lock()
        self._rate_lock = threading.Lock()
        self._cache: OrderedDict[tuple[float, float], tuple[str, float]] = OrderedDict()
        self._pending_keys: set[tuple[float, float]] = set()
        self._pending_futures: set[Future[None]] = set()
        self._last_request_time: float | None = None

    def get_cached(self, latitude: float, longitude: float) -> str | None:
        key = _cache_key(latitude, longitude)
        with self._lock:
            entry = self._cache.get(key)
            if entry is None:
                return None
            description, expires_at = entry
            if self._time() >= expires_at:
                del self._cache[key]
                return None
            self._cache.move_to_end(key)
            return description

    def _set_cached(self, key: tuple[float, float], description: str) -> None:
        with self._lock:
            self._cache[key] = (
                description,
                self._time() + self._cache_ttl_seconds,
            )
            self._cache.move_to_end(key)
            while len(self._cache) > self._cache_max_size:
                self._cache.popitem(last=False)

    def _wait_for_rate_limit(self) -> None:
        with self._rate_lock:
            now = self._time()
            if self._last_request_time is not None:
                elapsed = now - self._last_request_time
                if elapsed < self._min_interval_seconds:
                    self._sleep(self._min_interval_seconds - elapsed)
            self._last_request_time = self._time()

    def reverse_geocode(self, latitude: float, longitude: float) -> str | None:
        cached = self.get_cached(latitude, longitude)
        if cached is not None:
            return cached

        key = _cache_key(latitude, longitude)
        self._wait_for_rate_limit()
        cached = self.get_cached(latitude, longitude)
        if cached is not None:
            return cached

        query = urlencode(
            {
                "format": "jsonv2",
                "lat": f"{latitude:.6f}",
                "lon": f"{longitude:.6f}",
            }
        )
        try:
            payload = self._http_get(
                f"{NOMINATIM_URL}?{query}",
                headers={"User-Agent": self._user_agent},
                timeout=self._timeout_seconds,
            )
        except (
            httpx.HTTPError,
            http.client.HTTPException,
            OSError,
            ValueError,
            TypeError,
        ) as exc:
            logger.warning("Reverse geocoding failed (%s)", type(exc).__name__)
            return None

        description = format_nominatim_address(payload)
        if description is not None:
            self._set_cached(key, description)
        return description

    def _handle_future_done(self, future: Future[None]) -> None:
        with self._lock:
            self._pending_futures.discard(future)
        if future.cancelled():
            return
        exc = future.exception()
        if exc is not None:
            logger.warning("Background geocoding task failed (%s)", type(exc).__name__)

    def schedule_lookup(
        self,
        latitude: float,
        longitude: float,
        on_success: Callable[[str], None] | None = None,
    ) -> bool:
        if self.get_cached(latitude, longitude) is not None:
            return False

        key = _cache_key(latitude, longitude)
        with self._lock:
            if key in self._pending_keys:
                return False
            self._pending_keys.add(key)

        def _run() -> None:
            try:
                description = self.reverse_geocode(latitude, longitude)
                if description is not None and on_success is not None:
                    on_success(description)
            finally:
                with self._lock:
                    self._pending_keys.discard(key)

        try:
            future = self._executor.submit(_run)
        except Exception:
            with self._lock:
                self._pending_keys.discard(key)
            raise

        with self._lock:
            self._pending_futures.add(future)
        future.add_done_callback(self._handle_future_done)
        return True

    def shutdown(self, wait: bool = True) -> None:
        if self._owns_executor:
            self._executor.shutdown(wait=wait)
