import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../vehicles/application/vehicle_status_provider.dart';
import '../../vehicles/domain/realtime_event.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../data/location_repository.dart';
import '../domain/vehicle_location.dart';

/// AsyncNotifier managing the live and last-known position of the active vehicle.
class VehicleLocationNotifier extends AsyncNotifier<VehicleLocation?> {
  LocationRepository? _repository;
  Object? _refreshError;
  String? _currentVehicleId;

  /// Exposes the last background refresh error while preserving existing location data.
  Object? get lastRefreshError => _refreshError;

  @override
  FutureOr<VehicleLocation?> build() async {
    _repository = ref.watch(locationRepositoryProvider);
    final vehicleId = ref.watch(selectedVehicleProvider);
    _currentVehicleId = vehicleId;

    if (vehicleId == null || vehicleId.isEmpty) {
      return null;
    }

    // Reset state on user logout
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthUnauthenticated) {
        state = const AsyncData(null);
      }
    });

    // Listen to inbound real-time push events for the selected vehicle
    ref.listen(realtimeEventsProvider, (previous, next) {
      next.whenData((event) {
        if (event.vehicleId != _currentVehicleId) return;
        _handleRealtimeEvent(event);
      });
    });

    // Listen to resync signals from re-connections or polling intervals
    ref.listen(realtimeResyncProvider, (previous, next) {
      next.whenData((_) {
        refresh();
      });
    });

    // React to connectivity changes from vehicleStatusProvider
    ref.listen(vehicleStatusProvider, (previous, next) {
      final prevStatus = previous?.asData?.value;
      final nextStatus = next.asData?.value;
      if (nextStatus == null || nextStatus.vehicleId != _currentVehicleId) return;

      if (nextStatus.isOffline) {
        // Vehicle went offline: immediately mark current location as not current without waiting
        final current = state.hasValue ? state.value : null;
        if (current != null && current.isCurrent) {
          state = AsyncData(current.copyWith(isCurrent: false));
        }
      } else if (prevStatus != null && prevStatus.isOffline && !nextStatus.isOffline) {
        // Vehicle came back online: trigger re-fetch
        refresh();
      }
    });

    return _repository!.getLocation(vehicleId);
  }

  /// Refreshes vehicle location via REST while keeping previous data visible (no spinner flash).
  Future<void> refresh() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    // Preserve current data while loading to avoid flashing spinner
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<VehicleLocation?>().copyWithPrevious(state);

    try {
      final location = await _repository!.getLocation(vehicleId);
      _refreshError = null;
      state = AsyncData(location);
    } catch (e, st) {
      _refreshError = e;
      // If we have previous good data, preserve it; otherwise propagate error
      if (state.hasValue && state.value != null) {
        state = AsyncData(state.value);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.type != RealtimeEventType.vehicleLocation) return;
    if (event.rawData == null) return;

    try {
      final map = Map<String, dynamic>.from(event.rawData!);
      if (!map.containsKey('vehicleId') || map['vehicleId'] == null) {
        map['vehicleId'] = event.vehicleId;
      }

      final incoming = VehicleLocation.fromJson(map);
      final current = state.hasValue ? state.value : null;

      if (current == null) {
        state = AsyncData(incoming);
      } else {
        final currentReported = current.reportedAt;
        final newReported = incoming.reportedAt;

        // Replace state if reportedAt is newer than the current one (or current reportedAt is null)
        if (currentReported == null ||
            (newReported != null && newReported.isAfter(currentReported))) {
          state = AsyncData(incoming);
        }
      }
    } catch (_) {
      // Parse failures in push events are safely ignored, not thrown
    }
  }
}

/// Provider exposing live/last-known [VehicleLocation] for the currently active vehicle.
/// Automatically resets/reloads when the selected vehicle changes or on logout.
final vehicleLocationProvider =
    AsyncNotifierProvider<VehicleLocationNotifier, VehicleLocation?>(
  VehicleLocationNotifier.new,
);

/// Exposes the last REST refresh error for location if any occurred while data was retained.
final vehicleLocationRefreshErrorProvider = Provider<Object?>((ref) {
  ref.watch(vehicleLocationProvider);
  final notifier = ref.watch(vehicleLocationProvider.notifier);
  return notifier.lastRefreshError;
});
