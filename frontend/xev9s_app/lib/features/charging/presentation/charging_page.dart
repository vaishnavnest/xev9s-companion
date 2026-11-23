import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/stale_banner.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../vehicles/domain/vehicle_status.dart';
import 'charging_display_helpers.dart';
import 'providers/charging_overview_provider.dart';
import 'providers/charging_view_provider.dart';
import 'widgets/charging_progress_bar.dart';
import 'widgets/schedule_editor_sheet.dart';
import 'widgets/target_slider_sheet.dart';

/// Charging overview screen (UC-04) showing battery state, power, saved target,
/// schedule, and session entry points.
class ChargingPage extends ConsumerStatefulWidget {
  const ChargingPage({super.key});

  @override
  ConsumerState<ChargingPage> createState() => _ChargingPageState();
}

class _ChargingPageState extends ConsumerState<ChargingPage> {
  Timer? _ticker;
  int? _tickingDurationSeconds;
  int? _serverDurationBase;
  ChargingState? _lastState;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncDurationTimer(ChargingViewState? data) {
    if (data == null) {
      _ticker?.cancel();
      _tickingDurationSeconds = null;
      _serverDurationBase = null;
      _lastState = null;
      return;
    }

    final isCharging = data.state == ChargingState.charging;
    final serverDuration = data.sessionDurationSeconds;

    // If server value changed or state changed, rebase timer
    if (serverDuration != _serverDurationBase || data.state != _lastState) {
      _serverDurationBase = serverDuration;
      _tickingDurationSeconds = serverDuration;
      _lastState = data.state;

      _ticker?.cancel();
      if (isCharging && serverDuration != null) {
        _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _tickingDurationSeconds = (_tickingDurationSeconds ?? 0) + 1;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewAsync = ref.watch(chargingViewProvider);

    // Sync local ticker with server data
    viewAsync.whenData(_syncDurationTimer);

    return Scaffold(
      body: AsyncValueView<ChargingViewState?>(
        value: viewAsync,
        onRetry: () => ref.read(chargingOverviewProvider.notifier).refresh(),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No vehicle selected'));
          }
          return _buildContent(context, data);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChargingViewState data) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    final displayDuration = data.state == ChargingState.charging
        ? (_tickingDurationSeconds ?? data.sessionDurationSeconds)
        : data.sessionDurationSeconds;

    final chipType = switch (data.state) {
      ChargingState.charging => ChipStatusType.success,
      ChargingState.completed => ChipStatusType.success,
      ChargingState.paused => ChipStatusType.warning,
      ChargingState.interrupted => ChipStatusType.error,
      _ => ChipStatusType.info,
    };

    final content = RefreshIndicator(
      onRefresh: () => ref.read(chargingOverviewProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data.isOffline) ...[
                  StaleBanner(
                    lastUpdatedAt: data.lastUpdatedAt,
                    message:
                        'Vehicle is offline. Live charging telemetry may be outdated.',
                  ),
                  const SizedBox(height: 12),
                ],

                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildStatusAndBatteryCard(
                              theme,
                              data,
                              chipType,
                              displayDuration,
                            ),
                            const SizedBox(height: 16),
                            _buildHistoryCard(context, theme, data),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildTargetCard(context, theme, data),
                            const SizedBox(height: 16),
                            _buildScheduleCard(context, theme, data),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildStatusAndBatteryCard(
                    theme,
                    data,
                    chipType,
                    displayDuration,
                  ),
                  const SizedBox(height: 16),
                  _buildTargetCard(context, theme, data),
                  const SizedBox(height: 16),
                  _buildScheduleCard(context, theme, data),
                  const SizedBox(height: 16),
                  _buildHistoryCard(context, theme, data),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return content;
  }

  Widget _buildStatusAndBatteryCard(
    ThemeData theme,
    ChargingViewState data,
    ChipStatusType chipType,
    int? displayDuration,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Opacity(
          opacity: data.isOffline ? 0.65 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // State chip + textual description
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                    key: const Key('charging_status_chip'),
                    label: ChargingDisplayHelpers.stateLabel(data.state),
                    type: chipType,
                    icon: data.state == ChargingState.charging
                        ? Icons.bolt
                        : (data.state == ChargingState.interrupted
                            ? Icons.error_outline
                            : null),
                  ),
                  if (data.currentSessionId != null)
                    TextButton.icon(
                      key: const Key('current_session_link'),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Current session'),
                      onPressed: () {
                        context.go('/charging/sessions/${data.currentSessionId}');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Battery % large + separate target indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Battery',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ChargingDisplayHelpers.formatBattery(data.batteryPercent),
                        key: const Key('battery_percent_text'),
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Target',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        data.targetPercent != null ? '${data.targetPercent}%' : '-',
                        key: const Key('target_percent_text'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar with distinct target marker
              ChargingProgressBar(
                batteryPercent: data.batteryPercent,
                targetPercent: data.targetPercent,
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Power and Session Duration telemetry
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Charging Power',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ChargingDisplayHelpers.formatPower(data.powerKw),
                          key: const Key('charging_power_text'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Session Duration',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ChargingDisplayHelpers.formatDuration(displayDuration),
                          key: const Key('charging_duration_text'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(
    BuildContext context,
    ThemeData theme,
    ChargingViewState data,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Charging Target',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  key: const Key('edit_target_button'),
                  onPressed: () {
                    TargetSliderSheet.show(
                      context,
                      initialTarget: data.targetPercent,
                      currentBatteryPercent: data.batteryPercent,
                      isVehicleOffline: data.isOffline,
                    );
                  },
                  child: const Text('Edit target'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.targetPercent != null
                  ? 'Charging stops automatically when battery reaches ${data.targetPercent}%.'
                  : 'No charge limit set.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    ThemeData theme,
    ChargingViewState data,
  ) {
    final schedule = data.schedule;
    final hasSchedule = schedule != null && schedule.enabled;
    final summary = ChargingDisplayHelpers.formatScheduleSummary(schedule);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alarm, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Scheduled Charging',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  key: const Key('edit_schedule_button'),
                  onPressed: () {
                    ScheduleEditorSheet.show(
                      context,
                      initialSchedule: schedule,
                      isVehicleOffline: data.isOffline,
                    );
                  },
                  child: Text(hasSchedule ? 'Edit' : 'Set schedule'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary,
              key: const Key('schedule_summary_text'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: hasSchedule
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    ThemeData theme,
    ChargingViewState data,
  ) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Charging History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review previous charge logs and power telemetry',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            FilledButton.icon(
              key: const Key('view_history_button'),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('View history'),
              onPressed: () {
                context.go('/charging/sessions');
              },
            ),
          ],
        ),
      ),
    );
  }
}
