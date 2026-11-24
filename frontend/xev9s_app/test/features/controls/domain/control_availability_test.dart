import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/controls/domain/control_availability.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('availableActions Pure Logic', () {
    final now = DateTime.parse('2026-11-24T12:00:00Z');

    VehicleStatus makeStatus({
      VehicleConnectivity connectivity = VehicleConnectivity.online,
      VehicleState vehicleState = VehicleState.parked,
      LockState? lockState = LockState.locked,
      PreconditioningState? preconditioningState = PreconditioningState.inactive,
    }) {
      return VehicleStatus(
        vehicleId: 'veh_9S0001',
        name: 'My XEV 9S',
        model: '9S',
        vehicleState: vehicleState,
        connectivity: connectivity,
        lastUpdatedAt: now,
        isStale: false,
        lockState: lockState,
        preconditioningState: preconditioningState,
      );
    }

    test('vehicle connectivity OFFLINE disables all controls with exact message', () {
      final status = makeStatus(
        connectivity: VehicleConnectivity.offline,
        lockState: LockState.unlocked,
        preconditioningState: PreconditioningState.inactive,
      );

      final result = availableActions(status, null);
      expect(result.canLock, isFalse);
      expect(result.canUnlock, isFalse);
      expect(result.canStartClimate, isFalse);
      expect(result.canStopClimate, isFalse);
      expect(result.disabledReason, 'Vehicle is offline. Controls are unavailable.');
    });

    test('vehicleState OFFLINE disables all controls with exact message', () {
      final status = makeStatus(
        vehicleState: VehicleState.offline,
        lockState: LockState.unlocked,
        preconditioningState: PreconditioningState.inactive,
      );

      final result = availableActions(status, null);
      expect(result.canLock, isFalse);
      expect(result.canUnlock, isFalse);
      expect(result.canStartClimate, isFalse);
      expect(result.canStopClimate, isFalse);
      expect(result.disabledReason, 'Vehicle is offline. Controls are unavailable.');
    });

    test('active non-final command disables all controls with exact message', () {
      final status = makeStatus(
        lockState: LockState.unlocked,
        preconditioningState: PreconditioningState.inactive,
      );
      final active = Command(
        commandId: 'cmd_1',
        vehicleId: 'veh_9S0001',
        commandType: CommandType.lock,
        status: CommandStatus.executing,
        requestedAt: now,
      );

      final result = availableActions(status, active);
      expect(result.canLock, isFalse);
      expect(result.canUnlock, isFalse);
      expect(result.canStartClimate, isFalse);
      expect(result.canStopClimate, isFalse);
      expect(result.disabledReason, 'A command is in progress.');
    });

    test('completed (final) command does not disable controls', () {
      final status = makeStatus(
        lockState: LockState.unlocked,
        preconditioningState: PreconditioningState.inactive,
      );
      final finalCmd = Command(
        commandId: 'cmd_1',
        vehicleId: 'veh_9S0001',
        commandType: CommandType.lock,
        status: CommandStatus.succeeded,
        requestedAt: now,
      );

      final result = availableActions(status, finalCmd);
      expect(result.canLock, isTrue);
      expect(result.canUnlock, isFalse);
      expect(result.canStartClimate, isTrue);
      expect(result.canStopClimate, isFalse);
    });

    test('lock pairing rules: canLock when UNLOCKED; canUnlock when LOCKED', () {
      final unlockedStatus = makeStatus(lockState: LockState.unlocked);
      final unlockedActions = availableActions(unlockedStatus, null);
      expect(unlockedActions.canLock, isTrue);
      expect(unlockedActions.canUnlock, isFalse);

      final lockedStatus = makeStatus(lockState: LockState.locked);
      final lockedActions = availableActions(lockedStatus, null);
      expect(lockedActions.canLock, isFalse);
      expect(lockedActions.canUnlock, isTrue);
    });

    test('climate pairing rules: canStartClimate when INACTIVE; canStopClimate when ACTIVE', () {
      final inactiveStatus =
          makeStatus(preconditioningState: PreconditioningState.inactive);
      final inactiveActions = availableActions(inactiveStatus, null);
      expect(inactiveActions.canStartClimate, isTrue);
      expect(inactiveActions.canStopClimate, isFalse);

      final activeStatus =
          makeStatus(preconditioningState: PreconditioningState.active);
      final activeActions = availableActions(activeStatus, null);
      expect(activeActions.canStartClimate, isFalse);
      expect(activeActions.canStopClimate, isTrue);
    });

    test('unknown or null states disable respective pair with "State unavailable."', () {
      final unknownStatus = makeStatus(
        lockState: LockState.unknown,
        preconditioningState: PreconditioningState.unknown,
      );
      final result = availableActions(unknownStatus, null);
      expect(result.canLock, isFalse);
      expect(result.canUnlock, isFalse);
      expect(result.canStartClimate, isFalse);
      expect(result.canStopClimate, isFalse);
      expect(result.lockDisabledReason, 'State unavailable.');
      expect(result.climateDisabledReason, 'State unavailable.');

      final nullStatus = makeStatus(
        lockState: null,
        preconditioningState: null,
      );
      final nullResult = availableActions(nullStatus, null);
      expect(nullResult.canLock, isFalse);
      expect(nullResult.canUnlock, isFalse);
      expect(nullResult.canStartClimate, isFalse);
      expect(nullResult.canStopClimate, isFalse);
      expect(nullResult.lockDisabledReason, 'State unavailable.');
      expect(nullResult.climateDisabledReason, 'State unavailable.');
    });

    test('DRIVING vehicleState exposes driving hint but does NOT disable controls', () {
      final drivingStatus = makeStatus(
        vehicleState: VehicleState.driving,
        lockState: LockState.unlocked,
        preconditioningState: PreconditioningState.inactive,
      );

      final result = availableActions(drivingStatus, null);
      expect(result.canLock, isTrue);
      expect(result.canStartClimate, isTrue);
      expect(result.drivingHint, isNotNull);
      expect(result.drivingHint, contains('driving'));
    });
  });
}
