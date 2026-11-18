
import pytest
from bson import ObjectId


def test_is_vehicle_associated_with_user_returns_true(
    repo, mock_collections
):
    _vehicles, associations = mock_collections
    user_id = str(ObjectId())

    associations.find_one.return_value = {"_id": ObjectId()}

    result = repo.is_vehicle_associated_with_user(
        user_id=user_id,
        vehicle_id="XEV9S-001",
    )

    assert result is True
    associations.find_one.assert_called_once_with(
        {
            "user_id": ObjectId(user_id),
            "vehicle_id": "XEV9S-001",
            "association_status": "active",
        },
        {"_id": 1},
    )


def test_is_vehicle_associated_with_user_returns_false(
    repo, mock_collections
):
    _vehicles, associations = mock_collections
    associations.find_one.return_value = None

    result = repo.is_vehicle_associated_with_user(
        user_id=str(ObjectId()),
        vehicle_id="XEV9S-001",
    )

    assert result is False


def test_is_vehicle_associated_with_user_ignores_inactive_association(
    repo, mock_collections
):
    _vehicles, associations = mock_collections

    def find_active_association(query, projection):
        assert query["association_status"] == "active"

    associations.find_one.side_effect = find_active_association

    result = repo.is_vehicle_associated_with_user(
        user_id=str(ObjectId()),
        vehicle_id="XEV9S-001",
    )

    assert result is False


def test_is_vehicle_associated_with_user_invalid_user_id(
    repo, mock_collections
):
    _vehicles, associations = mock_collections

    with pytest.raises(ValueError, match="Invalid user identifier"):
        repo.is_vehicle_associated_with_user(
            user_id="invalid",
            vehicle_id="XEV9S-001",
        )

    associations.find_one.assert_not_called()
