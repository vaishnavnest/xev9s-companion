class InvalidPairingCodeError(Exception):
    """Raised when a vehicle pairing code is invalid, expired, or used."""


class VehicleAlreadyAssociatedError(Exception):
    """Raised when a vehicle is already associated with the user's account."""


class VehicleNotActiveError(Exception):
    """Raised when telemetry comes from an unknown or inactive vehicle."""


class VehicleAccessDeniedError(Exception):
    """Raised when a user attempts to access another user's vehicle data."""

class VehicleOfflineError(Exception):
    """Raised when a remote command targets an offline vehicle."""


class CommandNotFoundError(Exception):
    """Raised when a requested vehicle command does not exist."""


class MQTTUnavailableError(Exception):
    """Raised when the MQTT broker cannot accept a command."""


class InvalidCommandResponseError(Exception):
    """Raised when a simulator response does not match its command."""