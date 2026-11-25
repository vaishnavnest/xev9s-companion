import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/trips_provider.dart';
import '../domain/route_utils.dart';
import '../domain/trip.dart';
import '../domain/trip_status.dart';
import 'trips_view_model.dart';

/// Paginated trip history list page (/trips) with date/status filters and day grouping (UC-06).
class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(tripsProvider.notifier).setScreenVisible(true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Best-effort: pause ongoing timer when leaving the trips screen.
    try {
      ref.read(tripsProvider.notifier).setScreenVisible(false);
    } catch (_) {
      // Container may already be disposed in tests.
    }
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      ref.read(tripsProvider.notifier).loadMore();
    }
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final currentRange = ref.read(tripsProvider).asData?.value.dateRange;
    final initialRange = (currentRange?.preset == TripDatePreset.custom &&
            currentRange?.customStart != null &&
            currentRange?.customEnd != null)
        ? DateTimeRange(
            start: currentRange!.customStart!,
            end: currentRange.customEnd!,
          )
        : DateTimeRange(
            start: now.subtract(const Duration(days: 6)),
            end: now,
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initialRange,
    );

    if (picked != null && mounted) {
      await ref
          .read(tripsProvider.notifier)
          .setDateRange(TripDateRange.custom(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);
    final currentState = tripsAsync.asData?.value;
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWide ? 1000 : double.infinity,
          ),
          child: Column(
            children: [
              _TripsFilterBar(
                statusFilter: currentState?.statusFilter,
                dateRange: currentState?.dateRange,
                hasActiveFilters: currentState?.hasActiveFilters ?? false,
                onStatusSelected: (status) =>
                    ref.read(tripsProvider.notifier).setStatusFilter(status),
                onDatePresetSelected: (preset) {
                  if (preset == null) {
                    ref.read(tripsProvider.notifier).setDateRange(null);
                  } else if (preset == TripDatePreset.today) {
                    ref
                        .read(tripsProvider.notifier)
                        .setDateRange(const TripDateRange.today());
                  } else if (preset == TripDatePreset.last7Days) {
                    ref
                        .read(tripsProvider.notifier)
                        .setDateRange(const TripDateRange.last7Days());
                  } else if (preset == TripDatePreset.last30Days) {
                    ref
                        .read(tripsProvider.notifier)
                        .setDateRange(const TripDateRange.last30Days());
                  } else if (preset == TripDatePreset.custom) {
                    _pickCustomDateRange(context);
                  }
                },
                onClearFilters: () =>
                    ref.read(tripsProvider.notifier).clearFilters(),
              ),
              const Divider(height: 1),
              Expanded(
                child: AsyncValueView<TripsState>(
                  value: tripsAsync,
                  onRetry: () => ref.read(tripsProvider.notifier).refresh(),
                  isEmpty: (s) => s.items.isEmpty,
                  empty: _buildEmptyState(currentState),
                  data: (state) {
                    final groups = TripsViewModel.groupTripsByDay(state.items);
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.read(tripsProvider.notifier).refresh(),
                      child: ListView(
                        key: const PageStorageKey<String>('trips_list_view'),
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          for (final group in groups) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 8,
                                left: 4,
                              ),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  group.header,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ),
                            for (final trip in group.trips) ...[
                              _TripRowCard(
                                trip: trip,
                                onTap: () =>
                                    context.push('/trips/${trip.tripId}'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                          if (state.isLoadingMore)
                            const Padding(
                              key: Key('trips_pagination_loader'),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Failed to load more trips.'),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    key: const Key('trips_retry_load_more'),
                                    onPressed: () => ref
                                        .read(tripsProvider.notifier)
                                        .loadMore(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(TripsState? state) {
    if (state != null && state.hasActiveFilters) {
      return EmptyState(
        key: const Key('trips_empty_filtered'),
        icon: Icons.filter_list_off_rounded,
        title: 'No trips match these filters',
        message: 'Try adjusting the date range or status filter.',
        actionLabel: 'Clear filters',
        onAction: () => ref.read(tripsProvider.notifier).clearFilters(),
      );
    }

    return const EmptyState(
      key: Key('trips_empty_all'),
      icon: Icons.route_outlined,
      title: 'No trips yet',
      message: 'Your completed and ongoing trips will appear here after driving.',
    );
  }
}

class _TripsFilterBar extends StatelessWidget {
  const _TripsFilterBar({
    required this.statusFilter,
    required this.dateRange,
    required this.hasActiveFilters,
    required this.onStatusSelected,
    required this.onDatePresetSelected,
    required this.onClearFilters,
  });

  final TripStatus? statusFilter;
  final TripDateRange? dateRange;
  final bool hasActiveFilters;
  final ValueChanged<TripStatus?> onStatusSelected;
  final ValueChanged<TripDatePreset?> onDatePresetSelected;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('trip_filter_status_all'),
            label: const Text('All'),
            selected: statusFilter == null,
            onSelected: (_) => onStatusSelected(null),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('trip_filter_status_completed'),
            label: const Text('Completed'),
            selected: statusFilter == TripStatus.completed,
            onSelected: (selected) =>
                onStatusSelected(selected ? TripStatus.completed : null),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('trip_filter_status_ongoing'),
            label: const Text('Ongoing'),
            selected: statusFilter == TripStatus.ongoing,
            onSelected: (selected) =>
                onStatusSelected(selected ? TripStatus.ongoing : null),
          ),
          const SizedBox(width: 16),
          ChoiceChip(
            key: const Key('trip_filter_date_today'),
            label: const Text('Today'),
            selected: dateRange?.preset == TripDatePreset.today,
            onSelected: (selected) =>
                onDatePresetSelected(selected ? TripDatePreset.today : null),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('trip_filter_date_7d'),
            label: const Text('7 days'),
            selected: dateRange?.preset == TripDatePreset.last7Days,
            onSelected: (selected) => onDatePresetSelected(
              selected ? TripDatePreset.last7Days : null,
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('trip_filter_date_30d'),
            label: const Text('30 days'),
            selected: dateRange?.preset == TripDatePreset.last30Days,
            onSelected: (selected) => onDatePresetSelected(
              selected ? TripDatePreset.last30Days : null,
            ),
          ),
          const SizedBox(width: 8),
          ActionChip(
            key: const Key('trip_filter_date_custom'),
            avatar: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(
              dateRange?.preset == TripDatePreset.custom
                  ? 'Custom (Active)'
                  : 'Custom...',
            ),
            onPressed: () => onDatePresetSelected(TripDatePreset.custom),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              key: const Key('trip_filter_clear'),
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripRowCard extends StatelessWidget {
  const _TripRowCard({
    required this.trip,
    required this.onTap,
  });

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOngoing = trip.isOngoing;
    final routeText = TripsViewModel.routeLabel(trip);
    final timeRangeText = TripsViewModel.timeRangeLabel(trip);
    final distanceText = TripsViewModel.distanceLabel(trip.distanceKm);
    final durationText = TripsViewModel.rowDurationLabel(trip);
    final energyText = TripsViewModel.energyLabel(trip.energyConsumedKwh);

    return Semantics(
      button: true,
      label: 'Trip $routeText, $timeRangeText, $distanceText',
      child: Card(
        key: Key('trip_row_${trip.tripId}'),
        elevation: isOngoing ? 2 : 0,
        color: isOngoing
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isOngoing
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isOngoing ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          timeRangeText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isOngoing
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isOngoing) ...[
                        Container(
                          key: Key('trip_in_progress_badge_${trip.tripId}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            TripsViewModel.inProgressLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      StatusChip(
                        label: isOngoing ? 'Ongoing' : 'Completed',
                        type: isOngoing
                            ? ChipStatusType.warning
                            : ChipStatusType.success,
                        icon: isOngoing
                            ? Icons.directions_car_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    routeText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _MetricPill(
                        icon: Icons.straighten_rounded,
                        label: distanceText,
                      ),
                      _MetricPill(
                        icon: Icons.timer_outlined,
                        label: durationText,
                      ),
                      _MetricPill(
                        icon: Icons.bolt_rounded,
                        label: energyText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
