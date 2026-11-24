
from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    VehicleAccessDeniedError,
    VehicleNotActiveError,
)
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.telemetry_service import TelemetryService


@pytest.fixture
def repositories():
    return MagicMock(), MagicMock()


@pytest.fixture
def telemetry_service(repositories):
    telemetry_repository, vehicle_repository = repositories
    return TelemetryService(telemetry_repository, vehicle_repository)


@pytest.fixture
def valid_telemetry():
    return TelemetryPayload(
        vehicle_id=" XEV9S-001 ",
        timestamp=datetime.now(UTC),
        battery_percentage=80.0,
        estimated_range_km=300.0,
        speed_kph=0.0,
        odometer_km=1200.5,
        latitude=8.5241,
        longitude=76.9366,
        operating_state="parked",
        is_locked=True,
        charging_status="disconnected",
        charging_power_kw=0.0,
        cabin_preconditioning_active=False,
    )


def test_ingest_telemetry_success(
    telemetry_service,
    repositories,
    valid_telemetry,
):
    telemetry_repository, vehicle_repository = repositories
    expected = {"vehicle_id": "XEV9S-001"}
    vehicle_repository.get_active_vehicle_by_id.return_value = {
        "vehicle_id": "XEV9S-001",
        "is_active": True,
    }
    telemetry_repository.save_telemetry.return_value = expected

    result = telemetry_service.ingest_telemetry(valid_telemetry)

    assert result == expected
    vehicle_repository.get_active_vehicle_by_id.assert_called_once_with(
        "XEV9S-001"
    )
    saved_payload = telemetry_repository.save_telemetry.call_args.args[0]
    assert saved_payload.vehicle_id == "XEV9S-001"


def test_ingest_telemetry_inactive_vehicle(
    telemetry_service,
    repositories,
    valid_telemetry,
):
    telemetry_repository, vehicle_repository = repositories
    vehicle_repository.get_active_vehicle_by_id.return_value = None

    with pytest.raises(VehicleNotActiveError):
        telemetry_service.ingest_telemetry(valid_telemetry)

    telemetry_repository.save_telemetry.assert_not_called()


def test_get_latest_telemetry_success(
    telemetry_service,
    repositories,
):
    telemetry_repository, vehicle_repository = repositories
    expected = {"vehicle_id": "XEV9S-001"}
    vehicle_repository.is_vehicle_associated_with_user.return_value = True
    telemetry_repository.get_latest_telemetry.return_value = expected

    result = telemetry_service.get_latest_telemetry(
        "user-123",
        " XEV9S-001 ",
    )

    assert result == expected
    vehicle_repository.is_vehicle_associated_with_user.assert_called_once_with(
        "user-123",
        "XEV9S-001",
    )
    telemetry_repository.get_latest_telemetry.assert_called_once_with(
        "XEV9S-001"
    )


def test_get_latest_telemetry_access_denied(
    telemetry_service,
    repositories,
):
    telemetry_repository, vehicle_repository = repositories
    vehicle_repository.is_vehicle_associated_with_user.return_value = False

    with pytest.raises(VehicleAccessDeniedError):
        telemetry_service.get_latest_telemetry(
            "user-123",
            "XEV9S-001",
        )

    telemetry_repository.get_latest_telemetry.assert_not_called()


def test_get_telemetry_history_success(
    telemetry_service,
    repositories,
):
    telemetry_repository, vehicle_repository = repositories
    start_time = datetime.now(UTC)
    end_time = start_time + timedelta(hours=1)
    expected = [{"vehicle_id": "XEV9S-001"}]
    vehicle_repository.is_vehicle_associated_with_user.return_value = True
    telemetry_repository.get_telemetry_history.return_value = expected

    result = telemetry_service.get_telemetry_history(
        "user-123",
        "XEV9S-001",
        start_time,
        end_time,
        limit=50,
    )

    assert result == expected
    telemetry_repository.get_telemetry_history.assert_called_once_with(
        "XEV9S-001",
        start_time,
        end_time,
        50,
    )


def test_get_telemetry_history_invalid_time_range(
    telemetry_service,
    repositories,
):
    telemetry_repository, vehicle_repository = repositories
    start_time = datetime.now(UTC)
    end_time = start_time - timedelta(hours=1)

    with pytest.raises(ValueError, match="Start time must be before end time"):
        telemetry_service.get_telemetry_history(
            "user-123",
            "XEV9S-001",
            start_time,
            end_time,
        )

    vehicle_repository.is_vehicle_associated_with_user.assert_not_called()
    telemetry_repository.get_telemetry_history.assert_not_called()


@pytest.mark.parametrize("limit", [0, 1001])
def test_get_telemetry_history_invalid_limit(
    telemetry_service,
    repositories,
    limit,
):
    telemetry_repository, vehicle_repository = repositories
    start_time = datetime.now(UTC)
    end_time = start_time + timedelta(hours=1)

    with pytest.raises(ValueError, match="Limit must be between 1 and 1000"):
        telemetry_service.get_telemetry_history(
            "user-123",
            "XEV9S-001",
            start_time,
            end_time,
            limit,
        )

    vehicle_repository.is_vehicle_associated_with_user.assert_not_called()
    telemetry_repository.get_telemetry_history.assert_not_called()
