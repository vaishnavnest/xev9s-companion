class InvalidPairingCodeError(Exception):
    """Raised when a vehicle pairing code is invalid, expired, or used."""


class VehicleAlreadyAssociatedError(Exception):
    """Raised when a vehicle is already associated with the user's account."""
