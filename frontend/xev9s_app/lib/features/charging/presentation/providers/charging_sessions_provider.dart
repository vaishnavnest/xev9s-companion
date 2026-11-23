import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../vehicles/domain/vehicle_status.dart';
import '../../../vehicles/selected_vehicle_provider.dart';
import '../../data/charging_repository.dart';
import '../../domain/charging_session.dart';

/// State of the paginated charging sessions list.
class ChargingSessionsState extends Equatable {
  const ChargingSessionsState({
    this.items = const <ChargingSession>[],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.statusFilter,
    this.loadMoreError,
  });

  final List<ChargingSession> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final ChargingState? statusFilter;
  final Object? loadMoreError;

  ChargingSessionsState copyWith({
    List<ChargingSession>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    ChargingState? statusFilter,
    bool clearStatusFilter = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return ChargingSessionsState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }

  @override
  List<Object?> get props => [
        items,
        page,
        hasMore,
        isLoadingMore,
        statusFilter,
        loadMoreError,
      ];
}

/// AsyncNotifier managing paginated charging sessions history.
class ChargingSessionsNotifier extends AsyncNotifier<ChargingSessionsState> {
  ChargingRepository? _repository;
  String? _currentVehicleId;
  bool _isFetchingPage = false;

  @override
  FutureOr<ChargingSessionsState> build() async {
    _repository = ref.watch(chargingRepositoryProvider);
    final vehicleId = ref.watch(selectedVehicleProvider);
    final authState = ref.watch(authControllerProvider);

    _currentVehicleId = vehicleId;

    if (authState is! AuthAuthenticated || vehicleId == null || vehicleId.isEmpty) {
      return const ChargingSessionsState(hasMore: false);
    }

    return _fetchInitialPage(vehicleId, filter: null);
  }

  Future<ChargingSessionsState> _fetchInitialPage(
    String vehicleId, {
    ChargingState? filter,
  }) async {
    _isFetchingPage = true;
    try {
      final paged = await _repository!.listSessions(
        vehicleId,
        page: 1,
        pageSize: AppConstants.sessionsPageSize,
        status: filter,
      );

      final totalPages = paged.pagination?.totalPages ?? 1;
      final hasMore = 1 < totalPages && paged.items.isNotEmpty;

      return ChargingSessionsState(
        items: paged.items,
        page: 1,
        hasMore: hasMore,
        statusFilter: filter,
      );
    } finally {
      _isFetchingPage = false;
    }
  }

  /// Pull-to-refresh: re-fetches first page while preserving existing data.
  Future<void> refresh() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    final currentFilter = state.hasValue ? state.value!.statusFilter : null;
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<ChargingSessionsState>().copyWithPrevious(state);

    try {
      final freshState = await _fetchInitialPage(vehicleId, filter: currentFilter);
      state = AsyncData(freshState);
    } catch (e, st) {
      if (state.hasValue && state.value != null) {
        state = AsyncData(state.value!);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  /// Changes or clears the status filter and reloads from page 1.
  Future<void> setFilter(ChargingState? filter) async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<ChargingSessionsState>().copyWithPrevious(state);

    try {
      final freshState = await _fetchInitialPage(vehicleId, filter: filter);
      state = AsyncData(freshState);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Appends the next page of items. De-duplicates by sessionId and prevents duplicate requests.
  Future<void> loadMore() async {
    final current = state.hasValue ? state.value : null;
    final vehicleId = _currentVehicleId;
    if (current == null ||
        vehicleId == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        _isFetchingPage) {
      return;
    }

    _isFetchingPage = true;
    state = AsyncData(
      current.copyWith(
        isLoadingMore: true,
        clearLoadMoreError: true,
      ),
    );

    final nextPage = current.page + 1;

    try {
      final paged = await _repository!.listSessions(
        vehicleId,
        page: nextPage,
        pageSize: AppConstants.sessionsPageSize,
        status: current.statusFilter,
      );

      final existingIds = current.items.map((e) => e.sessionId).toSet();
      final newUniqueItems =
          paged.items.where((e) => !existingIds.contains(e.sessionId)).toList();

      final combined = List<ChargingSession>.from(current.items)..addAll(newUniqueItems);
      final totalPages = paged.pagination?.totalPages ?? nextPage;
      final hasMore = nextPage < totalPages && paged.items.isNotEmpty;

      state = AsyncData(
        current.copyWith(
          items: combined,
          page: nextPage,
          hasMore: hasMore,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: e,
        ),
      );
    } finally {
      _isFetchingPage = false;
    }
  }
}

/// Provider for paginated charging sessions list.
final chargingSessionsProvider =
    AsyncNotifierProvider<ChargingSessionsNotifier, ChargingSessionsState>(
  ChargingSessionsNotifier.new,
);
