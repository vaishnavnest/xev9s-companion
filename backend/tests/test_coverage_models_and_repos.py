from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock

import pytest
from backend.app.models.vehicle import create_vehicle_document
from backend.app.repositories.command_repository import CommandRepository
from backend.app.repositories.vehicle_repository import VehicleRepository
from pymongo.errors import DuplicateKeyError


def test_create_vehicle_document_fields():
    expiry = datetime.now(UTC) + timedelta(minutes=30)
    doc = create_vehicle_document(
        vehicle_id="  XEV9S000001  ",
        model="  XEV 9S  ",
        pairing_code_hash="sample_hash_123",
        pairing_expires_at=expiry,
    )

    assert doc["vehicle_id"] == "XEV9S000001"
    assert doc["model"] == "XEV 9S"
    assert doc["pairing_code_hash"] == "sample_hash_123"
    assert doc["pairing_expires_at"] == expiry
    assert doc["is_active"] is True
    assert isinstance(doc["created_at"], datetime)
    assert isinstance(doc["updated_at"], datetime)


def test_vehicle_repository_register_vehicle_success():
    expiry = datetime.now(UTC) + timedelta(minutes=30)
    vehicles_col = MagicMock()
    vehicles_col.insert_one.return_value = MagicMock(inserted_id="mock_id_001")
    associations_col = MagicMock()

    repo = VehicleRepository(vehicles_col, associations_col)
    result = repo.register_vehicle(
        vehicle_id="XEV9S000001",
        model="XEV 9S",
        pairing_code_hash="hash_abc",
        pairing_expires_at=expiry,
    )

    assert result["_id"] == "mock_id_001"
    assert result["vehicle_id"] == "XEV9S000001"
    vehicles_col.insert_one.assert_called_once()


def test_vehicle_repository_register_vehicle_duplicate_error():
    expiry = datetime.now(UTC) + timedelta(minutes=30)
    vehicles_col = MagicMock()
    vehicles_col.insert_one.side_effect = DuplicateKeyError("Duplicate")
    associations_col = MagicMock()

    repo = VehicleRepository(vehicles_col, associations_col)
    with pytest.raises(ValueError, match="Vehicle identifier already exists"):
        repo.register_vehicle(
            vehicle_id="XEV9S000001",
            model="XEV 9S",
            pairing_code_hash="hash_abc",
            pairing_expires_at=expiry,
        )


def test_vehicle_repository_get_vehicle_by_id():
    vehicles_col = MagicMock()
    expected = {"vehicle_id": "XEV9S000001", "model": "XEV 9S"}
    vehicles_col.find_one.return_value = expected

    repo = VehicleRepository(vehicles_col, MagicMock())
    result = repo.get_vehicle_by_id("XEV9S000001")

    assert result == expected
    vehicles_col.find_one.assert_called_once_with({"vehicle_id": "XEV9S000001"})


def test_command_repository_get_command_for_response():
    collection = MagicMock()
    expected = {"command_id": "cmd-01", "vehicle_id": "XEV-01"}
    collection.find_one.return_value = expected

    repo = CommandRepository(collection)
    result = repo.get_command_for_response("cmd-01", "XEV-01")

    assert result == expected
    collection.find_one.assert_called_once_with(
        {"command_id": "cmd-01", "vehicle_id": "XEV-01"},
        {"_id": 0},
    )
