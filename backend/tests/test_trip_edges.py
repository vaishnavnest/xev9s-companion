import os
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import TripAlreadyActiveError
from backend.app.routes import trips as trip_routes
from backend.app.schemas.telemetry import TelemetryPayload
from backend.app.services.trip_lifecycle import TripLifecycleManager
from backend.app.services.trip_runtime import (
    create_trip_notification_callback,
)
from backend.app.services.trip_service import TripService
from fastapi import Request


def test_validate_vehicle_access_empty_id():
    svc = TripService(MagicMock(), MagicMock(), MagicMock())
    with pytest.raises(ValueError, match="Vehicle identifier cannot be empty"):
        svc.list_trips(user_id="u1", vehicle_id="   ")


def test_get_trip_detail_empty_trip_id():
    svc = TripService(MagicMock(), MagicMock(), MagicMock())
    svc.vehicle_repository.get_vehicle_by_id.return_value = {"is_active": True}
    svc.vehicle_repository.is_vehicle_associated_with_user.return_value = True

    with pytest.raises(ValueError, match="Trip identifier cannot be empty"):
        svc.get_trip_detail(user_id="u1", vehicle_id="V1", trip_id="   ")


def test_get_trip_service_fallback_creates_new():
    request = MagicMock(spec=Request)
    request.app.state = MagicMock(spec=[])
    request.app.state.database = MagicMock()

    svc = trip_routes.get_trip_service(request)
    assert isinstance(svc, TripService)

    # Also test when trip_service is already on request.app.state
    request.app.state.trip_service = svc
    assert trip_routes.get_trip_service(request) is svc


def test_trip_service_delegates_process_telemetry():
    lifecycle = MagicMock()
    svc = TripService(MagicMock(), MagicMock(), lifecycle)
    tel = MagicMock(spec=TelemetryPayload)
    svc.process_telemetry(tel)
    lifecycle.process_telemetry.assert_called_once_with(tel)


def test_handle_trip_error_unhandled():
    with pytest.raises(RuntimeError):
        trip_routes.handle_trip_error(RuntimeError("Unexpected error"))


def test_trip_notification_callback_future_exception():
    websocket_manager = MagicMock()
    event_loop = MagicMock()
    future = MagicMock()
    future.result.side_effect = RuntimeError("Broadcast network error")

    def capture_callback(fut, loop):
        return future

    event_loop.call_soon_threadsafe = MagicMock()
    import asyncio

    orig_run = asyncio.run_coroutine_threadsafe
    try:
        asyncio.run_coroutine_threadsafe = lambda coro, loop: future
        notify = create_trip_notification_callback(websocket_manager, event_loop)
        notify({"vehicle_id": "V1", "trip_id": "T1", "status": "completed"})
        for callback in future.add_done_callback.call_args_list:
            callback[0][0](future)
    finally:
        asyncio.run_coroutine_threadsafe = orig_run


def test_driving_start_race_condition_reraise():
    repo = MagicMock()
    repo.get_active_trip.side_effect = [None, None]
    repo.create_trip.side_effect = TripAlreadyActiveError("Race error")
    manager = TripLifecycleManager(repo)

    tel = MagicMock(spec=TelemetryPayload)
    tel.operating_state = "driving"
    tel.vehicle_id = "V1"

    with pytest.raises(TripAlreadyActiveError):
        manager._handle_driving_telemetry(tel)


def test_trip_config_negative_capacity():
    with pytest.raises(
        ValueError, match="DEFAULT_BATTERY_CAPACITY_KWH must be positive"
    ):
        import importlib

        os.environ["DEFAULT_BATTERY_CAPACITY_KWH"] = "-5.0"
        import backend.app.core.trip_config as tc

        try:
            importlib.reload(tc)
        finally:
            os.environ["DEFAULT_BATTERY_CAPACITY_KWH"] = "60.0"
            importlib.reload(tc)


def test_telemetry_service_calls_trip_service():
    from backend.app.services.telemetry_service import TelemetryService

    tel_repo = MagicMock()
    veh_repo = MagicMock()
    veh_repo.get_active_vehicle_by_id.return_value = {
        "vehicle_id": "V1",
        "is_active": True,
    }
    trip_svc = MagicMock()

    service = TelemetryService(tel_repo, veh_repo, trip_service=trip_svc)
    tel = MagicMock(spec=TelemetryPayload)
    tel.vehicle_id = "V1"
    tel.model_copy.return_value = tel

    service.ingest_telemetry(tel)
    trip_svc.process_telemetry.assert_called_once_with(tel)
