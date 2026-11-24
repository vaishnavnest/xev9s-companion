import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_status_machine.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';

void main() {
  group('CommandStatusMachine', () {
    final t0 = DateTime.parse('2026-11-24T12:00:00Z');
    final t1 = DateTime.parse('2026-11-24T12:00:05Z');

    final base = Command(
      commandId: 'cmd_1',
      vehicleId: 'veh_1',
      commandType: CommandType.lock,
      status: CommandStatus.submitted,
      requestedAt: t0,
    );

    test('forward transitions advance the status', () {
      final accepted = base.copyWith(status: CommandStatus.accepted);
      final afterAccepted = CommandStatusMachine.apply(base, accepted);
      expect(afterAccepted.status, CommandStatus.accepted);

      final executing = accepted.copyWith(status: CommandStatus.executing);
      final afterExecuting =
          CommandStatusMachine.apply(afterAccepted, executing);
      expect(afterExecuting.status, CommandStatus.executing);

      final succeeded = executing.copyWith(
        status: CommandStatus.succeeded,
        completedAt: t1,
      );
      final afterSucceeded =
          CommandStatusMachine.apply(afterExecuting, succeeded);
      expect(afterSucceeded.status, CommandStatus.succeeded);
      expect(afterSucceeded.completedAt, t1);
    });

    test('backward transitions are strictly ignored', () {
      final executing = base.copyWith(status: CommandStatus.executing);
      final accepted = base.copyWith(status: CommandStatus.accepted);

      final result = CommandStatusMachine.apply(executing, accepted);
      expect(result.status, CommandStatus.executing);
    });

    test('late events after SUCCEEDED are completely ignored', () {
      final succeeded = base.copyWith(
        status: CommandStatus.succeeded,
        completedAt: t1,
      );
      final lateExecuting = base.copyWith(status: CommandStatus.executing);

      final result = CommandStatusMachine.apply(succeeded, lateExecuting);
      expect(result.status, CommandStatus.succeeded);
      expect(result.completedAt, t1);
    });

    test('late events after FAILED or TIMED_OUT are ignored', () {
      final failed = base.copyWith(
        status: CommandStatus.failed,
        failureReason: 'VEHICLE_DRIVING',
        completedAt: t1,
      );
      final lateAccepted = base.copyWith(status: CommandStatus.accepted);

      final resultFailed = CommandStatusMachine.apply(failed, lateAccepted);
      expect(resultFailed.status, CommandStatus.failed);
      expect(resultFailed.failureReason, 'VEHICLE_DRIVING');

      final timedOut = base.copyWith(
        status: CommandStatus.timedOut,
        completedAt: t1,
      );
      final resultTimedOut =
          CommandStatusMachine.apply(timedOut, lateAccepted);
      expect(resultTimedOut.status, CommandStatus.timedOut);
    });

    test('same status updates incoming fields and preserves requestedAt', () {
      final exec1 = base.copyWith(status: CommandStatus.executing);
      final exec2 = base.copyWith(
        status: CommandStatus.executing,
        failureReason: 'Pending confirmation',
      );

      final result = CommandStatusMachine.apply(exec1, exec2);
      expect(result.status, CommandStatus.executing);
      expect(result.failureReason, 'Pending confirmation');
      expect(result.requestedAt, t0);
    });
  });
}
