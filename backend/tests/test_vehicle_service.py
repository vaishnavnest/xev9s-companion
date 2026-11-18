
from unittest.mock import MagicMock

import pytest
from backend.app.services.vehicle_service import VehicleService


@pytest.fixture
def mock_repository():
    return MagicMock()


@pytest.fixture
def vehicle_service(mock_repository):
    return VehicleService(mock_repository)


def test_associate_vehicle_success(
    vehicle_service,
    mock_repository,
    monkeypatch,
):
    def fake_hash_pairing_code(pairing_code):
        assert pairing_code == "TEST-CODE-123"
        return "hashed-pairing-code"

    monkeypatch.setattr(
        "backend.app.services.vehicle_service.hash_pairing_code",
        fake_hash_pairing_code,
    )

    vehicle_service.associate_vehicle(
        user_id="507f1f77bcf86cd799439011",
        vehicle_id=" XEV9S-001 ",
        pairing_code="TEST-CODE-123",
    )

    mock_repository.associate_vehicle.assert_called_once_with(
        user_id="507f1f77bcf86cd799439011",
        vehicle_id="XEV9S-001",
        pairing_code_hash="hashed-pairing-code",
    )


def test_associate_vehicle_empty_id(
    vehicle_service,
    mock_repository,
):
    with pytest.raises(
        ValueError,
        match="Vehicle identifier cannot be empty",
    ):
        vehicle_service.associate_vehicle(
            user_id="507f1f77bcf86cd799439011",
            vehicle_id="   ",
            pairing_code="TEST-CODE-123",
        )

    mock_repository.associate_vehicle.assert_not_called()


def test_associate_vehicle_empty_pairing_code(
    vehicle_service,
    mock_repository,
):
    with pytest.raises(
        ValueError,
        match="Pairing code cannot be empty",
    ):
        vehicle_service.associate_vehicle(
            user_id="507f1f77bcf86cd799439011",
            vehicle_id="XEV9S-001",
            pairing_code="",
        )

    mock_repository.associate_vehicle.assert_not_called()


def test_associate_vehicle_hashing_failure(
    vehicle_service,
    mock_repository,
    monkeypatch,
):
    def raise_hash_error(_pairing_code):
        raise RuntimeError("Hashing configuration error")

    monkeypatch.setattr(
        "backend.app.services.vehicle_service.hash_pairing_code",
        raise_hash_error,
    )

    with pytest.raises(
        RuntimeError,
        match="Hashing configuration error",
    ):
        vehicle_service.associate_vehicle(
            user_id="507f1f77bcf86cd799439011",
            vehicle_id="XEV9S-001",
            pairing_code="TEST-CODE-123",
        )

    mock_repository.associate_vehicle.assert_not_called()


def test_get_user_vehicles(
    vehicle_service,
    mock_repository,
):
    expected_vehicles = [
        {
            "vehicle_id": "XEV9S-001",
            "model": "XEV 9S",
            "association_status": "active",
        }
    ]
    mock_repository.get_user_vehicles.return_value = expected_vehicles

    result = vehicle_service.get_user_vehicles(
        "507f1f77bcf86cd799439011"
    )

    assert result == expected_vehicles
    mock_repository.get_user_vehicles.assert_called_once_with(
        "507f1f77bcf86cd799439011"
    )


def test_is_vehicle_associated_with_user_returns_true(
    vehicle_service,
    mock_repository,
):
    mock_repository.is_vehicle_associated_with_user.return_value = True

    result = vehicle_service.is_vehicle_associated_with_user(
        user_id="507f1f77bcf86cd799439011",
        vehicle_id=" XEV9S-001 ",
    )

    assert result is True
    mock_repository.is_vehicle_associated_with_user.assert_called_once_with(
        user_id="507f1f77bcf86cd799439011",
        vehicle_id="XEV9S-001",
    )


def test_is_vehicle_associated_with_user_returns_false(
    vehicle_service,
    mock_repository,
):
    mock_repository.is_vehicle_associated_with_user.return_value = False

    result = vehicle_service.is_vehicle_associated_with_user(
        user_id="507f1f77bcf86cd799439011",
        vehicle_id="XEV9S-001",
    )

    assert result is False


def test_is_vehicle_associated_with_user_empty_id(
    vehicle_service,
    mock_repository,
):
    with pytest.raises(
        ValueError,
        match="Vehicle identifier cannot be empty",
    ):
        vehicle_service.is_vehicle_associated_with_user(
            user_id="507f1f77bcf86cd799439011",
            vehicle_id="   ",
        )

    mock_repository.is_vehicle_associated_with_user.assert_not_called()
