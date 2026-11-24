import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../domain/command.dart';
import '../domain/command_status.dart';
import '../domain/command_type.dart';
import 'controls_view_model.dart';
import 'providers/command_history_provider.dart';

/// Command history screen displaying paginated remote commands (UC-05).
class ControlsHistoryPage extends ConsumerStatefulWidget {
  const ControlsHistoryPage({super.key});

  @override
  ConsumerState<ControlsHistoryPage> createState() =>
      _ControlsHistoryPageState();
}

class _ControlsHistoryPageState extends ConsumerState<ControlsHistoryPage> {
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
    if (currentScroll >= maxScroll - 200) {
      ref.read(commandHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleId = ref.watch(selectedVehicleProvider);
    final historyAsync = ref.watch(commandHistoryProvider);

    if (vehicleId == null || vehicleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Command History')),
        body: const Center(child: Text('No vehicle selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Command History'),
      ),
      body: AsyncValueView<CommandHistoryState>(
        value: historyAsync,
        data: (state) {
          return Column(
            children: [
              _buildFiltersBar(context, state),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(commandHistoryProvider.notifier).refresh(),
                  child: _buildListContent(context, state),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersBar(BuildContext context, CommandHistoryState state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(
                  label: 'All',
                  isSelected: state.statusFilter == null,
                  onSelected: () => ref
                      .read(commandHistoryProvider.notifier)
                      .setStatusFilter(null),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  label: 'Succeeded',
                  isSelected: state.statusFilter == CommandStatus.succeeded,
                  onSelected: () => ref
                      .read(commandHistoryProvider.notifier)
                      .setStatusFilter(CommandStatus.succeeded),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  label: 'Failed',
                  isSelected: state.statusFilter == CommandStatus.failed,
                  onSelected: () => ref
                      .read(commandHistoryProvider.notifier)
                      .setStatusFilter(CommandStatus.failed),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  label: 'Timed out',
                  isSelected: state.statusFilter == CommandStatus.timedOut,
                  onSelected: () => ref
                      .read(commandHistoryProvider.notifier)
                      .setStatusFilter(CommandStatus.timedOut),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  label: 'In progress',
                  isSelected: state.statusFilter == CommandStatus.executing,
                  onSelected: () => ref
                      .read(commandHistoryProvider.notifier)
                      .setStatusFilter(CommandStatus.executing),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Type Dropdown Filter
          Row(
            children: [
              Text(
                'Type:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<CommandType?>(
                key: const Key('command-type-dropdown'),
                value: state.typeFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Types')),
                  DropdownMenuItem(
                      value: CommandType.lock, child: Text('Lock')),
                  DropdownMenuItem(
                      value: CommandType.unlock, child: Text('Unlock')),
                  DropdownMenuItem(
                      value: CommandType.startPreconditioning,
                      child: Text('Start climate')),
                  DropdownMenuItem(
                      value: CommandType.stopPreconditioning,
                      child: Text('Stop climate')),
                ],
                onChanged: (type) {
                  ref.read(commandHistoryProvider.notifier).setTypeFilter(type);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildListContent(BuildContext context, CommandHistoryState state) {
    if (state.items.isEmpty) {
      final hasActiveFilter =
          state.statusFilter != null || state.typeFilter != null;
      return EmptyState(
        title: hasActiveFilter ? 'No matching commands' : 'No commands yet',
        message: hasActiveFilter
            ? 'Try adjusting or clearing your filters to see past commands.'
            : 'Commands dispatched from Remote Controls will appear here.',
        actionLabel: hasActiveFilter ? 'Clear filters' : null,
        onAction: hasActiveFilter
            ? () {
                ref.read(commandHistoryProvider.notifier).setStatusFilter(null);
                ref.read(commandHistoryProvider.notifier).setTypeFilter(null);
              }
            : null,
      );
    }

    final itemCount = state.items.length + (state.hasMore ? 1 : 0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView.separated(
          key: const PageStorageKey('command-history-list'),
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == state.items.length) {
              return _buildLoadMoreFooter(context, state);
            }
            final command = state.items[index];
            return _buildHistoryItem(context, command);
          },
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Command command) {
    final theme = Theme.of(context);
    final requestedStr = Formatters.formatDateTime(command.requestedAt);
    final completedStr = ControlsViewModel.completedTimeLabel(command);

    final (ChipStatusType chipType, IconData chipIcon, String chipLabel) =
        switch (command.status) {
      CommandStatus.succeeded => (
          ChipStatusType.success,
          Icons.check_circle_outline,
          'Succeeded'
        ),
      CommandStatus.failed => (
          ChipStatusType.error,
          Icons.error_outline,
          'Failed'
        ),
      CommandStatus.timedOut => (
          ChipStatusType.warning,
          Icons.access_time,
          'Timed out'
        ),
      _ => (ChipStatusType.info, Icons.sync, 'In progress'),
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  command.commandType.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StatusChip(
                  label: chipLabel,
                  type: chipType,
                  icon: chipIcon,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Requested: $requestedStr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Completed: $completedStr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (command.failureReason != null &&
                command.failureReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        command.failureReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter(BuildContext context, CommandHistoryState state) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Text('Failed to load more commands'),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('retry-load-more'),
              onPressed: () =>
                  ref.read(commandHistoryProvider.notifier).retryLoadMore(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return const Padding(
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
}
