import 'package:equatable/equatable.dart';
import '../../vehicles/domain/vehicle_status.dart';
import 'command.dart';

/// Availability status and user messaging for vehicle remote controls (UC-05).
class ControlAvailability extends Equatable {
  const ControlAvailability({
    required this.canLock,
    required this.canUnlock,
    required this.canStartClimate,
    required this.canStopClimate,
    this.disabledReason,
    this.lockDisabledReason,
    this.climateDisabledReason,
    this.drivingHint,
  });

  final bool canLock;
  final bool canUnlock;
  final bool canStartClimate;
  final bool canStopClimate;

  /// General disabled reason when all controls are unavailable.
  final String? disabledReason;

  /// Specific disabled reason for the lock/unlock pair.
  final String? lockDisabledReason;

  /// Specific disabled reason for the climate control pair.
  final String? climateDisabledReason;

  /// Non-blocking advisory hint when the vehicle is in motion.
  final String? drivingHint;

  @override
  List<Object?> get props => [
        canLock,
        canUnlock,
        canStartClimate,
        canStopClimate,
        disabledReason,
        lockDisabledReason,
        climateDisabledReason,
        drivingHint,
      ];
}

/// Pure function computing action availability for UC-05 based on vehicle status and active command.
ControlAvailability availableActions(VehicleStatus status, Command? active) {
  final isOffline = status.connectivity == VehicleConnectivity.offline ||
      status.vehicleState == VehicleState.offline;

  final drivingHint = status.vehicleState == VehicleState.driving
      ? 'Vehicle is driving. Remote commands may be rejected by the vehicle.'
      : null;

  if (isOffline) {
    const reason = 'Vehicle is offline. Controls are unavailable.';
    return const ControlAvailability(
      canLock: false,
      canUnlock: false,
      canStartClimate: false,
      canStopClimate: false,
      disabledReason: reason,
      lockDisabledReason: reason,
      climateDisabledReason: reason,
      drivingHint: null,
    );
  }

  if (active != null && !active.status.isFinal) {
    const reason = 'A command is in progress.';
    return ControlAvailability(
      canLock: false,
      canUnlock: false,
      canStartClimate: false,
      canStopClimate: false,
      disabledReason: reason,
      lockDisabledReason: reason,
      climateDisabledReason: reason,
      drivingHint: drivingHint,
    );
  }

  bool canLock = false;
  bool canUnlock = false;
  String? lockReason;

  final lockState = status.lockState;
  if (lockState == null || lockState == LockState.unknown) {
    lockReason = 'State unavailable.';
  } else if (lockState == LockState.unlocked) {
    canLock = true;
  } else if (lockState == LockState.locked) {
    canUnlock = true;
  } else {
    lockReason = 'State unavailable.';
  }

  bool canStartClimate = false;
  bool canStopClimate = false;
  String? climateReason;

  final preconState = status.preconditioningState;
  if (preconState == null || preconState == PreconditioningState.unknown) {
    climateReason = 'State unavailable.';
  } else if (preconState == PreconditioningState.inactive) {
    canStartClimate = true;
  } else if (preconState == PreconditioningState.active) {
    canStopClimate = true;
  } else {
    climateReason = 'State unavailable.';
  }

  String? generalReason;
  if (!canLock && !canUnlock && !canStartClimate && !canStopClimate) {
    generalReason = lockReason ?? climateReason;
  }

  return ControlAvailability(
    canLock: canLock,
    canUnlock: canUnlock,
    canStartClimate: canStartClimate,
    canStopClimate: canStopClimate,
    disabledReason: generalReason,
    lockDisabledReason: lockReason,
    climateDisabledReason: climateReason,
    drivingHint: drivingHint,
  );
}
