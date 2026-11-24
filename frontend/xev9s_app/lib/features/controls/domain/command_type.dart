/// Types of remote vehicle commands supported by UC-05.
enum CommandType {
  lock,
  unlock,
  startPreconditioning,
  stopPreconditioning,
  unknown;

  /// Serializes the enum to the OpenAPI wire format.
  String toApi() {
    switch (this) {
      case CommandType.lock:
        return 'LOCK';
      case CommandType.unlock:
        return 'UNLOCK';
      case CommandType.startPreconditioning:
        return 'START_PRECONDITIONING';
      case CommandType.stopPreconditioning:
        return 'STOP_PRECONDITIONING';
      case CommandType.unknown:
        return 'UNKNOWN';
    }
  }

  /// Parses wire strings safely without throwing on unknown values.
  static CommandType fromApi(String? value) {
    if (value == null || value.trim().isEmpty) return CommandType.unknown;
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'LOCK':
        return CommandType.lock;
      case 'UNLOCK':
        return CommandType.unlock;
      case 'START_PRECONDITIONING':
        return CommandType.startPreconditioning;
      case 'STOP_PRECONDITIONING':
        return CommandType.stopPreconditioning;
      default:
        return CommandType.unknown;
    }
  }

  /// Human-readable label for UI controls and cards.
  String get label {
    switch (this) {
      case CommandType.lock:
        return 'Lock';
      case CommandType.unlock:
        return 'Unlock';
      case CommandType.startPreconditioning:
        return 'Start climate';
      case CommandType.stopPreconditioning:
        return 'Stop climate';
      case CommandType.unknown:
        return 'Unknown';
    }
  }
}
