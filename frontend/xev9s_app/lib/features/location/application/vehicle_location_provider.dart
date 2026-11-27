import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
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
  DateTime? _lastAddressFetchAt;
  bool _isFetchingAddress = false;

  static const double _addressRefreshDistanceMeters = 150.0;
  static const Duration _addressRefreshCooldown = Duration(seconds: 10);

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
    if (event.type != RealtimeEventType.vehicleLocation &&
        event.type != RealtimeEventType.vehicleStatus) {
      return;
    }
    if (event.rawData == null) return;

    try {
      final map = Map<String, dynamic>.from(event.rawData!);
      if (event.type == RealtimeEventType.vehicleStatus) {
        if (map['latitude'] is! num || map['longitude'] is! num) {
          return;
        }
        if (!map.containsKey('isCurrent') && !map.containsKey('is_current')) {
          map['isCurrent'] = true;
        }
        if (!map.containsKey('reportedAt') && !map.containsKey('timestamp')) {
          map['reportedAt'] = event.timestamp.toUtc().toIso8601String();
        }
      }

      if (!map.containsKey('vehicleId') || map['vehicleId'] == null) {
        map['vehicleId'] = event.vehicleId;
      }

      var incoming = VehicleLocation.fromJson(map);
      if (event.type == RealtimeEventType.vehicleStatus &&
          !incoming.hasCoordinates) {
        return;
      }

      final current = state.hasValue ? state.value : null;

      if (current == null) {
        state = AsyncData(incoming);
        if (incoming.description == null && incoming.hasCoordinates) {
          _scheduleAddressFetch(incoming.vehicleId);
        }
      } else {
        final currentReported = current.reportedAt;
        final newReported = incoming.reportedAt;

        // Replace state if reportedAt is newer than the current one (or current reportedAt is null)
        if (currentReported == null ||
            (newReported != null && newReported.isAfter(currentReported))) {
          final hadDescription = incoming.description != null;
          final movedEnough = _hasMovedBeyondThreshold(current, incoming);
          if (!hadDescription && current.description != null) {
            incoming = incoming.copyWith(description: current.description);
          }
          state = AsyncData(incoming);

          if (!hadDescription &&
              (incoming.description == null || movedEnough) &&
              incoming.hasCoordinates) {
            _scheduleAddressFetch(incoming.vehicleId);
          }
        }
      }
    } catch (_) {
      // Parse failures in push events are safely ignored, not thrown
    }
  }

  bool _hasMovedBeyondThreshold(
    VehicleLocation previous,
    VehicleLocation next,
  ) {
    if (!previous.hasCoordinates || !next.hasCoordinates) return true;
    final meters = const Distance().as(
      LengthUnit.Meter,
      LatLng(previous.latitude!, previous.longitude!),
      LatLng(next.latitude!, next.longitude!),
    );
    return meters >= _addressRefreshDistanceMeters;
  }

  void _scheduleAddressFetch(String vehicleId) {
    if (_isFetchingAddress || _repository == null) return;
    final now = DateTime.now();
    if (_lastAddressFetchAt != null &&
        now.difference(_lastAddressFetchAt!) < _addressRefreshCooldown) {
      return;
    }

    _isFetchingAddress = true;
    _lastAddressFetchAt = now;

    unawaited(() async {
      try {
        final fetched = await _repository!.getLocation(vehicleId);
        if (!ref.mounted || _currentVehicleId != vehicleId) return;
        final latest = state.hasValue ? state.value : null;
        if (latest == null) {
          state = AsyncData(fetched);
        } else if (fetched.description != null &&
            fetched.description!.trim().isNotEmpty) {
          state = AsyncData(latest.copyWith(description: fetched.description));
        }
      } catch (_) {
        // Silent background address fetch failure is safely ignored
      } finally {
        _isFetchingAddress = false;
      }
    }());
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
