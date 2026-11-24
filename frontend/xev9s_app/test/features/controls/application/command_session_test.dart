import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/controls/application/command_session.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';

void main() {
  final now = DateTime.parse('2026-11-24T12:00:00Z');

  group('CommandSession Model Tests', () {
    test('copyWith updates fields and preserves unmodified ones', () {
      final session = CommandSession(
        phase: CommandPhase.idle,
        idempotencyKey: 'key-1',
        startedAt: now,
        lastAttemptedType: CommandType.lock,
      );

      final updated = session.copyWith(
        phase: CommandPhase.submitting,
        waitingTooLong: true,
      );

      expect(updated.phase, CommandPhase.submitting);
      expect(updated.idempotencyKey, 'key-1');
      expect(updated.waitingTooLong, isTrue);
      expect(updated.lastAttemptedType, CommandType.lock);
    });

    test('copyWith clearError resets error', () {
      const error = AppError(
        code: ApiErrorCode.internalError,
        message: 'Failed',
        httpStatus: 500,
      );
      final session = CommandSession(
        phase: CommandPhase.finished,
        error: error,
      );

      expect(session.error, isNotNull);
      final cleared = session.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('props equality checks all properties correctly', () {
      final cmd = Command(
        commandId: 'cmd_1',
        vehicleId: 'veh_1',
        commandType: CommandType.lock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );

      final s1 = CommandSession(
        command: cmd,
        phase: CommandPhase.tracking,
        idempotencyKey: 'key-1',
        startedAt: now,
      );

      final s2 = CommandSession(
        command: cmd,
        phase: CommandPhase.tracking,
        idempotencyKey: 'key-1',
        startedAt: now,
      );

      expect(s1, equals(s2));
    });
  });
}
