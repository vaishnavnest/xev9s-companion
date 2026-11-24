import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../vehicles/domain/vehicle_status.dart';
import 'charging_display_helpers.dart';
import '../domain/charging_session.dart';
import 'providers/charging_sessions_provider.dart';

/// Charging session history list page (/charging/sessions) with status filters and infinite scroll.
class ChargingSessionsPage extends ConsumerStatefulWidget {
  const ChargingSessionsPage({super.key});

  @override
  ConsumerState<ChargingSessionsPage> createState() =>
      _ChargingSessionsPageState();
}

class _ChargingSessionsPageState extends ConsumerState<ChargingSessionsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Load next page when user scrolls near the bottom (within 200px)
    if (currentScroll >= maxScroll - 200) {
      ref.read(chargingSessionsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(chargingSessionsProvider);
    final currentFilter = sessionsAsync.hasValue ? sessionsAsync.value!.statusFilter : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charging History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/charging'),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          _buildFilterChips(currentFilter),
          const Divider(height: 1),

          // Content
          Expanded(
            child: AsyncValueView<ChargingSessionsState>(
              value: sessionsAsync,
              onRetry: () => ref.read(chargingSessionsProvider.notifier).refresh(),
              isEmpty: (state) => state.items.isEmpty,
              empty: _buildEmptyState(currentFilter),
              data: (state) {
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(chargingSessionsProvider.notifier).refresh(),
                  child: ListView.separated(
                    key: const Key('sessions_list_view'),
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: state.items.length + (state.isLoadingMore ? 1 : 0) + (state.loadMoreError != null ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index < state.items.length) {
                        final session = state.items[index];
                        return _buildSessionCard(context, theme, session);
                      }

                      if (state.isLoadingMore) {
                        return const Padding(
                          key: Key('pagination_loader'),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      if (state.loadMoreError != null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Failed to load more sessions.'),
                              TextButton(
                                key: const Key('retry_load_more_button'),
                                onPressed: () {
                                  ref
                                      .read(chargingSessionsProvider.notifier)
                                      .loadMore();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ChargingState? currentFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            key: const Key('filter_all'),
            label: const Text('All'),
            selected: currentFilter == null,
            onSelected: (_) {
              ref.read(chargingSessionsProvider.notifier).setFilter(null);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const Key('filter_completed'),
            label: const Text('Completed'),
            selected: currentFilter == ChargingState.completed,
            onSelected: (_) {
              ref
                  .read(chargingSessionsProvider.notifier)
                  .setFilter(ChargingState.completed);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const Key('filter_interrupted'),
            label: const Text('Interrupted'),
            selected: currentFilter == ChargingState.interrupted,
            onSelected: (_) {
              ref
                  .read(chargingSessionsProvider.notifier)
                  .setFilter(ChargingState.interrupted);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            key: const Key('filter_charging'),
            label: const Text('Charging'),
            selected: currentFilter == ChargingState.charging,
            onSelected: (_) {
              ref
                  .read(chargingSessionsProvider.notifier)
                  .setFilter(ChargingState.charging);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ChargingState? filter) {
    final hasFilter = filter != null;
    return Center(
      child: EmptyState(
        key: const Key('sessions_empty_state'),
        title: hasFilter
            ? 'No ${ChargingDisplayHelpers.stateLabel(filter).toLowerCase()} sessions'
            : 'No charging sessions yet',
        message: hasFilter
            ? 'Try selecting a different filter or clearing active filters.'
            : 'Plug in your XEV 9S to start recording charging sessions.',
        actionLabel: hasFilter ? 'Clear filter' : null,
        onAction: hasFilter
            ? () {
                ref.read(chargingSessionsProvider.notifier).setFilter(null);
              }
            : null,
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    ThemeData theme,
    ChargingSession session,
  ) {
    final chipType = switch (session.status) {
      ChargingState.completed => ChipStatusType.success,
      ChargingState.charging => ChipStatusType.success,
      ChargingState.interrupted => ChipStatusType.error,
      ChargingState.paused => ChipStatusType.warning,
      _ => ChipStatusType.info,
    };

    final transition = ChargingDisplayHelpers.formatBatteryTransition(
      session.startBatteryPercent,
      session.endBatteryPercent,
    );

    return Card(
      key: Key('session_item_${session.sessionId}'),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go('/charging/sessions/${session.sessionId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.formatDateTime(session.startedAt),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (session.isActive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'In progress',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      StatusChip(
                        label: ChargingDisplayHelpers.stateLabel(session.status),
                        type: chipType,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Battery',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transition,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Duration',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ChargingDisplayHelpers.formatDuration(
                          session.durationSeconds,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
