
from unittest.mock import MagicMock

import pytest
from backend.app.core.exceptions import (
    InvalidPairingCodeError,
    VehicleAlreadyAssociatedError,
)
from bson import ObjectId
from pymongo.errors import DuplicateKeyError


def test_associate_vehicle_success(repo, mock_collections):
    vehicles, associations = mock_collections
    user_id = str(ObjectId())

    vehicles.find_one_and_update.return_value = {
        "vehicle_id": "XEV9S-001"
    }

    repo.associate_vehicle(
        user_id=user_id,
        vehicle_id="XEV9S-001",
        pairing_code_hash="valid_hash",
    )

    vehicles.find_one_and_update.assert_called_once()
    associations.insert_one.assert_called_once()

    document = associations.insert_one.call_args.args[0]
    assert document["user_id"] == ObjectId(user_id)
    assert document["vehicle_id"] == "XEV9S-001"


def test_associate_vehicle_invalid_user_id(repo, mock_collections):
    vehicles, associations = mock_collections

    with pytest.raises(ValueError, match="Invalid user identifier"):
        repo.associate_vehicle(
            user_id="invalid",
            vehicle_id="XEV9S-001",
            pairing_code_hash="valid_hash",
        )

    vehicles.find_one_and_update.assert_not_called()
    associations.insert_one.assert_not_called()


def test_associate_vehicle_invalid_pairing_code(repo, mock_collections):
    vehicles, associations = mock_collections
    vehicles.find_one_and_update.return_value = None

    with pytest.raises(InvalidPairingCodeError):
        repo.associate_vehicle(
            user_id=str(ObjectId()),
            vehicle_id="XEV9S-001",
            pairing_code_hash="invalid_hash",
        )

    associations.insert_one.assert_not_called()


def test_associate_vehicle_already_associated(repo, mock_collections):
    vehicles, associations = mock_collections
    associations.find_one.return_value = {
        "vehicle_id": "XEV9S-001"
    }

    with pytest.raises(VehicleAlreadyAssociatedError):
        repo.associate_vehicle(
            user_id=str(ObjectId()),
            vehicle_id="XEV9S-001",
            pairing_code_hash="valid_hash",
        )

    vehicles.find_one_and_update.assert_not_called()
    associations.insert_one.assert_not_called()


def test_associate_vehicle_duplicate_insert(repo, mock_collections):
    vehicles, associations = mock_collections
    vehicles.find_one_and_update.return_value = {
        "vehicle_id": "XEV9S-001"
    }
    associations.insert_one.side_effect = DuplicateKeyError(
        "Duplicate association"
    )

    with pytest.raises(VehicleAlreadyAssociatedError):
        repo.associate_vehicle(
            user_id=str(ObjectId()),
            vehicle_id="XEV9S-001",
            pairing_code_hash="valid_hash",
        )


def test_get_user_vehicles_returns_associations(repo, mock_collections):
    vehicles, associations = mock_collections
    user_id = str(ObjectId())

    vehicle_association = {
        "user_id": ObjectId(user_id),
        "vehicle_id": "XEV9S-001",
        "association_status": "active",
        "associated_at": MagicMock(),
    }

    associations.find.return_value.sort.return_value = [
        vehicle_association
    ]
    vehicles.find.return_value = [
        {
            "vehicle_id": "XEV9S-001",
            "model": "XEV 9S",
        }
    ]

    result = repo.get_user_vehicles(user_id)

    assert len(result) == 1
    assert result[0]["vehicle_id"] == "XEV9S-001"
    assert result[0]["model"] == "XEV 9S"
    assert result[0]["association_status"] == "active"

    associations.find.assert_called_once_with(
        {
            "user_id": ObjectId(user_id),
            "association_status": "active",
        }
    )
    associations.find.return_value.sort.assert_called_once_with(
        "associated_at", -1
    )


def test_get_user_vehicles_empty_list(repo, mock_collections):
    vehicles, associations = mock_collections
    associations.find.return_value.sort.return_value = []

    result = repo.get_user_vehicles(str(ObjectId()))

    assert result == []
    vehicles.find.assert_not_called()


def test_get_user_vehicles_invalid_user_id(repo, mock_collections):
    _vehicles, associations = mock_collections

    with pytest.raises(ValueError, match="Invalid user identifier"):
        repo.get_user_vehicles("invalid")

    associations.find.assert_not_called()

def test_get_user_vehicles_excludes_inactive_associations(
    repo,
    mock_collections,
):
    _, associations = mock_collections
    user_id = str(ObjectId())

    associations.find.return_value.sort.return_value = []

    result = repo.get_user_vehicles(user_id)

    assert result == []

    associations.find.assert_called_once_with(
        {
            "user_id": ObjectId(user_id),
            "association_status": "active",
        }
    )

def test_get_active_vehicle_by_id(repo, mock_collections):
    vehicles, _ = mock_collections
    expected_vehicle = {
        "vehicle_id": "XEV9S-001",
        "is_active": True,
    }
    vehicles.find_one.return_value = expected_vehicle

    result = repo.get_active_vehicle_by_id("XEV9S-001")

    assert result == expected_vehicle
    vehicles.find_one.assert_called_once_with(
        {
            "vehicle_id": "XEV9S-001",
            "is_active": True,
        }
    )

def test_get_active_vehicle_by_id_not_found(repo, mock_collections):
    vehicles, _ = mock_collections
    vehicles.find_one.return_value = None

    result = repo.get_active_vehicle_by_id("XEV9S-001")

    assert result is None
