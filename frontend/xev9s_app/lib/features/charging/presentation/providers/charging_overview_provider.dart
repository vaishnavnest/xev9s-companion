import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/realtime/realtime_providers.dart';
import '../../../vehicles/domain/realtime_event.dart';
import '../../../vehicles/domain/vehicle_status.dart';
import '../../../vehicles/selected_vehicle_provider.dart';
import '../../data/charging_repository.dart';
import '../../domain/charging_overview.dart';
import '../../domain/charging_schedule.dart';
import 'charging_sessions_provider.dart';

/// Notifier tracking the timestamp of the last applied [ChargingOverview] update.
class ChargingOverviewLastUpdatedNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setTimestamp(DateTime? time) => state = time;
}

final chargingOverviewLastUpdatedProvider =
    NotifierProvider<ChargingOverviewLastUpdatedNotifier, DateTime?>(
  ChargingOverviewLastUpdatedNotifier.new,
);

/// Notifier tracking in-flight action state (loading/error) for form operations.
class ChargingActionStateNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  void setLoading() => state = const AsyncLoading();
  void setData() => state = const AsyncData(null);
  void setError(Object e, StackTrace st) => state = AsyncError(e, st);
}

final chargingActionStateProvider =
    NotifierProvider<ChargingActionStateNotifier, AsyncValue<void>>(
  ChargingActionStateNotifier.new,
);

/// AsyncNotifier managing live charging overview for the active vehicle.
class ChargingOverviewNotifier extends AsyncNotifier<ChargingOverview?> {
  ChargingRepository? _repository;
  String? _currentVehicleId;

  @override
  FutureOr<ChargingOverview?> build() async {
    _repository = ref.watch(chargingRepositoryProvider);
    final vehicleId = ref.watch(selectedVehicleProvider);
    _currentVehicleId = vehicleId;

    if (vehicleId == null || vehicleId.isEmpty) {
      ref.read(chargingOverviewLastUpdatedProvider.notifier).setTimestamp(null);
      return null;
    }

    // Inbound WebSocket push events
    ref.listen(realtimeEventsProvider, (previous, next) {
      next.whenData((event) {
        final activeId = _currentVehicleId ?? ref.read(selectedVehicleProvider);
        if (event.vehicleId != activeId) return;
        _handleRealtimeEvent(event);
      });
    });

    // Real-time re-sync on reconnection
    ref.listen(realtimeResyncProvider, (previous, next) {
      next.whenData((_) {
        refresh();
      });
    });

    final overview = await _repository!.getOverview(vehicleId);
    ref.read(chargingOverviewLastUpdatedProvider.notifier).setTimestamp(DateTime.now());
    return overview;
  }

  /// Refreshes overview via REST while preserving previous data to prevent spinner flash.
  Future<void> refresh() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    // Preserve previous data
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<ChargingOverview?>().copyWithPrevious(state);

    try {
      final overview = await _repository!.getOverview(vehicleId);
      ref.read(chargingOverviewLastUpdatedProvider.notifier).setTimestamp(DateTime.now());
      state = AsyncData(overview);
    } catch (e, st) {
      if (state.hasValue && state.value != null) {
        state = AsyncData(state.value);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  /// Sets charging target percent without optimistic UI update; updates on server response.
  Future<ChargingOverview> setTarget(int targetPercent) async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) {
      throw StateError('No vehicle selected');
    }

    final actionNotifier = ref.read(chargingActionStateProvider.notifier);
    actionNotifier.setLoading();

    try {
      final updated = await _repository!.setTarget(vehicleId, targetPercent);
      ref.read(chargingOverviewLastUpdatedProvider.notifier).setTimestamp(DateTime.now());
      state = AsyncData(updated);
      actionNotifier.setData();
      return updated;
    } catch (e, st) {
      actionNotifier.setError(e, st);
      rethrow;
    }
  }

