import 'package:equatable/equatable.dart';
import '../../../core/network/api_exception.dart';
import '../domain/command.dart';
import '../domain/command_type.dart';

/// Execution phases of a remote command within the tracker session.
enum CommandPhase {
  idle,
  submitting,
  tracking,
  finished,
  submitUnconfirmed,
}

/// State tracking an ongoing or recently completed remote vehicle command.
class CommandSession extends Equatable {
  const CommandSession({
    this.command,
    this.phase = CommandPhase.idle,
    this.idempotencyKey,
    this.startedAt,
    this.error,
    this.waitingTooLong = false,
    this.refreshFailed = false,
    this.stoppedWaiting = false,
    this.lastAttemptedType,
  });

  final Command? command;
  final CommandPhase phase;
  final String? idempotencyKey;
  final DateTime? startedAt;
  final AppError? error;
  final bool waitingTooLong;
  final bool refreshFailed;
  final bool stoppedWaiting;
  final CommandType? lastAttemptedType;

  CommandSession copyWith({
    Command? command,
    CommandPhase? phase,
    String? idempotencyKey,
    DateTime? startedAt,
    AppError? error,
    bool clearError = false,
    bool? waitingTooLong,
    bool? refreshFailed,
    bool? stoppedWaiting,
    CommandType? lastAttemptedType,
  }) {
    return CommandSession(
      command: command ?? this.command,
      phase: phase ?? this.phase,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      startedAt: startedAt ?? this.startedAt,
      error: clearError ? null : (error ?? this.error),
      waitingTooLong: waitingTooLong ?? this.waitingTooLong,
      refreshFailed: refreshFailed ?? this.refreshFailed,
      stoppedWaiting: stoppedWaiting ?? this.stoppedWaiting,
      lastAttemptedType: lastAttemptedType ?? this.lastAttemptedType,
    );
  }

  @override
  List<Object?> get props => [
        command,
        phase,
        idempotencyKey,
        startedAt,
        error,
        waitingTooLong,
        refreshFailed,
        stoppedWaiting,
        lastAttemptedType,
      ];
}
