/// Execution lifecycle status of a remote vehicle command.
enum CommandStatus {
  submitted,
  accepted,
  executing,
  succeeded,
  failed,
  timedOut,
  unknown;

  /// Serializes to the wire string specified in OpenAPI.
  String toApi() {
    switch (this) {
      case CommandStatus.submitted:
        return 'SUBMITTED';
      case CommandStatus.accepted:
        return 'ACCEPTED';
      case CommandStatus.executing:
        return 'EXECUTING';
      case CommandStatus.succeeded:
        return 'SUCCEEDED';
      case CommandStatus.failed:
        return 'FAILED';
      case CommandStatus.timedOut:
        return 'TIMED_OUT';
      case CommandStatus.unknown:
        return 'UNKNOWN';
    }
  }

  /// Parses wire strings safely without throwing on unknown values.
  static CommandStatus fromApi(String? value) {
    if (value == null || value.trim().isEmpty) return CommandStatus.unknown;
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'SUBMITTED':
        return CommandStatus.submitted;
      case 'ACCEPTED':
        return CommandStatus.accepted;
      case 'EXECUTING':
        return CommandStatus.executing;
      case 'SUCCEEDED':
        return CommandStatus.succeeded;
      case 'FAILED':
        return CommandStatus.failed;
      case 'TIMED_OUT':
        return CommandStatus.timedOut;
      default:
        return CommandStatus.unknown;
    }
  }

  /// Whether the command has completed its lifecycle.
  bool get isFinal =>
      this == CommandStatus.succeeded ||
      this == CommandStatus.failed ||
      this == CommandStatus.timedOut;

  /// Lifecycle rank ensuring status machine moves strictly forward.
  int get rank {
    switch (this) {
      case CommandStatus.submitted:
        return 0;
      case CommandStatus.accepted:
        return 1;
      case CommandStatus.executing:
        return 2;
      case CommandStatus.succeeded:
      case CommandStatus.failed:
      case CommandStatus.timedOut:
        return 3;
      case CommandStatus.unknown:
        return -1;
    }
  }

  /// User-facing status label.
  String get label {
    switch (this) {
      case CommandStatus.submitted:
        return 'Submitted';
      case CommandStatus.accepted:
        return 'Accepted';
      case CommandStatus.executing:
        return 'Executing';
      case CommandStatus.succeeded:
        return 'Succeeded';
      case CommandStatus.failed:
        return 'Failed';
      case CommandStatus.timedOut:
        return 'Timed out';
      case CommandStatus.unknown:
        return 'Unknown';
    }
  }
}
