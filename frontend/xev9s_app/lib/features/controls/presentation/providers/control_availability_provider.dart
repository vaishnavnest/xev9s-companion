import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../vehicles/application/vehicle_status_provider.dart';
import '../../../vehicles/selected_vehicle_provider.dart';
import '../../application/command_session.dart';
import '../../application/command_tracker_provider.dart';
import '../../domain/command.dart';
import '../../domain/command_status.dart';
import '../../domain/command_type.dart';
import '../../domain/control_availability.dart';

/// Provider combining vehicle status and active command session to determine
/// button enablement and explanatory advisory text (UC-05).
final controlAvailabilityProvider = Provider<ControlAvailability>((ref) {
  final statusAsync = ref.watch(vehicleStatusProvider);
  final vehicleId = ref.watch(selectedVehicleProvider);
  final trackerMap = ref.watch(commandTrackerProvider);

  final session = vehicleId != null ? trackerMap[vehicleId] : null;
  final isCommandActive = session != null &&
      (session.phase == CommandPhase.submitting ||
          session.phase == CommandPhase.tracking);

  final activeCommand = isCommandActive
      ? (session.command ??
          Command(
            commandId: 'pending',
            vehicleId: vehicleId ?? '',
            commandType: session.lastAttemptedType ?? CommandType.unknown,
            status: CommandStatus.submitted,
            requestedAt: session.startedAt ?? DateTime.now(),
          ))
      : null;

  final status = statusAsync.value;
  if (status == null) {
    return const ControlAvailability(
      canLock: false,
      canUnlock: false,
      canStartClimate: false,
      canStopClimate: false,
      disabledReason: 'State unavailable.',
      lockDisabledReason: 'State unavailable.',
      climateDisabledReason: 'State unavailable.',
    );
  }

  return availableActions(status, activeCommand);
});
