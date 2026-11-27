import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../vehicles/application/vehicle_status_provider.dart';
import '../../vehicles/domain/realtime_event.dart';
import '../../vehicles/domain/vehicle_status.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../data/trip_repository.dart';
import '../domain/route_utils.dart';
import '../domain/trip.dart';
import '../domain/trip_status.dart';

/// State of the paginated trips history list (UC-06).
class TripsState extends Equatable {
  const TripsState({
    this.items = const <Trip>[],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.statusFilter,
    this.dateRange,
    this.error,
  });

  final List<Trip> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final TripStatus? statusFilter;
  final TripDateRange? dateRange;
  final Object? error;

  bool get hasActiveFilters => statusFilter != null || dateRange != null;
  bool get hasOngoingTrip => items.any((t) => t.isOngoing);

  TripsState copyWith({
    List<Trip>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    TripStatus? statusFilter,
    bool clearStatusFilter = false,
    TripDateRange? dateRange,
    bool clearDateRange = false,
    Object? error,
    bool clearError = false,
  }) {
    return TripsState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        items,
        page,
        hasMore,
        isLoadingMore,
        statusFilter,
        dateRange,
        error,
      ];
}

/// AsyncNotifier managing paginated trip history, filters, and auto-refresh.
class TripsNotifier extends AsyncNotifier<TripsState> {
  TripRepository? _repository;
  String? _currentVehicleId;
  bool _isFetchingPage = false;
  bool _isScreenVisible = false;
  Timer? _ongoingRefreshTimer;

  @override
  FutureOr<TripsState> build() async {
    _repository = ref.watch(tripRepositoryProvider);
    final vehicleId = ref.watch(selectedVehicleProvider);
    final authState = ref.watch(authControllerProvider);

    _currentVehicleId = vehicleId;
    _cancelOngoingTimer();

    ref.onDispose(_cancelOngoingTimer);

    // Refresh first page when vehicle transitions from DRIVING to non-driving.
    ref.listen<AsyncValue<VehicleStatus?>>(vehicleStatusProvider,
        (previous, next) {
      final prevState = previous?.asData?.value?.vehicleState;
      final nextState = next.asData?.value?.vehicleState;
      if (prevState == VehicleState.driving &&
          nextState != null &&
          nextState != VehicleState.driving) {
        refresh();
      }
    });

    // Refresh first page when realtime service signals resync.
    ref.listen<AsyncValue<void>>(realtimeResyncProvider, (previous, next) {
      next.whenData((_) {
        refresh();
      });
    });

    // Refresh first page when a trip completes for the active vehicle.
    ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider,
        (previous, next) {
      next.whenData((event) {
        if (event.type == RealtimeEventType.tripCompleted &&
            event.vehicleId == _currentVehicleId) {
          refresh();
        }
      });
    });

    if (authState is! AuthAuthenticated ||
        vehicleId == null ||
        vehicleId.isEmpty) {
      debugPrint('[TripsNotifier] build skipped: unauthenticated or no vehicle selected');
      return const TripsState(hasMore: false);
    }