  /// Saves or updates the charging schedule without optimistic UI update.
  Future<ChargingOverview> saveSchedule(ChargingSchedule schedule) async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) {
      throw StateError('No vehicle selected');
    }

    final actionNotifier = ref.read(chargingActionStateProvider.notifier);
    actionNotifier.setLoading();

    try {
      final updated = await _repository!.saveSchedule(vehicleId, schedule);
      ref.read(chargingOverviewLastUpdatedProvider.notifier).setTimestamp(DateTime.now());
      state = AsyncData(updated);
      actionNotifier.setData();
      return updated;
    } catch (e, st) {
      actionNotifier.setError(e, st);
      rethrow;
    }
  }

  /// Deletes the charging schedule.
  Future<ChargingOverview> deleteSchedule() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) {
      throw StateError('No vehicle selected');
    }

    final actionNotifier = ref.read(chargingActionStateProvider.notifier);
    actionNotifier.setLoading();

    try {
      final updated = await _repository!.deleteSchedule(vehicleId);
      ref.read(chargingOverviewLastUpdatedProvider.notifier).setTimestamp(DateTime.now());
      state = AsyncData(updated);
      actionNotifier.setData();
      return updated;
    } catch (e, st) {
      actionNotifier.setError(e, st);
      rethrow;
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.type == RealtimeEventType.chargingUpdated) {
      if (event.rawData == null) return;

      try {
        final incoming = ChargingOverview.fromJson(event.rawData!);
        final previous = state.hasValue ? state.value : null;

        // When a charging session finishes or currentSessionId changes, invalidate sessions list
        if (previous != null) {
          final sessionFinished = (previous.state == ChargingState.charging ||
                  previous.state == ChargingState.paused ||
                  previous.state == ChargingState.connected) &&
              (incoming.state == ChargingState.completed ||
                  incoming.state == ChargingState.interrupted ||
                  incoming.state == ChargingState.notConnected);

          final sessionChanged = incoming.currentSessionId != null &&
              previous.currentSessionId != null &&
              incoming.currentSessionId != previous.currentSessionId;

          if (sessionFinished || sessionChanged) {
            ref.invalidate(chargingSessionsProvider);
          }
        }

        // Preserve existing preferences/session fields when partial WebSocket payloads omit them
        final raw = event.rawData!;
        final lastUpdated = ref.read(chargingOverviewLastUpdatedProvider);
        ChargingOverview effective = incoming;
        if (previous != null) {
          final isStaleTarget = lastUpdated != null &&
              event.timestamp.isBefore(lastUpdated) &&
              previous.targetPercent != null &&
              incoming.targetPercent != previous.targetPercent;

          final sessionFinished = (previous.state == ChargingState.charging ||
                  previous.state == ChargingState.paused ||
                  previous.state == ChargingState.connected) &&
              (incoming.state == ChargingState.completed ||
                  incoming.state == ChargingState.interrupted ||
                  incoming.state == ChargingState.notConnected);

          effective = incoming.copyWith(
            batteryPercent: incoming.batteryPercent ?? previous.batteryPercent,
            targetPercent: (isStaleTarget || incoming.targetPercent == null)
                ? previous.targetPercent
                : incoming.targetPercent,
            powerKw: incoming.powerKw ?? previous.powerKw,
            sessionDurationSeconds:
                incoming.sessionDurationSeconds ?? previous.sessionDurationSeconds,
            schedule: incoming.schedule ?? previous.schedule,
            currentSessionId: sessionFinished
                ? null
                : (incoming.currentSessionId ?? previous.currentSessionId),
            clearCurrentSessionId: sessionFinished,
            timezone: raw.containsKey('timezone')
                ? incoming.timezone
                : previous.timezone,
            stopChargingAtTarget: raw.containsKey('stop_charging_at_target')
                ? incoming.stopChargingAtTarget
                : previous.stopChargingAtTarget,
          );
        }

        ref
            .read(chargingOverviewLastUpdatedProvider.notifier)
            .setTimestamp(event.timestamp);
        state = AsyncData(effective);
      } catch (_) {
        // Parse failures are ignored per spec
      }
    } else if (event.type == RealtimeEventType.vehicleStatus) {
      if (event.rawData == null) return;
      try {
        final status = event.asVehicleStatus();
        if (status != null && status.vehicleState == VehicleState.driving) {
          final previous = state.hasValue ? state.value : null;
          if (previous != null &&
              (previous.state == ChargingState.charging ||
                  previous.state == ChargingState.paused ||
                  previous.state == ChargingState.connected)) {
            ref.invalidate(chargingSessionsProvider);
            state = AsyncData(
              previous.copyWith(
                state: ChargingState.notConnected,
                powerKw: null,
                sessionDurationSeconds: null,
                currentSessionId: null,
              ),
            );
            ref
                .read(chargingOverviewLastUpdatedProvider.notifier)
                .setTimestamp(event.timestamp);
          }
        }
      } catch (_) {
        // Ignored
      }
    }
  }
}

/// Provider for active vehicle's [ChargingOverview].
final chargingOverviewProvider =
    AsyncNotifierProvider<ChargingOverviewNotifier, ChargingOverview?>(
  ChargingOverviewNotifier.new,
);
