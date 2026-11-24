import '../../../core/utils/formatters.dart';
import '../../vehicles/domain/vehicle_status.dart';
import '../domain/command.dart';
import '../domain/command_status.dart';
import '../domain/command_type.dart';

/// Configuration for user confirmation dialogs prior to command dispatch.
class ConfirmDialogConfig {
  const ConfirmDialogConfig({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
}

/// Pure presentation view model and formatting logic for UC-05 Remote Controls.
class ControlsViewModel {
  const ControlsViewModel._();

  /// Builds confirmation dialog text per UC-05 specifications.
  static ConfirmDialogConfig confirmConfigFor(CommandType type) {
    switch (type) {
      case CommandType.lock:
        return const ConfirmDialogConfig(
          title: 'Lock the vehicle?',
          message: 'The vehicle will be locked.',
          confirmLabel: 'Confirm',
        );
      case CommandType.unlock:
        return const ConfirmDialogConfig(
          title: 'Unlock the vehicle?',
          message:
              'Anyone nearby will be able to open it. Only unlock if you are with the vehicle.',
          confirmLabel: 'Unlock',
        );
      case CommandType.startPreconditioning:
        return const ConfirmDialogConfig(
          title: 'Start climate control?',
          message: 'The cabin will be pre-conditioned.',
          confirmLabel: 'Confirm',
        );
      case CommandType.stopPreconditioning:
        return const ConfirmDialogConfig(
          title: 'Stop climate control?',
          message: 'Climate control will be stopped.',
          confirmLabel: 'Confirm',
        );
      case CommandType.unknown:
        return const ConfirmDialogConfig(
          title: 'Submit command?',
          message: 'Are you sure you want to proceed?',
          confirmLabel: 'Confirm',
        );
    }
  }

  /// Success card header derived from command type.
  static String successTitle(CommandType type) {
    switch (type) {
      case CommandType.lock:
        return 'Vehicle locked';
      case CommandType.unlock:
        return 'Vehicle unlocked';
      case CommandType.startPreconditioning:
        return 'Climate control started';
      case CommandType.stopPreconditioning:
        return 'Climate control stopped';
      case CommandType.unknown:
        return 'Command succeeded';
    }
  }

  /// Lock state label for vehicle status card.
  static String lockStateLabel(LockState? state) {
    switch (state) {
      case LockState.locked:
        return 'Locked';
      case LockState.unlocked:
        return 'Unlocked';
      default:
        return Formatters.nullPlaceholder;
    }
  }

  /// Climate state label for vehicle status card.
  static String climateStateLabel(PreconditioningState? state) {
    switch (state) {
      case PreconditioningState.active:
        return 'Climate on';
      case PreconditioningState.inactive:
        return 'Climate off';
      default:
        return Formatters.nullPlaceholder;
    }
  }

  /// Progress indicator step index (0: Submitted, 1: Accepted, 2: Executing, 3: Result).
  static int progressStepIndex(CommandStatus status) {
    switch (status) {
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
        return 0;
    }
  }

  /// Elapsed time timer string format (mm:ss).
  static String formatElapsed(int totalSeconds) {
    if (totalSeconds < 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Completed time label in command history list items.
  static String completedTimeLabel(Command command) {
    if (!command.status.isFinal) {
      return 'In progress';
    }
    if (command.completedAt != null) {
      return Formatters.formatDateTime(command.completedAt);
    }
    return Formatters.nullPlaceholder;
  }
}