    try {
      final initial = await _fetchFirstPage(vehicleId);
      debugPrint('[TripsNotifier] build loaded ${initial.items.length} trips');
      _syncOngoingTimer(initial);
      return initial;
    } catch (e) {
      debugPrint('[TripsNotifier] build failed: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Marks whether the trips list screen is currently visible so ongoing
  /// auto-refresh only runs while the user is viewing the screen.
  void setScreenVisible(bool visible) {
    if (_isScreenVisible == visible) return;
    _isScreenVisible = visible;
    final current = state.asData?.value;
    if (current != null) {
      _syncOngoingTimer(current);
    } else if (!visible) {
      _cancelOngoingTimer();
    }
  }

  Future<TripsState> _fetchFirstPage(
    String vehicleId, {
    TripStatus? statusFilter,
    TripDateRange? dateRange,
  }) async {
    _isFetchingPage = true;
    try {
      String? fromIso;
      String? toIso;
      if (dateRange != null) {
        final (from, to) = dateRangeToQuery(dateRange);
        fromIso = from;
        toIso = to;
      }

      final paged = await _repository!.listTrips(
        vehicleId,
        page: 1,
        pageSize: AppConstants.tripsPageSize,
        sort: '-started_at',
        status: statusFilter,
        from: fromIso,
        to: toIso,
      );

      final totalPages = paged.pagination?.totalPages ?? 1;
      final hasMore = 1 < totalPages && paged.items.isNotEmpty;

      return TripsState(
        items: paged.items,
        page: 1,
        hasMore: hasMore,
        statusFilter: statusFilter,
        dateRange: dateRange,
      );
    } finally {
      _isFetchingPage = false;
    }
  }

  /// Loads or reloads the first page (used by pull-to-refresh and auto-refresh).
  Future<void> loadFirstPage() => refresh();

  /// Pull-to-refresh / auto-refresh: keeps previous items visible without spinner flash.
  Future<void> refresh() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;
    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) return;
    if (_isFetchingPage) return;

    final current = state.asData?.value;
    final currentStatus = current?.statusFilter;
    final currentDateRange = current?.dateRange;

    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<TripsState>().copyWithPrevious(state);

    try {
      final fresh = await _fetchFirstPage(
        vehicleId,
        statusFilter: currentStatus,
        dateRange: currentDateRange,
      );
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      _syncOngoingTimer(fresh);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (current != null) {
        state = AsyncData(current);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  /// Updates the status filter and reloads page 1.
  Future<void> setStatusFilter(TripStatus? status) async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    final currentDateRange = state.asData?.value.dateRange;
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<TripsState>().copyWithPrevious(state);

    try {
      final fresh = await _fetchFirstPage(
        vehicleId,
        statusFilter: status,
        dateRange: currentDateRange,
      );
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      _syncOngoingTimer(fresh);
    } catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncError(e, st);
      _cancelOngoingTimer();
    }
  }

  /// Updates the date range filter and reloads page 1.
  Future<void> setDateRange(TripDateRange? range) async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    final currentStatus = state.asData?.value.statusFilter;
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<TripsState>().copyWithPrevious(state);

    try {
      final fresh = await _fetchFirstPage(
        vehicleId,
        statusFilter: currentStatus,
        dateRange: range,
      );
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      _syncOngoingTimer(fresh);
    } catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncError(e, st);
      _cancelOngoingTimer();
    }
  }

  /// Clears all active filters and reloads page 1.
  Future<void> clearFilters() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<TripsState>().copyWithPrevious(state);

    try {
      final fresh = await _fetchFirstPage(vehicleId);
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      _syncOngoingTimer(fresh);
    } catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncError(e, st);
      _cancelOngoingTimer();
    }
  }

  /// Appends the next page of trips. De-duplicates by tripId and prevents duplicate requests.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    final vehicleId = _currentVehicleId;
    if (current == null ||
        vehicleId == null ||
        vehicleId.isEmpty ||
        !current.hasMore ||
        current.isLoadingMore ||
        _isFetchingPage) {
      return;
    }

    _isFetchingPage = true;
    state = AsyncData(
      current.copyWith(
        isLoadingMore: true,
        clearError: true,
      ),
    );

    final nextPage = current.page + 1;

    try {
      String? fromIso;
      String? toIso;
      if (current.dateRange != null) {
        final (from, to) = dateRangeToQuery(current.dateRange!);
        fromIso = from;
        toIso = to;
      }

      final paged = await _repository!.listTrips(
        vehicleId,
        page: nextPage,
        pageSize: AppConstants.tripsPageSize,
        sort: '-started_at',
        status: current.statusFilter,
        from: fromIso,
        to: toIso,
      );

      if (!ref.mounted) return;

      final existingIds = current.items.map((e) => e.tripId).toSet();
      final newUnique =
          paged.items.where((e) => !existingIds.contains(e.tripId)).toList();

      final combined = List<Trip>.from(current.items)..addAll(newUnique);
      final totalPages = paged.pagination?.totalPages ?? nextPage;
      final hasMore = nextPage < totalPages && paged.items.isNotEmpty;

      final updated = current.copyWith(
        items: combined,
        page: nextPage,
        hasMore: hasMore,
        isLoadingMore: false,
        clearError: true,
      );
      state = AsyncData(updated);
      _syncOngoingTimer(updated);
    } catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          error: e,
        ),
      );
    } finally {
      _isFetchingPage = false;
    }
  }

  void _syncOngoingTimer(TripsState tripsState) {
    if (_isScreenVisible && tripsState.hasOngoingTrip) {
      _ongoingRefreshTimer ??= Timer.periodic(
        const Duration(seconds: AppConstants.ongoingTripRefreshSeconds),
        (_) => refresh(),
      );
    } else {
      _cancelOngoingTimer();
    }
  }

  void _cancelOngoingTimer() {
    _ongoingRefreshTimer?.cancel();
    _ongoingRefreshTimer = null;
  }
}

/// Provider for paginated trips list.
final tripsProvider = AsyncNotifierProvider<TripsNotifier, TripsState>(
  TripsNotifier.new,
);
