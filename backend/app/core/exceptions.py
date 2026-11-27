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


class ChargingSessionNotFoundError(Exception):
    """Raised when a charging session cannot be found."""


class InvalidChargingTransitionError(Exception):
    """Raised when a charging event violates lifecycle rules."""


class DuplicateChargingEventError(Exception):
    """Raised when a charging event has already been processed."""


class ChargingSessionAlreadyActiveError(Exception):
    """Raised when a vehicle already has an active charging session."""


class TripNotFoundError(Exception):
    """Raised when a requested trip cannot be found."""


class TripAlreadyActiveError(Exception):
    """Raised when an active trip already exists for a vehicle."""


class InvalidTripTransitionError(Exception):
    """Raised when a trip state transition violates lifecycle rules."""
