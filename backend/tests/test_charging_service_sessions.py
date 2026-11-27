from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import ChargingSessionNotFoundError
from backend.app.schemas.charging_session import ChargingSessionStatus
from backend.app.services.charging_service import ChargingService


@pytest.fixture
def deps():
    return {
        "charging": MagicMock(),
        "sessions": MagicMock(),
        "events": MagicMock(),
        "vehicles": MagicMock(),
        "mongo": MagicMock(),
        "mqtt": MagicMock(),
    }


@pytest.fixture
def service(deps):
    return ChargingService(
        deps["charging"], deps["sessions"], deps["events"],
        deps["vehicles"], deps["mongo"], deps["mqtt"],
    )


def authorize(deps, owned=True):
    deps["vehicles"].get_active_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-DEMO-001"
    }
    deps["vehicles"].is_vehicle_associated_with_user.return_value = owned


def test_session_history(service, deps):
    authorize(deps)
    expected = ([{"session_id": "session-1"}], 1)
    deps["sessions"].get_session_history.return_value = expected

    result = service.get_session_history(
        "user-1",
        "XEV-DEMO-001",
        limit=10,
        offset=5,
        status=ChargingSessionStatus.COMPLETED,
    )

    assert result == expected
    deps["sessions"].get_session_history.assert_called_once_with(
        "XEV-DEMO-001",
        10,
        5,
        status=ChargingSessionStatus.COMPLETED,
        from_time=None,
        to_time=None,
        sort="-started_at",
    )


def test_session_history_invalid_time_range(service, deps):
    authorize(deps)
    now = datetime.now(UTC)
    with pytest.raises(ValueError, match="cannot be after end timestamp"):
        service.get_session_history(
            "user-1",
            "XEV-DEMO-001",
            from_time=now,
            to_time=now - timedelta(hours=1),
        )


def test_get_session_detail_success(service, deps):
    authorize(deps)
    expected = {"session_id": "session-1", "vehicle_id": "XEV-DEMO-001"}
    deps["sessions"].get_session.return_value = expected

    result = service.get_session_detail("user-1", "XEV-DEMO-001", "session-1")

    assert result == expected
    deps["sessions"].get_session.assert_called_once_with("session-1")


def test_get_session_detail_not_found_or_other_vehicle(service, deps):
    authorize(deps)
    deps["sessions"].get_session.return_value = None
    with pytest.raises(ChargingSessionNotFoundError):
        service.get_session_detail("user-1", "XEV-DEMO-001", "missing")

    deps["sessions"].get_session.return_value = {
        "session_id": "session-2",
        "vehicle_id": "OTHER-VEH",
    }
    with pytest.raises(ChargingSessionNotFoundError):
        service.get_session_detail("user-1", "XEV-DEMO-001", "session-2")


@pytest.mark.parametrize("limit", [0, 101])
def test_invalid_history_limit(service, deps, limit):
    authorize(deps)
    with pytest.raises(ValueError, match="Limit must be between"):
        service.get_session_history("user-1", "XEV-DEMO-001", limit=limit)


def test_negative_history_offset(service, deps):
    authorize(deps)
    with pytest.raises(ValueError, match="Offset cannot be negative"):
        service.get_session_history(
            "user-1", "XEV-DEMO-001", offset=-1
        )
