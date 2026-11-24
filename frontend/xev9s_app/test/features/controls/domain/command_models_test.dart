import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('CommandType Enum', () {
    test('toApi and fromApi wire conversion', () {
      expect(CommandType.lock.toApi(), 'LOCK');
      expect(CommandType.unlock.toApi(), 'UNLOCK');
      expect(CommandType.startPreconditioning.toApi(), 'START_PRECONDITIONING');
      expect(CommandType.stopPreconditioning.toApi(), 'STOP_PRECONDITIONING');
      expect(CommandType.unknown.toApi(), 'UNKNOWN');

      expect(CommandType.fromApi('LOCK'), CommandType.lock);
      expect(CommandType.fromApi('unlock'), CommandType.unlock);
      expect(CommandType.fromApi('START_PRECONDITIONING'),
          CommandType.startPreconditioning);
      expect(CommandType.fromApi('stop_preconditioning'),
          CommandType.stopPreconditioning);
      expect(CommandType.fromApi('NON_EXISTENT'), CommandType.unknown);
      expect(CommandType.fromApi(null), CommandType.unknown);
      expect(CommandType.fromApi(''), CommandType.unknown);
    });

    test('human labels', () {
      expect(CommandType.lock.label, 'Lock');
      expect(CommandType.unlock.label, 'Unlock');
      expect(CommandType.startPreconditioning.label, 'Start climate');
      expect(CommandType.stopPreconditioning.label, 'Stop climate');
      expect(CommandType.unknown.label, 'Unknown');
    });
  });

  group('CommandStatus Enum', () {
    test('toApi, fromApi, isFinal, rank and label', () {
      expect(CommandStatus.submitted.toApi(), 'SUBMITTED');
      expect(CommandStatus.accepted.toApi(), 'ACCEPTED');
      expect(CommandStatus.executing.toApi(), 'EXECUTING');
      expect(CommandStatus.succeeded.toApi(), 'SUCCEEDED');
      expect(CommandStatus.failed.toApi(), 'FAILED');
      expect(CommandStatus.timedOut.toApi(), 'TIMED_OUT');
      expect(CommandStatus.unknown.toApi(), 'UNKNOWN');

      expect(CommandStatus.fromApi('SUBMITTED'), CommandStatus.submitted);
      expect(CommandStatus.fromApi('accepted'), CommandStatus.accepted);
      expect(CommandStatus.fromApi('EXECUTING'), CommandStatus.executing);
      expect(CommandStatus.fromApi('SUCCEEDED'), CommandStatus.succeeded);
      expect(CommandStatus.fromApi('failed'), CommandStatus.failed);
      expect(CommandStatus.fromApi('TIMED_OUT'), CommandStatus.timedOut);
      expect(CommandStatus.fromApi('OTHER'), CommandStatus.unknown);
      expect(CommandStatus.fromApi(null), CommandStatus.unknown);

      expect(CommandStatus.submitted.isFinal, isFalse);
      expect(CommandStatus.accepted.isFinal, isFalse);
      expect(CommandStatus.executing.isFinal, isFalse);
      expect(CommandStatus.succeeded.isFinal, isTrue);
      expect(CommandStatus.failed.isFinal, isTrue);
      expect(CommandStatus.timedOut.isFinal, isTrue);
      expect(CommandStatus.unknown.isFinal, isFalse);

      expect(CommandStatus.submitted.rank, 0);
      expect(CommandStatus.accepted.rank, 1);
      expect(CommandStatus.executing.rank, 2);
      expect(CommandStatus.succeeded.rank, 3);
      expect(CommandStatus.failed.rank, 3);
      expect(CommandStatus.timedOut.rank, 3);
      expect(CommandStatus.unknown.rank, -1);
    });
  });

  group('Command Model', () {
    final now = DateTime.parse('2026-11-24T12:00:00Z');

    test('parses complete valid json', () {
      final json = {
        'commandId': 'cmd_7731',
        'vehicleId': 'veh_9S0001',
        'commandType': 'LOCK',
        'status': 'SUCCEEDED',
        'requestedAt': '2026-11-24T12:00:00Z',
        'completedAt': '2026-11-24T12:00:03Z',
        'failureReason': null,
        'resultingState': {
          'lockState': 'LOCKED',
          'preconditioningState': 'INACTIVE',
        },
      };

      final cmd = Command.fromJson(json);
      expect(cmd.commandId, 'cmd_7731');
      expect(cmd.vehicleId, 'veh_9S0001');
      expect(cmd.commandType, CommandType.lock);
      expect(cmd.status, CommandStatus.succeeded);
      expect(cmd.requestedAt, now);
      expect(cmd.completedAt, DateTime.parse('2026-11-24T12:00:03Z'));
      expect(cmd.failureReason, isNull);
      expect(cmd.resultingState?.lockState, LockState.locked);
      expect(cmd.resultingState?.preconditioningState,
          PreconditioningState.inactive);
    });

    test('tolerates unknown enum strings without throwing', () {
      final json = {
        'commandId': 'cmd_9999',
        'vehicleId': 'veh_9S0001',
        'commandType': 'HONK_HORN',
        'status': 'PROCESSING',
        'requestedAt': '2026-11-24T12:00:00Z',
      };

      final cmd = Command.fromJson(json);
      expect(cmd.commandType, CommandType.unknown);
      expect(cmd.status, CommandStatus.unknown);
    });

    test('throws FormatException on missing required fields', () {
      // Missing commandId
      expect(
        () => Command.fromJson({
          'vehicleId': 'veh_1',
          'commandType': 'LOCK',
          'status': 'SUBMITTED',
          'requestedAt': '2026-11-24T12:00:00Z',
        }),
        throwsFormatException,
      );

      // Missing vehicleId
      expect(
        () => Command.fromJson({
          'commandId': 'cmd_1',
          'commandType': 'LOCK',
          'status': 'SUBMITTED',
          'requestedAt': '2026-11-24T12:00:00Z',
        }),
        throwsFormatException,
      );

      // Missing commandType
      expect(
        () => Command.fromJson({
          'commandId': 'cmd_1',
          'vehicleId': 'veh_1',
          'status': 'SUBMITTED',
          'requestedAt': '2026-11-24T12:00:00Z',
        }),
        throwsFormatException,
      );

      // Missing status
      expect(
        () => Command.fromJson({
          'commandId': 'cmd_1',
          'vehicleId': 'veh_1',
          'commandType': 'LOCK',
          'requestedAt': '2026-11-24T12:00:00Z',
        }),
        throwsFormatException,
      );

      // Missing requestedAt
      expect(
        () => Command.fromJson({
          'commandId': 'cmd_1',
          'vehicleId': 'veh_1',
          'commandType': 'LOCK',
          'status': 'SUBMITTED',
        }),
        throwsFormatException,
      );

      // Invalid requestedAt
      expect(
        () => Command.fromJson({
          'commandId': 'cmd_1',
          'vehicleId': 'veh_1',
          'commandType': 'LOCK',
          'status': 'SUBMITTED',
          'requestedAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('toJson and copyWith operate properly', () {
      final cmd = Command(
        commandId: 'cmd_1',
        vehicleId: 'veh_1',
        commandType: CommandType.unlock,
        status: CommandStatus.executing,
        requestedAt: now,
      );

      final copy = cmd.copyWith(status: CommandStatus.succeeded);
      expect(copy.status, CommandStatus.succeeded);
      expect(copy.commandId, 'cmd_1');

      final json = copy.toJson();
      expect(json['commandId'], 'cmd_1');
      expect(json['status'], 'SUCCEEDED');
      expect(json['commandType'], 'UNLOCK');
    });
  });
}
