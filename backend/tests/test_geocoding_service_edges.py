import logging
from unittest.mock import MagicMock

from backend.app.services.geocoding_service import GeocodingService


def test_unexpected_worker_exception_logged_and_pending_key_cleaned(caplog):
    def exploding_callback(_desc: str) -> None:
        raise RuntimeError("callback boom")

    service = GeocodingService(
        http_get=MagicMock(return_value={"display_name": "MG Road, Bengaluru"})
    )

    with caplog.at_level(logging.WARNING):
        assert (
            service.schedule_lookup(12.9716, 77.5946, on_success=exploding_callback)
            is True
        )
        service._executor.shutdown(wait=True)

    assert "Background geocoding task failed (RuntimeError)" in caplog.text
    assert service._pending_keys == set()
    assert service._pending_futures == set()
