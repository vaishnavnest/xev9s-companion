from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    MQTTUnavailableError,
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.routes import charging
from fastapi import HTTPException


@pytest.fixture
def request_context():
    class FakeDatabase(dict):
        client = MagicMock()

    database = FakeDatabase({
        "charging_preferences": MagicMock(),
        "charging_sessions": MagicMock(),
        "charging_events": MagicMock(),
        "vehicles": MagicMock(),
        "user_vehicles": MagicMock(),
    })

    mqtt_client = MagicMock()
    request = SimpleNamespace(
        app=SimpleNamespace(
            state=SimpleNamespace(
                database=database,
                mqtt_subscriber=SimpleNamespace(client=mqtt_client),
            )
        )
    )
    return request


def test_get_charging_service_uses_application_resources(request_context):
    service = charging.get_charging_service(request_context)

    assert isinstance(service, charging.ChargingService)


@pytest.mark.parametrize(
    ("error", "expected_status"),
    [
        (VehicleNotActiveError("inactive"), 404),
        (ValueError("invalid value"), 422),
        (MQTTUnavailableError("broker unavailable"), 503),
    ],
)
def test_handle_charging_error(error, expected_status):
    with pytest.raises(HTTPException) as exc:
        charging.handle_charging_error(error)

    assert exc.value.status_code == expected_status


@pytest.mark.parametrize(
    ("error", "expected_status"),
    [
        (VehicleAccessDeniedError("denied"), 403),
        (VehicleNotActiveError("inactive"), 404),
    ],
)
def test_get_preferences_translates_service_errors(
    monkeypatch, request_context, error, expected_status
):
    service = MagicMock()
    service.get_preferences.side_effect = error
    monkeypatch.setattr(charging, "get_charging_service", lambda request: service)

    with pytest.raises(HTTPException) as exc:
        charging.get_charging_preferences(
            "vehicle-001",
            request_context,
            {"id": "user-001"},
        )

    assert exc.value.status_code == expected_status


@pytest.mark.parametrize(
    ("error", "expected_status"),
    [
        (VehicleAccessDeniedError("denied"), 403),
        (VehicleNotActiveError("inactive"), 404),
        (ValueError("invalid pagination"), 422),
    ],
)
def test_get_sessions_translates_service_errors(
    monkeypatch, request_context, error, expected_status
):
    service = MagicMock()
    service.get_session_history.side_effect = error
    monkeypatch.setattr(charging, "get_charging_service", lambda request: service)

    with pytest.raises(HTTPException) as exc:
        charging.get_charging_sessions(
            "vehicle-001",
            request_context,
            20,
            0,
            {"id": "user-001"},
        )

    assert exc.value.status_code == expected_status