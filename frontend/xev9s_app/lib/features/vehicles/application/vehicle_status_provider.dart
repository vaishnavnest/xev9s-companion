import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../data/vehicle_status_repository.dart';
import '../domain/realtime_event.dart';
import '../domain/vehicle_status.dart';
import '../selected_vehicle_provider.dart';

/// AsyncNotifier managing the live telemetry and physical status of the active vehicle.
/// Single source of truth for all vehicle dashboard and telemetry data across screens.
class VehicleStatusNotifier extends AsyncNotifier<VehicleStatus?> {
  VehicleStatusRepository? _repository;
  Object? _refreshError;
  String? _currentVehicleId;

  Object? get lastRefreshError => _refreshError;

  @override
  FutureOr<VehicleStatus?> build() async {
    _repository = ref.watch(vehicleStatusRepositoryProvider);
    final vehicleId = ref.watch(selectedVehicleProvider);
    _currentVehicleId = vehicleId;

    if (vehicleId == null || vehicleId.isEmpty) {
      return null;
    }

    // Listen to inbound real-time events for this specific vehicle
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

    return _repository!.getStatus(vehicleId);
  }

  /// Refreshes vehicle status via REST while preserving previous data to prevent spinner flicker.
  Future<void> refresh() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    // Preserve current data while fetching
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<VehicleStatus?>().copyWithPrevious(state);

    try {
      final status = await _repository!.getStatus(vehicleId);
      _refreshError = null;
      state = AsyncData(status);
    } catch (e, st) {
      _refreshError = e;
      // If we have existing data, keep showing it alongside the error
      if (state.hasValue && state.value != null) {
        state = AsyncData(state.value);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!state.hasValue || state.value == null) return;
    final current = state.value!;

    switch (event.type) {
      case RealtimeEventType.vehicleStatus:
        final incoming = event.asVehicleStatus();
        if (incoming != null) {
          // Out-of-date events are safely ignored
          if (!incoming.lastUpdatedAt.isBefore(current.lastUpdatedAt)) {
            state = AsyncData(current.merge(incoming));
          }
        }
        break;

      case RealtimeEventType.chargingUpdated:
        final charging = event.asChargingOverview();
        if (charging != null) {
          if (!event.timestamp.isBefore(current.lastUpdatedAt)) {
            final updatedCharging = current.charging?.copyWith(
                  state: charging.state,
                  powerKw: charging.powerKw,
                ) ??
                ChargingSummary(
                  state: charging.state,
                  powerKw: charging.powerKw,
                );

            var updatedBattery = current.battery;
            if (charging.batteryPercent != null) {
              updatedBattery = current.battery?.copyWith(
                    percent: charging.batteryPercent,
                  ) ??
                  BatterySummary(percent: charging.batteryPercent);
            }

            var updatedVehicleState = current.vehicleState;
            if (charging.state == ChargingState.charging) {
              updatedVehicleState = VehicleState.charging;
            }

            state = AsyncData(
              current.copyWith(
                charging: updatedCharging,
                battery: updatedBattery,
                vehicleState: updatedVehicleState,
                lastUpdatedAt: event.timestamp,
              ),
            );
          }
        }
        break;

      case RealtimeEventType.connectivityChanged:
        final conn = event.asConnectivity();
        if (conn != null) {
          if (!event.timestamp.isBefore(current.lastUpdatedAt)) {
            final isOffline = conn.status == ConnectivityStatus.offline;
            state = AsyncData(
              current.copyWith(
                connectivity: conn.status,
                isStale: isOffline ? true : current.isStale,
                speedKmh: isOffline ? null : current.speedKmh,
                charging: isOffline
                    ? current.charging?.copyWith(powerKw: null)
                    : current.charging,
                lastUpdatedAt: event.timestamp,
              ),
            );
          }
        }
        break;

      default:
        // Other event types ignored for dashboard status
        break;
    }
  }
}

/// Provider exposing live [VehicleStatus] for the currently active vehicle.
/// Automatically resets/reloads when the selected vehicle changes or on logout.
final vehicleStatusProvider =
    AsyncNotifierProvider<VehicleStatusNotifier, VehicleStatus?>(
  VehicleStatusNotifier.new,
);

/// Exposes the last REST refresh error for the active vehicle, if any occurred while data was retained.
final vehicleStatusRefreshErrorProvider = Provider<Object?>((ref) {
  final notifier = ref.watch(vehicleStatusProvider.notifier);
  return notifier.lastRefreshError;
});
