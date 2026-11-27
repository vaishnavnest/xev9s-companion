
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.schemas.charging import ChargingPreferencesUpdate
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


@pytest.fixture
def preferences():
    return ChargingPreferencesUpdate(
        target_percentage=90,
        schedule_enabled=False,
        timezone="Asia/Kolkata",
        stop_charging_at_target=True,
    )


def authorize(deps, owned=True):
    deps["vehicles"].get_active_vehicle_by_id.return_value = {
        "vehicle_id": "XEV-DEMO-001"
    }
    deps["vehicles"].is_vehicle_associated_with_user.return_value = owned


def test_empty_vehicle_id(service):
    with pytest.raises(ValueError, match="cannot be empty"):
        service._validate_vehicle("  ")


def test_inactive_vehicle(service, deps):
    deps["vehicles"].get_active_vehicle_by_id.return_value = None
    with pytest.raises(VehicleNotActiveError):
        service._validate_vehicle("XEV-DEMO-001")


def test_vehicle_id_normalization(service, deps):
    authorize(deps)
    assert service._validate_vehicle(" XEV-DEMO-001 ") == "XEV-DEMO-001"


def test_unauthorized_user(service, deps):
    authorize(deps, owned=False)
    with pytest.raises(VehicleAccessDeniedError):
        service.get_preferences("user-1", "XEV-DEMO-001")


def test_get_preferences(service, deps):
    authorize(deps)
    expected = {"target_percentage": 90}
    active = {"session_id": "session-active"}
    deps["charging"].get_preferences.return_value = expected
    deps["sessions"].get_active_session.return_value = active
    result = service.get_preferences("user-1", "XEV-DEMO-001")
    assert result == {"target_percentage": 90, "active_session": active}
    deps["charging"].get_preferences.assert_called_once_with("XEV-DEMO-001")
    deps["sessions"].get_active_session.assert_called_once_with("XEV-DEMO-001")


def test_get_preferences_when_none(service, deps):
    authorize(deps)
    deps["charging"].get_preferences.return_value = None
    assert service.get_preferences("user-1", "XEV-DEMO-001") is None
    deps["sessions"].get_active_session.assert_not_called()


def test_update_preferences_with_active_session(service, deps, preferences):
    authorize(deps)
    deps["charging"].save_preferences.return_value = {"saved": True}
    deps["sessions"].get_active_session.return_value = {
        "session_id": "session-1"
    }

    result = service.update_preferences(
        "user-1", "XEV-DEMO-001", preferences
    )

    assert result == {"saved": True}
    deps["sessions"].update_session.assert_called_once()
    update = deps["sessions"].update_session.call_args.args[1]
    assert update["final_target_percentage"] == 90
    deps["mqtt"].publish_preferences.assert_called_once()


def test_update_preferences_without_active_session(
    service, deps, preferences
):
    authorize(deps)
    deps["charging"].save_preferences.return_value = {"saved": True}
    deps["sessions"].get_active_session.return_value = None

    service.update_preferences("user-1", "XEV-DEMO-001", preferences)

    deps["sessions"].update_session.assert_not_called()
    deps["mqtt"].publish_preferences.assert_called_once()


def test_update_preferences_without_mqtt(deps, preferences):
    authorize(deps)
    deps["charging"].save_preferences.return_value = {"saved": True}
    service = ChargingService(
        deps["charging"], deps["sessions"], deps["events"],
        deps["vehicles"], deps["mongo"],
    )

    result = service.update_preferences(
        "user-1", "XEV-DEMO-001", preferences
    )

    assert result == {"saved": True}
