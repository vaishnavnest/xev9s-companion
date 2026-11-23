import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../vehicles/application/vehicle_status_provider.dart';
import '../../../vehicles/domain/vehicle_status.dart';
import '../../domain/charging_schedule.dart';
import 'charging_overview_provider.dart';

/// Unified view state combining live vehicle status telemetry and charging overview.
/// Guarantees that the live charging fields match the dashboard.
class ChargingViewState extends Equatable {
  const ChargingViewState({
    required this.state,
    this.batteryPercent,
    this.powerKw,
    this.targetPercent,
    this.sessionDurationSeconds,
    this.schedule,
    this.currentSessionId,
    this.isOffline = false,
    this.lastUpdatedAt,
  });

  final ChargingState state;
  final double? batteryPercent;
  final double? powerKw;
  final int? targetPercent;
  final int? sessionDurationSeconds;
  final ChargingSchedule? schedule;
  final String? currentSessionId;
  final bool isOffline;
  final DateTime? lastUpdatedAt;

  @override
  List<Object?> get props => [
        state,
        batteryPercent,
        powerKw,
        targetPercent,
        sessionDurationSeconds,
        schedule,
        currentSessionId,
        isOffline,
        lastUpdatedAt,
      ];
}

/// View-model provider ensuring the live fields (state, batteryPercent, powerKw)
/// on the charging screen and dashboard never disagree.
final chargingViewProvider = Provider<AsyncValue<ChargingViewState?>>((ref) {
  final overviewAsync = ref.watch(chargingOverviewProvider);
  final statusAsync = ref.watch(vehicleStatusProvider);

  if (overviewAsync.isLoading && !overviewAsync.hasValue) {
    return const AsyncLoading();
  }

  if (overviewAsync.hasError && !overviewAsync.hasValue) {
    return AsyncError(overviewAsync.error!, overviewAsync.stackTrace!);
  }

  final overview = overviewAsync.hasValue ? overviewAsync.value : null;
  if (overview == null) {
    return const AsyncData(null);
  }

  final status = statusAsync.hasValue ? statusAsync.value : null;
  final overviewTime = ref.watch(chargingOverviewLastUpdatedProvider) ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final statusTime = status?.lastUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  // If vehicle status has a strictly newer timestamp, use its live telemetry
  final useStatusLive = status != null && statusTime.isAfter(overviewTime);

  final liveState = useStatusLive
      ? (status.charging?.state ?? overview.state)
      : overview.state;

  final livePower = useStatusLive
      ? (status.charging?.powerKw ?? overview.powerKw)
      : overview.powerKw;

  final liveBattery = useStatusLive
      ? (status.battery?.percent ?? overview.batteryPercent)
      : overview.batteryPercent;

  final isOffline = status?.isOffline ?? false;

  return AsyncData(
    ChargingViewState(
      state: liveState,
      batteryPercent: liveBattery,
      powerKw: livePower,
      targetPercent: overview.targetPercent,
      sessionDurationSeconds: overview.sessionDurationSeconds,
      schedule: overview.schedule,
      currentSessionId: overview.currentSessionId,
      isOffline: isOffline,
      lastUpdatedAt: useStatusLive ? statusTime : overviewTime,
    ),
  );
});
