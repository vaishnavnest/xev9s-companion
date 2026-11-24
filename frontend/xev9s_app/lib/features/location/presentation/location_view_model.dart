import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../vehicles/domain/vehicle_status.dart';
import '../domain/vehicle_location.dart';

/// Pure Dart view-model providing formatted labels and state derivations
/// for the vehicle location UI and accessibility semantics.
class LocationViewModel {
  LocationViewModel({
    required this.location,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final VehicleLocation location;
  final DateTime now;

  /// Header title for the location card:
  /// "Current location" when live/current; "Last known position" when offline.
  /// Never uses "current" or "live" when isCurrent is false.
  String get headerTitle {
    return location.isCurrent ? 'Current location' : 'Last known position';
  }

  /// Address description or fallback string when missing/null.
  String get displayAddress {
    final desc = location.description?.trim();
    if (desc == null || desc.isEmpty) {
      return 'Address unavailable';
    }
    return desc;
  }

  /// Human-readable vehicle operational state label.
  String get vehicleStateLabel {
    switch (location.vehicleState) {
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

  /// Chip status color type matching dashboard conventions.
  ChipStatusType get vehicleStateType {
    switch (location.vehicleState) {
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

  /// Relative reported time string (e.g. "Just now", "5m ago").
  String get relativeReportedTime {
    if (location.reportedAt == null) return Formatters.nullPlaceholder;
    return Formatters.formatRelative(location.reportedAt, clock: now);
  }

  /// Exact localized date/time string for tooltips.
  String get exactReportedTimeTooltip {
    if (location.reportedAt == null) return 'Timestamp unavailable';
    return Formatters.formatDateTime(location.reportedAt);
  }

  /// Coordinates string formatted to 5 decimals (e.g. "12.97160, 77.59460").
  String get formattedCoordinates {
    if (!location.hasCoordinates) return Formatters.nullPlaceholder;
    final lat = location.latitude!.toStringAsFixed(5);
    final lng = location.longitude!.toStringAsFixed(5);
    return '$lat, $lng';
  }

  /// Notice message displayed when the vehicle is offline and showing last-known position.
  /// Never uses "current" or "live".
  String get offlineNoticeMessage {
    if (location.reportedAt != null) {
      final rel = Formatters.formatRelative(location.reportedAt, clock: now);
      return 'Last known position - the vehicle is offline ($rel)';
    }
    return 'Last known position - the vehicle is offline';
  }

  /// Comprehensive description for screen readers and accessibility semantics.
  String get semanticsLabel {
    final stateStr = vehicleStateLabel.toLowerCase();
    final address = displayAddress;
    final timeStr = relativeReportedTime.toLowerCase();
    return 'Vehicle $stateStr at $address, reported $timeStr';
  }
}
