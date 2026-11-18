
import pytest
from backend.app.schemas.vehicle import VehicleAssociationRequest
from pydantic import ValidationError


def test_valid_vehicle_association_request():
    request = VehicleAssociationRequest(
        vehicle_id=" XEV9S-001 ",
        pairing_code=" TEST-CODE-123 ",
    )

    assert request.vehicle_id == "XEV9S-001"
    assert request.pairing_code == "TEST-CODE-123"


@pytest.mark.parametrize(
    "vehicle_id",
    ["", "   "],
)
def test_invalid_vehicle_identifier(vehicle_id):
    with pytest.raises(ValidationError):
        VehicleAssociationRequest(
            vehicle_id=vehicle_id,
            pairing_code="TEST-CODE-123",
        )


@pytest.mark.parametrize(
    "pairing_code",
    ["", "   "],
)
def test_invalid_pairing_code(pairing_code):
    with pytest.raises(ValidationError):
        VehicleAssociationRequest(
            vehicle_id="XEV9S-001",
            pairing_code=pairing_code,
        )


def test_extra_fields_rejected():
    with pytest.raises(ValidationError):
        VehicleAssociationRequest(
            vehicle_id="XEV9S-001",
            pairing_code="TEST-CODE-123",
            unexpected_field="not-allowed",
        )


def test_vehicle_identifier_maximum_length():
    with pytest.raises(ValidationError):
        VehicleAssociationRequest(
            vehicle_id="V" * 65,
            pairing_code="TEST-CODE-123",
        )


def test_pairing_code_maximum_length():
    with pytest.raises(ValidationError):
        VehicleAssociationRequest(
            vehicle_id="XEV9S-001",
            pairing_code="C" * 129,
        )
