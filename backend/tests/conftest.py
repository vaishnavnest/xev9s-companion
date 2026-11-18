
from unittest.mock import MagicMock

import pytest
from backend.app.repositories.vehicle_repository import VehicleRepository


@pytest.fixture
def mock_collections():
    vehicles = MagicMock()
    associations = MagicMock()

    associations.find_one.return_value = None

    session = MagicMock()
    vehicles.database.client.start_session.return_value.__enter__.return_value = (
        session
    )

    return vehicles, associations


@pytest.fixture
def repo(mock_collections):
    vehicles, associations = mock_collections
    return VehicleRepository(vehicles, associations)
