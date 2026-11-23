import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/stale_banner.dart';
import '../../vehicles/domain/vehicle_status.dart';
import 'charging_display_helpers.dart';
import 'providers/charging_overview_provider.dart';
import 'providers/charging_view_provider.dart';
import 'widgets/charging_progress_bar.dart';
import 'widgets/schedule_editor_sheet.dart';
import 'widgets/target_slider_sheet.dart';

/// Charging overview screen (UC-04) customized to match the design specifications
/// with a 10-segment capsule battery indicator, rounded mint cards, and teal pill buttons.
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
      backgroundColor: const Color(0xFFEEF5F4),
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

    final content = RefreshIndicator(
      onRefresh: () => ref.read(chargingOverviewProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
    int? displayDuration,
  ) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF4F9F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE4EFEB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Opacity(
          opacity: data.isOffline ? 0.65 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row: Status chip + optional current session link
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    key: const Key('charging_status_chip'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EDED),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      ChargingDisplayHelpers.stateLabel(data.state),
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (data.currentSessionId != null)
                    TextButton.icon(
                      key: const Key('current_session_link'),
                      icon: const Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Color(0xFF0D9488),
                      ),
                      label: const Text(
                        'Current session',
                        style: TextStyle(
                          color: Color(0xFF0D9488),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        context.go('/charging/sessions/${data.currentSessionId}');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Battery & Target row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Battery',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ChargingDisplayHelpers.formatBattery(data.batteryPercent),
                        key: const Key('battery_percent_text'),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0A2540),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Target',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.targetPercent != null
                            ? '${data.targetPercent}%'
                            : '-',
                        key: const Key('target_percent_text'),
                        style: TextStyle(
                          fontSize: data.targetPercent != null ? 32 : 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0A2540),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 10-Segment Capsule Progress Bar
              ChargingProgressBar(
                batteryPercent: data.batteryPercent,
                targetPercent: data.targetPercent,
              ),
              const SizedBox(height: 20),

              // Horizontal Divider
              const Divider(color: Color(0xFFE2EBE9), height: 1, thickness: 1),
              const SizedBox(height: 18),

              // Charging Power & Session Duration Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Charging Power',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ChargingDisplayHelpers.formatPower(data.powerKw),
                          key: const Key('charging_power_text'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: const Color(0xFFE2EBE9),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Session Duration',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ChargingDisplayHelpers.formatDuration(displayDuration),
                          key: const Key('charging_duration_text'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A2540),
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
      color: const Color(0xFFF4F9F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE4EFEB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF0D9488), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Charging Target',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.targetPercent != null
                              ? 'Target set to ${data.targetPercent}%.'
                              : 'No charge limit set.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('edit_target_button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCEEFEA),
                foregroundColor: const Color(0xFF004D40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              onPressed: () {
                TargetSliderSheet.show(
                  context,
                  initialTarget: data.targetPercent,
                  currentBatteryPercent: data.batteryPercent,
                  isVehicleOffline: data.isOffline,
                );
              },
              child: const Text(
                'Edit target',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF004D40),
                ),
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
      color: const Color(0xFFF4F9F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE4EFEB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Color(0xFF0D9488),
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scheduled Charging',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          key: const Key('schedule_summary_text'),
                          style: TextStyle(
                            fontSize: 13,
                            color: hasSchedule
                                ? const Color(0xFF0A2540)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('edit_schedule_button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCEEFEA),
                foregroundColor: const Color(0xFF004D40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              onPressed: () {
                ScheduleEditorSheet.show(
                  context,
                  initialSchedule: schedule,
                  isVehicleOffline: data.isOffline,
                );
              },
              child: Text(
                hasSchedule ? 'Edit schedule' : 'Set schedule',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF004D40),
                ),
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
      color: const Color(0xFFF4F9F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE4EFEB), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Charging History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Review previous charge logs and power telemetry',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('view_history_button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCEEFEA),
                foregroundColor: const Color(0xFF004D40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              onPressed: () {
                context.go('/charging/sessions');
              },
              child: const Text(
                'View history',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF004D40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
