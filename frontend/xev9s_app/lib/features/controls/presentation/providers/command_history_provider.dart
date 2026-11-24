import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../vehicles/selected_vehicle_provider.dart';
import '../../data/command_repository.dart';
import '../../domain/command.dart';
import '../../domain/command_status.dart';
import '../../domain/command_type.dart';

/// State representation for paginated command history (UC-05).
class CommandHistoryState extends Equatable {
  const CommandHistoryState({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.statusFilter,
    this.typeFilter,
  });

  final List<Command> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final CommandStatus? statusFilter;
  final CommandType? typeFilter;

  CommandHistoryState copyWith({
    List<Command>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
    CommandStatus? statusFilter,
    bool clearStatusFilter = false,
    CommandType? typeFilter,
    bool clearTypeFilter = false,
  }) {
    return CommandHistoryState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
    );
  }

  @override
  List<Object?> get props => [
        items,
        page,
        hasMore,
        isLoadingMore,
        loadMoreError,
        statusFilter,
        typeFilter,
      ];
}

/// AsyncNotifier managing paginated command history.
class CommandHistoryNotifier extends AsyncNotifier<CommandHistoryState> {
  CommandRepository? _repository;
  String? _currentVehicleId;
  bool _isFetchingPage = false;

  @override
  FutureOr<CommandHistoryState> build() async {
    _repository = ref.watch(commandRepositoryProvider);
    final vehicleId = ref.watch(selectedVehicleProvider);
    final authState = ref.watch(authControllerProvider);

    _currentVehicleId = vehicleId;

    if (authState is! AuthAuthenticated ||
        vehicleId == null ||
        vehicleId.isEmpty) {
      return const CommandHistoryState(hasMore: false);
    }

    return _fetchInitialPage(vehicleId);
  }

  Future<CommandHistoryState> _fetchInitialPage(
    String vehicleId, {
    CommandStatus? statusFilter,
    CommandType? typeFilter,
  }) async {
    _isFetchingPage = true;
    try {
      final paged = await _repository!.listCommands(
        vehicleId,
        page: 1,
        pageSize: AppConstants.commandsPageSize,
        status: statusFilter,
        commandType: typeFilter,
      );

      final totalPages = paged.pagination?.totalPages ?? 1;
      final hasMore = 1 < totalPages && paged.items.isNotEmpty;

      return CommandHistoryState(
        items: paged.items,
        page: 1,
        hasMore: hasMore,
        statusFilter: statusFilter,
        typeFilter: typeFilter,
      );
    } finally {
      _isFetchingPage = false;
    }
  }

  /// Pull-to-refresh: re-fetches first page while preserving current items on failure.
  Future<void> refresh() async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    final current = state.hasValue ? state.value : null;
    final currentStatusFilter = current?.statusFilter;
    final currentTypeFilter = current?.typeFilter;

    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<CommandHistoryState>().copyWithPrevious(state);

    try {
      final freshState = await _fetchInitialPage(
        vehicleId,
        statusFilter: currentStatusFilter,
        typeFilter: currentTypeFilter,
      );
      state = AsyncData(freshState);
    } catch (e, st) {
      if (state.hasValue && state.value != null) {
        state = AsyncData(state.value!);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  /// Updates or clears the status filter and reloads from page 1.
  Future<void> setStatusFilter(CommandStatus? filter) async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    final currentType = state.hasValue ? state.value?.typeFilter : null;

    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<CommandHistoryState>().copyWithPrevious(state);

    try {
      final freshState = await _fetchInitialPage(
        vehicleId,
        statusFilter: filter,
        typeFilter: currentType,
      );
      state = AsyncData(freshState);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Updates or clears the type filter and reloads from page 1.
  Future<void> setTypeFilter(CommandType? filter) async {
    final vehicleId = _currentVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    final currentStatus = state.hasValue ? state.value?.statusFilter : null;

    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<CommandHistoryState>().copyWithPrevious(state);

    try {
      final freshState = await _fetchInitialPage(
        vehicleId,
        statusFilter: currentStatus,
        typeFilter: filter,
      );
      state = AsyncData(freshState);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Appends the next page of commands with de-duplication by commandId.
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
      final paged = await _repository!.listCommands(
        vehicleId,
        page: nextPage,
        pageSize: AppConstants.commandsPageSize,
        status: current.statusFilter,
        commandType: current.typeFilter,
      );

      final existingIds = current.items.map((c) => c.commandId).toSet();
      final newItems = paged.items
          .where((item) => !existingIds.contains(item.commandId))
          .toList();

      final totalPages = paged.pagination?.totalPages ?? nextPage;
      final hasMore = nextPage < totalPages && paged.items.isNotEmpty;

      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...newItems],
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

  /// Retries loading the page that previously failed during loadMore.
  Future<void> retryLoadMore() => loadMore();
}

/// Provider for paginated command history.
final commandHistoryProvider =
    AsyncNotifierProvider<CommandHistoryNotifier, CommandHistoryState>(
  CommandHistoryNotifier.new,
);
