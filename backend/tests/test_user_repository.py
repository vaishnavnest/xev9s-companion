from unittest.mock import MagicMock

import pytest
from backend.app.models.user import create_user_document
from backend.app.repositories.user_repository import UserRepository
from bson import ObjectId
from pymongo.errors import DuplicateKeyError


@pytest.fixture
def mock_collection():
    return MagicMock()


@pytest.fixture
def repo(mock_collection):
    return UserRepository(mock_collection)


def test_create_user_document_fields():
    doc = create_user_document(
        email="  Test.User@Example.COM  ",
        full_name="  Test User  ",
        password_hash="hashed_secret",
    )
    assert doc["email"] == "test.user@example.com"
    assert doc["full_name"] == "Test User"
    assert doc["password_hash"] == "hashed_secret"
    assert doc["is_active"] is True
    assert doc["created_at"] is not None
    assert doc["updated_at"] is not None


def test_create_user_success(repo, mock_collection):
    fake_id = ObjectId()
    mock_collection.insert_one.return_value = MagicMock(inserted_id=fake_id)

    user = repo.create_user(
        email="newuser@example.com",
        full_name="New User",
        password_hash="hashed_pw",
    )

    assert user["_id"] == fake_id
    assert user["email"] == "newuser@example.com"
    mock_collection.insert_one.assert_called_once()


def test_create_user_duplicate_email(repo, mock_collection):
    mock_collection.insert_one.side_effect = DuplicateKeyError(
        "E11000 duplicate key error"
    )

    with pytest.raises(ValueError, match="An account with this email already exists"):
        repo.create_user(
            email="existing@example.com",
            full_name="Existing User",
            password_hash="hashed_pw",
        )


def test_get_user_by_email_found(repo, mock_collection):
    expected_user = {"email": "user@example.com", "full_name": "User"}
    mock_collection.find_one.return_value = expected_user

    user = repo.get_user_by_email("  User@Example.com  ")
    assert user == expected_user
    mock_collection.find_one.assert_called_once_with({"email": "user@example.com"})


def test_get_user_by_email_not_found(repo, mock_collection):
    mock_collection.find_one.return_value = None

    user = repo.get_user_by_email("unknown@example.com")
    assert user is None
    mock_collection.find_one.assert_called_once_with({"email": "unknown@example.com"})


def test_get_user_by_id_valid_object_id(repo, mock_collection):
    valid_id = str(ObjectId())
    expected_user = {"_id": ObjectId(valid_id), "email": "user@example.com"}
    mock_collection.find_one.return_value = expected_user

    user = repo.get_user_by_id(valid_id)
    assert user == expected_user
    mock_collection.find_one.assert_called_once_with({"_id": ObjectId(valid_id)})


def test_get_user_by_id_invalid_object_id(repo, mock_collection):
    user = repo.get_user_by_id("invalid-not-an-objectid")
    assert user is None
    mock_collection.find_one.assert_not_called()


def test_get_user_by_id_not_found(repo, mock_collection):
    valid_id = str(ObjectId())
    mock_collection.find_one.return_value = None

    user = repo.get_user_by_id(valid_id)
    assert user is None
    mock_collection.find_one.assert_called_once_with({"_id": ObjectId(valid_id)})
