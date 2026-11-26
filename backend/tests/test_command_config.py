
import importlib

import pytest
from backend.app.core import command_config


def test_timeout_settings_reject_non_positive_values(monkeypatch):
    with monkeypatch.context() as env:
        env.setenv("VEHICLE_ONLINE_TIMEOUT_SECONDS", "0")
        env.setenv("COMMAND_EXECUTION_TIMEOUT_SECONDS", "10")

        with pytest.raises(
            ValueError,
            match="VEHICLE_ONLINE_TIMEOUT_SECONDS must be positive",
        ):
            importlib.reload(command_config)

        env.setenv("VEHICLE_ONLINE_TIMEOUT_SECONDS", "30")
        env.setenv("COMMAND_EXECUTION_TIMEOUT_SECONDS", "-1")

        with pytest.raises(
            ValueError,
            match="COMMAND_EXECUTION_TIMEOUT_SECONDS must be positive",
        ):
            importlib.reload(command_config)

    # Restore the module using the original environment settings.
    importlib.reload(command_config)
