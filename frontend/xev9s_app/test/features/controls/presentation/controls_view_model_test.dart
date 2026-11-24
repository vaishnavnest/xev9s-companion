import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/controls/presentation/controls_view_model.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('ControlsViewModel Presentation Logic', () {
    test('confirmConfigFor specifies exact titles and confirm labels', () {
      final lockConfig =
          ControlsViewModel.confirmConfigFor(CommandType.lock);
      expect(lockConfig.title, 'Lock the vehicle?');
      expect(lockConfig.message, 'The vehicle will be locked.');
      expect(lockConfig.confirmLabel, 'Confirm');

      final unlockConfig =
          ControlsViewModel.confirmConfigFor(CommandType.unlock);
      expect(unlockConfig.title, 'Unlock the vehicle?');
      expect(unlockConfig.message, contains('Anyone nearby'));
      expect(unlockConfig.confirmLabel, 'Unlock');

      final startClimate = ControlsViewModel.confirmConfigFor(
          CommandType.startPreconditioning);
      expect(startClimate.title, 'Start climate control?');
      expect(startClimate.message, 'The cabin will be pre-conditioned.');

      final stopClimate = ControlsViewModel.confirmConfigFor(
          CommandType.stopPreconditioning);
      expect(stopClimate.title, 'Stop climate control?');
    });

    test('successTitle generates user-friendly wording from CommandType', () {
      expect(ControlsViewModel.successTitle(CommandType.lock),
          'Vehicle locked');
      expect(ControlsViewModel.successTitle(CommandType.unlock),
          'Vehicle unlocked');
      expect(
          ControlsViewModel.successTitle(CommandType.startPreconditioning),
          'Climate control started');
      expect(
          ControlsViewModel.successTitle(CommandType.stopPreconditioning),
          'Climate control stopped');
      expect(ControlsViewModel.successTitle(CommandType.unknown),
          'Command succeeded');
    });

    test('lockStateLabel and climateStateLabel return "-" for null / unknown', () {
      expect(ControlsViewModel.lockStateLabel(LockState.locked), 'Locked');
      expect(ControlsViewModel.lockStateLabel(LockState.unlocked), 'Unlocked');
      expect(ControlsViewModel.lockStateLabel(LockState.unknown), '-');
      expect(ControlsViewModel.lockStateLabel(null), '-');

      expect(ControlsViewModel.climateStateLabel(PreconditioningState.active),
          'Climate on');
      expect(
          ControlsViewModel.climateStateLabel(PreconditioningState.inactive),
          'Climate off');
      expect(
          ControlsViewModel.climateStateLabel(PreconditioningState.unknown), '-');
      expect(ControlsViewModel.climateStateLabel(null), '-');
    });

    test('progressStepIndex maps lifecycle status strictly to 0..3', () {
      expect(ControlsViewModel.progressStepIndex(CommandStatus.submitted), 0);
      expect(ControlsViewModel.progressStepIndex(CommandStatus.accepted), 1);
      expect(ControlsViewModel.progressStepIndex(CommandStatus.executing), 2);
      expect(ControlsViewModel.progressStepIndex(CommandStatus.succeeded), 3);
      expect(ControlsViewModel.progressStepIndex(CommandStatus.failed), 3);
      expect(ControlsViewModel.progressStepIndex(CommandStatus.timedOut), 3);
      expect(ControlsViewModel.progressStepIndex(CommandStatus.unknown), 0);
    });

    test('formatElapsed formats mm:ss zero-padded', () {
      expect(ControlsViewModel.formatElapsed(0), '00:00');
      expect(ControlsViewModel.formatElapsed(5), '00:05');
      expect(ControlsViewModel.formatElapsed(65), '01:05');
      expect(ControlsViewModel.formatElapsed(600), '10:00');
      expect(ControlsViewModel.formatElapsed(-5), '00:00');
    });

    test('completedTimeLabel outputs "In progress" or formatted time and never null', () {
      final inProgressCmd = Command(
        commandId: 'c1',
        vehicleId: 'v1',
        commandType: CommandType.lock,
        status: CommandStatus.executing,
        requestedAt: DateTime.parse('2026-11-24T12:00:00Z'),
      );
      expect(
          ControlsViewModel.completedTimeLabel(inProgressCmd), 'In progress');

      final finalCompleted = inProgressCmd.copyWith(
        status: CommandStatus.succeeded,
        completedAt: DateTime.parse('2026-11-24T12:01:30Z'),
      );
      expect(ControlsViewModel.completedTimeLabel(finalCompleted),
          contains('2026'));

      final finalWithoutCompletedAt = inProgressCmd.copyWith(
        status: CommandStatus.timedOut,
        completedAt: null,
      );
      expect(
          ControlsViewModel.completedTimeLabel(finalWithoutCompletedAt), '-');
    });
  });
}
