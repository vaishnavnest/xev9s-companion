import 'package:material_ui/material_ui.dart' hide LockState;
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../vehicles/domain/vehicle_status.dart';

/// Pure presentation view-model for [DashboardPage], decoupling UI rendering
/// from domain formatting and condition logic for testability.
class DashboardViewModel {
  DashboardViewModel({
    required this.status,
    this.clock,
  });

  final VehicleStatus status;
  final DateTime? clock;

  bool get isOffline => status.isOffline;
  bool get showStale => status.showStale;
  bool get isLiveValuesDimmed => status.showStale;

  // Header values
  String get displayName =>
      status.name != null && status.name!.trim().isNotEmpty
          ? status.name!
          : (status.model ?? 'XEV 9S');

  String get modelName => status.model ?? 'XEV 9S';

  String get vehicleStateLabel {
    switch (status.vehicleState) {
      case VehicleState.parked:
        return 'Parked';
      case VehicleState.driving:
        return 'Driving';
      case VehicleState.charging:
        return 'Charging';
      case VehicleState.offline:
        return 'Offline';
      case VehicleState.unknown:
        return 'Unknown';
    }
  }

  ChipStatusType get vehicleStateType {
    switch (status.vehicleState) {
      case VehicleState.parked:
        return ChipStatusType.info;
      case VehicleState.driving:
        return ChipStatusType.success;
      case VehicleState.charging:
        return ChipStatusType.warning;
      case VehicleState.offline:
        return ChipStatusType.error;
      case VehicleState.unknown:
        return ChipStatusType.info;
    }
  }

  String get connectivityLabel =>
      status.connectivity == ConnectivityStatus.online ? 'Online' : 'Offline';

  ChipStatusType get connectivityType =>
      status.connectivity == ConnectivityStatus.online
          ? ChipStatusType.success
          : ChipStatusType.error;

  // Battery card
  String get batteryPercentDisplay =>
      Formatters.formatPercent(status.battery?.percent);

  bool get isBatteryUnavailable => status.battery?.percent == null;

  String get batteryRangeDisplay =>
      Formatters.formatKm(status.range?.estimatedKm);

  double get batteryProgressFraction =>
      status.battery?.percent != null ? (status.battery!.percent! / 100.0) : 0.0;

  BatteryLevel get effectiveBatteryLevel => status.effectiveBatteryLevel;

  String get batteryLevelLabel {
    switch (effectiveBatteryLevel) {
      case BatteryLevel.normal:
        return 'Normal';
      case BatteryLevel.warning:
        return 'Low Battery';
      case BatteryLevel.unavailable:
        return 'Unavailable';
      case BatteryLevel.unknown:
        return 'Unknown';
    }
  }

  String get batterySemanticsLabel {
    if (status.battery?.percent == null) {
      return 'Battery unavailable, range $batteryRangeDisplay';
    }
    return 'Battery $batteryPercentDisplay, range $batteryRangeDisplay';
  }

  // Vehicle info card
  String get odometerDisplay => Formatters.formatKm(status.odometerKm);

  String get speedDisplay => Formatters.formatKmh(status.speedKmh);

  String get lockStateDisplay {
    switch (status.lockState) {
      case LockState.locked:
        return 'Locked';
      case LockState.unlocked:
        return 'Unlocked';
      case LockState.unknown:
      case null:
        return Formatters.nullPlaceholder;
    }
  }

  IconData get lockStateIcon =>
      status.lockState == LockState.locked
          ? Icons.lock_outline_rounded
          : Icons.lock_open_rounded;

  String get preconditioningDisplay {
    switch (status.preconditioningState) {
      case PreconditioningState.active:
        return 'Active';
      case PreconditioningState.inactive:
        return 'Inactive';
      case PreconditioningState.unknown:
      case null:
        return Formatters.nullPlaceholder;
    }
  }

  // Charging summary card
  String get chargingStateDisplay {
    switch (status.charging?.state) {
      case ChargingState.notConnected:
        return 'Not Connected';
      case ChargingState.connected:
        return 'Connected';
      case ChargingState.charging:
        return 'Charging';
      case ChargingState.paused:
        return 'Paused';
      case ChargingState.completed:
        return 'Completed';
      case ChargingState.interrupted:
        return 'Interrupted';
      case ChargingState.unknown:
      case null:
        return Formatters.nullPlaceholder;
    }
  }

  String get chargingPowerDisplay =>
      Formatters.formatKw(status.charging?.powerKw);

  // Stale and relative time displays
  String get relativeLastUpdated =>
      Formatters.formatRelative(status.lastUpdatedAt, clock: clock);

  String get exactLastUpdated => Formatters.formatDateTime(status.lastUpdatedAt);

  String get staleBannerMessage =>
      'Offline - showing last known data from $relativeLastUpdated';
}
