import 'command.dart';

/// Pure status machine handling lifecycle transitions for commands (UC-05).
class CommandStatusMachine {
  const CommandStatusMachine._();

  /// Applies an [incoming] command update to the [current] command state.
  ///
  /// Non-negotiable rules:
  /// - If [current] is final (SUCCEEDED, FAILED, TIMED_OUT) -> return [current] unchanged (late events ignored).
  /// - If [incoming].rank < [current].rank -> return [current] (never move backwards).
  /// - Otherwise return [incoming] (preserving [current].requestedAt if [incoming] lacks it).
  static Command apply(Command current, Command incoming) {
    if (current.status.isFinal) {
      return current;
    }

    if (incoming.status.rank < current.status.rank) {
      return current;
    }

    return incoming.copyWith(
      requestedAt: incoming.requestedAt,
    );
  }
}
