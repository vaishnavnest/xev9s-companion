import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/error_codes.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../vehicles/domain/realtime_event.dart';
import '../data/trip_repository.dart';
import '../domain/route_point.dart';
import '../domain/route_utils.dart';
import '../domain/trip_detail.dart';
import '../domain/trip_status.dart';

/// Family key for [tripDetailProvider] and [tripRouteForMapProvider].
class TripDetailKey extends Equatable {
  const TripDetailKey({
    required this.vehicleId,
    required this.tripId,
  });

  final String vehicleId;
  final String tripId;

  @override
  List<Object?> get props => [vehicleId, tripId];
}

/// State representing a loaded trip detail or an explicit not-found state (404).
class TripDetailState extends Equatable {
  const TripDetailState._({
    this.detail,
    this.isNotFound = false,
  });

  const TripDetailState.found(TripDetail detail)
      : this._(detail: detail, isNotFound: false);

  const TripDetailState.notFound() : this._(detail: null, isNotFound: true);

  final TripDetail? detail;
  final bool isNotFound;

  @override
  List<Object?> get props => [detail, isNotFound];
}

/// AsyncNotifier family loading a single [TripDetail] directly by ID.
class TripDetailNotifier extends AsyncNotifier<TripDetailState> {
  TripDetailNotifier(this.arg);

  final TripDetailKey arg;

  TripRepository? _repository;
  Timer? _ongoingTimer;
  bool _isScreenVisible = true;
  bool _wasOngoing = false;

  @override
  FutureOr<TripDetailState> build() async {
    _repository = ref.watch(tripRepositoryProvider);
    _cancelTimer();
    ref.onDispose(_cancelTimer);

    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (previous, next) {
      next.whenData((event) {
        if (event.type != RealtimeEventType.tripCompleted) return;
        if (event.vehicleId != arg.vehicleId) return;
        final eventTripId =
            (event.rawData?['trip_id'] ?? event.rawData?['tripId']) as String?;
        if (eventTripId == null || eventTripId == arg.tripId) {
          refresh();
        }
      });
    });

    final loaded = await _fetchDetail();
    _handleLifecycle(loaded);
    return loaded;
  }

  /// Controls whether the detail screen is active so ongoing polling stops
  /// when the screen is off-screen.
  void setScreenVisible(bool visible) {
    _isScreenVisible = visible;
    final current = state.asData?.value;
    if (current != null) {
      _handleLifecycle(current);
    } else if (!visible) {
      _cancelTimer();
    }
  }

  Future<TripDetailState> _fetchDetail() async {
    try {
      final detail = await _repository!.getTrip(arg.vehicleId, arg.tripId);
      return TripDetailState.found(detail);
    } on AppError catch (e) {
      if (e.code == ApiErrorCode.notFound ||
          e.code == ApiErrorCode.vehicleNotFound) {
        return const TripDetailState.notFound();
      }
      rethrow;
    }
  }

  /// Refreshes the trip detail while preserving previous data.
  Future<void> refresh() async {
    final previous = state.asData?.value;
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<TripDetailState>().copyWithPrevious(state);

    try {
      final loaded = await _fetchDetail();
      if (!ref.mounted) return;
      state = AsyncData(loaded);

      final transitionedToCompleted = _wasOngoing &&
          loaded.detail != null &&
          loaded.detail!.status == TripStatus.completed;

      _handleLifecycle(loaded);

      if (transitionedToCompleted) {
        // Perform one final refresh to ensure final totals are up to date,
        // then keep timer stopped.
        final finalSnapshot = await _fetchDetail();
        if (!ref.mounted) return;
        state = AsyncData(finalSnapshot);
        _cancelTimer();
      }
    } catch (e, st) {
      if (!ref.mounted) return;
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  void _handleLifecycle(TripDetailState detailState) {
    final isOngoing = detailState.detail?.isOngoing ?? false;
    _wasOngoing = isOngoing;

    if (_isScreenVisible && isOngoing) {
      _ongoingTimer ??= Timer.periodic(
        const Duration(seconds: AppConstants.ongoingTripRefreshSeconds),
        (_) => refresh(),
      );
    } else {
      _cancelTimer();
    }
  }

  void _cancelTimer() {
    _ongoingTimer?.cancel();
    _ongoingTimer = null;
  }
}

/// Family provider loading trip details by `(vehicleId, tripId)`.
final tripDetailProvider =
    AsyncNotifierProvider.family<TripDetailNotifier, TripDetailState, TripDetailKey>(
  TripDetailNotifier.new,
);

/// Derived map-ready route data computed once per [TripDetail] value.
class TripMapRouteData extends Equatable {
  const TripMapRouteData({
    required this.points,
    required this.bounds,
  });

  final List<RoutePoint> points;
  final RouteBounds? bounds;

  bool get hasRoute => points.isNotEmpty;

  @override
  List<Object?> get props => [points, bounds];
}

/// Derived provider returning downsampled route points + bounding box for a trip.
final tripRouteForMapProvider =
    Provider.family<TripMapRouteData?, TripDetailKey>((ref, key) {
  final detailState = ref.watch(tripDetailProvider(key)).asData?.value;
  final detail = detailState?.detail;
  if (detail == null) return null;

  final downsampled = downsampleRoute(
    detail.route,
    maxPoints: AppConstants.routeMaxRenderPoints,
  );
  final bounds = computeRouteBounds(downsampled);
  return TripMapRouteData(points: downsampled, bounds: bounds);
});
