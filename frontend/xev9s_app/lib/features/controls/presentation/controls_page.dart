import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide LockState;
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../vehicles/application/vehicle_status_provider.dart';
import '../../vehicles/domain/vehicle_status.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../application/command_session.dart';
import '../application/command_tracker_provider.dart';
import '../domain/command_type.dart';
import 'controls_view_model.dart';
import 'providers/control_availability_provider.dart';
import 'widgets/active_command_card.dart';

/// Remote Controls main screen (UC-05).
class ControlsPage extends ConsumerWidget {
  const ControlsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleId = ref.watch(selectedVehicleProvider);
    final statusAsync = ref.watch(vehicleStatusProvider);

    if (vehicleId == null || vehicleId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Remote Controls')),
        body: const Center(
          child: Text('No vehicle selected'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Controls'),
        actions: [
          IconButton(
            key: const Key('command-history-button'),
            tooltip: 'Command history',
            icon: const Icon(Icons.history),
            onPressed: () => context.go('/controls/history'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(vehicleStatusProvider.notifier).refresh(),
        child: AsyncValueView<VehicleStatus?>(
          value: statusAsync,
          data: (status) {
            if (status == null) {
              return const Center(child: Text('Vehicle status unavailable'));
            }
            return _ControlsBody(
              vehicleId: vehicleId,
              status: status,
            );
          },
        ),
      ),
    );
  }
}

class _ControlsBody extends ConsumerWidget {
  const _ControlsBody({
    required this.vehicleId,
    required this.status,
  });

  final String vehicleId;
  final VehicleStatus status;

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    CommandType type,
  ) async {
    final config = ControlsViewModel.confirmConfigFor(type);
    final confirmed = await ConfirmDialog.show(
      context,
      title: config.title,
      content: config.message,
      confirmLabel: config.confirmLabel,
    );

    if (confirmed) {
      await ref.read(commandTrackerProvider.notifier).submit(vehicleId, type);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final availability = ref.watch(controlAvailabilityProvider);
    final trackerMap = ref.watch(commandTrackerProvider);
    final session = trackerMap[vehicleId] ?? const CommandSession();

    final isOffline = status.connectivity == VehicleConnectivity.offline ||
        status.vehicleState == VehicleState.offline;

    final isCommandActive = session.phase == CommandPhase.submitting ||
        session.phase == CommandPhase.tracking;
    final activeType = session.command?.commandType ?? session.lastAttemptedType;

    final isLockUpdating = isCommandActive &&
        (activeType == CommandType.lock || activeType == CommandType.unlock);
    final isClimateUpdating = isCommandActive &&
        (activeType == CommandType.startPreconditioning ||
            activeType == CommandType.stopPreconditioning);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        final stateCard = _buildCurrentStateCard(
          context,
          theme,
          status,
          isLockUpdating,
          isClimateUpdating,
        );

        final controlsCard = _buildControlsCard(
          context,
          ref,
          theme,
          availability,
          isCommandActive,
        );

        final activeCard = session.phase != CommandPhase.idle
            ? ActiveCommandCard(
                session: session,
                vehicleId: vehicleId,
                onRetry: () =>
                    ref.read(commandTrackerProvider.notifier).retry(vehicleId),
                onConfirmRetry: () => ref
                    .read(commandTrackerProvider.notifier)
                    .confirmUnconfirmedRetry(vehicleId),
                onDismiss: () => ref
                    .read(commandTrackerProvider.notifier)
                    .dismiss(vehicleId),
                onManualPoll: () => ref
                    .read(commandTrackerProvider.notifier)
                    .refreshTrackedCommand(vehicleId),
                onRetryStatusRefresh: () => ref
                    .read(commandTrackerProvider.notifier)
                    .retryVehicleStatusRefresh(vehicleId),
              )
            : const SizedBox.shrink();

        final errorBanner = (session.error != null &&
                session.phase == CommandPhase.idle)
            ? _buildErrorBanner(context, ref, theme, session.error!)
            : const SizedBox.shrink();

        final historyLink = Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            key: const Key('view-history-button'),
            icon: const Icon(Icons.history),
            label: const Text('View command history'),
            onPressed: () => context.go('/controls/history'),
          ),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (isOffline) const StaleBanner(),
                errorBanner,
                if (isWide) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            stateCard,
                            activeCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            controlsCard,
                            const SizedBox(height: 16),
                            historyLink,
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  stateCard,
                  activeCard,
                  const SizedBox(height: 8),
                  controlsCard,
                  const SizedBox(height: 16),
                  historyLink,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppError error,
  ) {
    return Container(
      key: const Key('submit-error-banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: theme.colorScheme.onErrorContainer, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.displayMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            key: const Key('submit-error-dismiss'),
            icon: const Icon(Icons.close, size: 20),
            color: theme.colorScheme.onErrorContainer,
            onPressed: () {
              ref.read(commandTrackerProvider.notifier).dismiss(vehicleId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStateCard(
    BuildContext context,
    ThemeData theme,
    VehicleStatus status,
    bool isLockUpdating,
    bool isClimateUpdating,
  ) {
    final lockLabel = ControlsViewModel.lockStateLabel(status.lockState);
    final climateLabel =
        ControlsViewModel.climateStateLabel(status.preconditioningState);

    final isLocked = status.lockState == LockState.locked;

    final isOffline = status.connectivity == VehicleConnectivity.offline ||
        status.vehicleState == VehicleState.offline;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vehicle State',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StatusChip(
                  label: isOffline ? 'Offline' : 'Online',
                  type: isOffline
                      ? ChipStatusType.error
                      : ChipStatusType.success,
                  icon: isOffline ? Icons.cloud_off : Icons.cloud_done,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLocked ? Icons.lock : Icons.lock_open,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Doors',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            if (isLockUpdating)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Updating...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lockLabel,
                          key: const Key('displayed-lock-state'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.ac_unit,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Climate',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            if (isClimateUpdating)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Updating...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          climateLabel,
                          key: const Key('displayed-climate-state'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    dynamic availability,
    bool isCommandActive,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controls',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Paired Control 1: Lock / Unlock
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Lock vehicle',
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.tonalIcon(
                        key: const Key('control-lock'),
                        icon: const Icon(Icons.lock),
                        label: const Text('Lock'),
                        onPressed: availability.canLock && !isCommandActive
                            ? () => _handleAction(
                                  context,
                                  ref,
                                  CommandType.lock,
                                )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Unlock vehicle',
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.tonalIcon(
                        key: const Key('control-unlock'),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Unlock'),
                        onPressed: availability.canUnlock && !isCommandActive
                            ? () => _handleAction(
                                  context,
                                  ref,
                                  CommandType.unlock,
                                )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (availability.lockDisabledReason != null) ...[
              const SizedBox(height: 6),
              Text(
                availability.lockDisabledReason!,
                key: const Key('lock-disabled-reason'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Paired Control 2: Start Climate / Stop Climate
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Start climate control',
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.tonalIcon(
                        key: const Key('control-climate-start'),
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Start climate'),
                        onPressed: availability.canStartClimate &&
                                !isCommandActive
                            ? () => _handleAction(
                                  context,
                                  ref,
                                  CommandType.startPreconditioning,
                                )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Stop climate control',
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.tonalIcon(
                        key: const Key('control-climate-stop'),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Stop climate'),
                        onPressed:
                            availability.canStopClimate && !isCommandActive
                                ? () => _handleAction(
                                      context,
                                      ref,
                                      CommandType.stopPreconditioning,
                                    )
                                : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (availability.climateDisabledReason != null) ...[
              const SizedBox(height: 6),
              Text(
                availability.climateDisabledReason!,
                key: const Key('climate-disabled-reason'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (availability.drivingHint != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        availability.drivingHint!,
                        key: const Key('driving-hint-text'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
}
