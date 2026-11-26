import pytest
from backend.app.core import security
from backend.app.core.security import hash_pairing_code


def test_hash_pairing_code_valid(monkeypatch):
    monkeypatch.setattr(
        security,
        "VEHICLE_PAIRING_PEPPER",
        "test_pepper_value_32_characters_minimum_valid",
    )

    code = "XEV482913"
    result = hash_pairing_code(code)

    assert isinstance(result, str)
    assert len(result) == 64
    assert result == hash_pairing_code(code)
    assert result != hash_pairing_code("XEV735192")


def test_hash_pairing_code_missing_pepper(monkeypatch):
    monkeypatch.setattr(security, "VEHICLE_PAIRING_PEPPER", None)

    with pytest.raises(
        RuntimeError,
        match="A valid VEHICLE_PAIRING_PEPPER must be configured",
    ):
        hash_pairing_code("XEV123456")


def test_hash_pairing_code_empty_pepper(monkeypatch):
    monkeypatch.setattr(security, "VEHICLE_PAIRING_PEPPER", "")

    with pytest.raises(
        RuntimeError,
        match="A valid VEHICLE_PAIRING_PEPPER must be configured",
    ):
        hash_pairing_code("XEV123456")


def test_hash_pairing_code_short_pepper(monkeypatch):
    monkeypatch.setattr(
        security,
        "VEHICLE_PAIRING_PEPPER",
        "short_pepper_under_32_chars",
    )

    with pytest.raises(
        RuntimeError,
        match="A valid VEHICLE_PAIRING_PEPPER must be configured",
    ):
        hash_pairing_code("XEV123456")
