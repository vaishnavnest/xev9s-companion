import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide LockState;
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
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
      return const Scaffold(
        body: Center(
          child: Text('No vehicle selected'),
        ),
      );
    }

    return Scaffold(
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
          status,
          availability,
          isOffline,
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
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            elevation: 2,
            shadowColor: theme.shadowColor.withValues(alpha: 0.14),
            shape: const StadiumBorder(),
            child: InkWell(
              key: const Key('view-history-button'),
              customBorder: const StadiumBorder(),
              onTap: () => context.go('/controls/history'),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View command history',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                            const SizedBox(height: 12),
                            activeCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            controlsCard,
                            const SizedBox(height: 24),
                            historyLink,
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  stateCard,
                  const SizedBox(height: 12),
                  activeCard,
                  controlsCard,
                  const SizedBox(height: 28),
                  historyLink,
                  const SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(14),
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
    final isClimateOn =
        status.preconditioningState == PreconditioningState.active;
    final isOffline = status.connectivity == VehicleConnectivity.offline ||
        status.vehicleState == VehicleState.offline;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOffline
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VEHICLE STATE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                  child: _StateMetricTile(
                    title: 'DOORS',
                    value: lockLabel,
                    valueKey: const Key('displayed-lock-state'),
                    icon: isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    isHighlighted: isLocked,
                    isUpdating: isLockUpdating,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StateMetricTile(
                    title: 'CLIMATE',
                    value: climateLabel,
                    valueKey: const Key('displayed-climate-state'),
                    icon: Icons.ac_unit_rounded,
                    isHighlighted: isClimateOn,
                    isUpdating: isClimateUpdating,
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
    VehicleStatus status,
    dynamic availability,
    bool isOffline,
    bool isCommandActive,
  ) {
    final isLocked = status.lockState == LockState.locked;
    final isClimateOn =
        status.preconditioningState == PreconditioningState.active;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Key-fob header: FOB-433Mhz | Controls | SIGNAL dot
            Row(
              children: [
                Expanded(
                  child: Text(
                    'FOB-433Mhz',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Controls',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'SIGNAL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PulsingSignalDot(
                        isOffline: isOffline,
                        isTransmitting: isCommandActive,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Recessed key-fob housing with dual vertical rocker switches
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RockerSwitchPair(
                      activeTop: isLocked,
                      topKey: const Key('control-lock'),
                      topIcon: Icons.lock_rounded,
                      topLabel: 'Lock',
                      topSemantics: 'Lock vehicle',
                      onTopPressed: availability.canLock && !isCommandActive
                          ? () => _handleAction(
                                context,
                                ref,
                                CommandType.lock,
                              )
                          : null,
                      bottomKey: const Key('control-unlock'),
                      bottomIcon: Icons.lock_open_rounded,
                      bottomLabel: 'Unlock',
                      bottomSemantics: 'Unlock vehicle',
                      onBottomPressed:
                          availability.canUnlock && !isCommandActive
                              ? () => _handleAction(
                                    context,
                                    ref,
                                    CommandType.unlock,
                                  )
                              : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _RockerSwitchPair(
                      activeTop: isClimateOn,
                      topKey: const Key('control-climate-start'),
                      topIcon: Icons.power_settings_new_rounded,
                      topLabel: 'Start climate',
                      topSemantics: 'Start climate control',
                      onTopPressed:
                          availability.canStartClimate && !isCommandActive
                              ? () => _handleAction(
                                    context,
                                    ref,
                                    CommandType.startPreconditioning,
                                  )
                              : null,
                      bottomKey: const Key('control-climate-stop'),
                      bottomIcon: Icons.stop_circle_outlined,
                      bottomLabel: 'Stop climate',
                      bottomSemantics: 'Stop climate control',
                      onBottomPressed:
                          availability.canStopClimate && !isCommandActive
                              ? () => _handleAction(
                                    context,
                                    ref,
                                    CommandType.stopPreconditioning,
                                  )
                              : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FobIndicatorBars(isTransmitting: isCommandActive),
            if (availability.lockDisabledReason != null) ...[
              const SizedBox(height: 12),
              Text(
                availability.lockDisabledReason!,
                key: const Key('lock-disabled-reason'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (availability.climateDisabledReason != null &&
                availability.climateDisabledReason !=
                    availability.lockDisabledReason) ...[
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
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

class _StateMetricTile extends StatelessWidget {
  const _StateMetricTile({
    required this.title,
    required this.value,
    required this.valueKey,
    required this.icon,
    required this.isHighlighted,
    required this.isUpdating,
  });

  final String title;
  final String value;
  final Key valueKey;
  final IconData icon;
  final bool isHighlighted;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.32)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              value,
              key: valueKey,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isUpdating) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Updating...',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Vertical rocker-switch housing with a sliding animated toggle highlight
/// between the top and bottom [FilledButton] controls.
class _RockerSwitchPair extends StatelessWidget {
  const _RockerSwitchPair({
    required this.activeTop,
    required this.topKey,
    required this.topIcon,
    required this.topLabel,
    required this.topSemantics,
    required this.onTopPressed,
    required this.bottomKey,
    required this.bottomIcon,
    required this.bottomLabel,
    required this.bottomSemantics,
    required this.onBottomPressed,
  });

  final bool activeTop;
  final Key topKey;
  final IconData topIcon;
  final String topLabel;
  final String topSemantics;
  final VoidCallback? onTopPressed;

  final Key bottomKey;
  final IconData bottomIcon;
  final String bottomLabel;
  final String bottomSemantics;
  final VoidCallback? onBottomPressed;

  static const double _halfHeight = 68;
  static const double _totalHeight = _halfHeight * 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final highlightFill = isDark
        ? theme.colorScheme.primary.withValues(alpha: 0.24)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.65);

    return Container(
      height: _totalHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sliding animated rocker highlight
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: activeTop ? Alignment.topCenter : Alignment.bottomCenter,
            child: Container(
              height: _halfHeight,
              decoration: BoxDecoration(
                color: highlightFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              _RockerHalfButton(
                buttonKey: topKey,
                icon: topIcon,
                label: topLabel,
                semanticsLabel: topSemantics,
                isHighlighted: activeTop,
                onPressed: onTopPressed,
              ),
              _RockerHalfButton(
                buttonKey: bottomKey,
                icon: bottomIcon,
                label: bottomLabel,
                semanticsLabel: bottomSemantics,
                isHighlighted: !activeTop,
                onPressed: onBottomPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RockerHalfButton extends StatelessWidget {
  const _RockerHalfButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.isHighlighted,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final String semanticsLabel;
  final bool isHighlighted;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;
    final fgColor = isHighlighted
        ? theme.colorScheme.primary
        : isEnabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);

    return Expanded(
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: buttonKey,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: fgColor,
              disabledForegroundColor: fgColor,
              shadowColor: Colors.transparent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: isHighlighted ? 1.03 : 0.97,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: fgColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _PulsingSignalDot extends StatelessWidget {
  const _PulsingSignalDot({
    required this.isOffline,
    required this.isTransmitting,
  });

  final bool isOffline;
  final bool isTransmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = isOffline
        ? AppTheme.errorColor
        : isTransmitting
            ? AppTheme.warningColor
            : theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: isTransmitting ? 11 : 9,
      height: isTransmitting ? 11 : 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor,
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: isTransmitting ? 0.65 : 0.4),
            blurRadius: isTransmitting ? 10 : 4,
            spreadRadius: isTransmitting ? 2 : 0.5,
          ),
        ],
      ),
    );
  }
}

class _FobIndicatorBars extends StatelessWidget {
  const _FobIndicatorBars({required this.isTransmitting});

  final bool isTransmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = theme.colorScheme.outlineVariant;
    final active = theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 18,
          height: 3.5,
          decoration: BoxDecoration(
            color: isTransmitting ? active.withValues(alpha: 0.5) : inactive,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isTransmitting ? 34 : 26,
          height: 3.5,
          decoration: BoxDecoration(
            color: isTransmitting ? active : inactive,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 18,
          height: 3.5,
          decoration: BoxDecoration(
            color: isTransmitting ? active.withValues(alpha: 0.5) : inactive,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
