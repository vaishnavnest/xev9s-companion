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
/// Fully adaptive to both Light and Dark theme modes.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewAsync = ref.watch(chargingViewProvider);

    // Sync local ticker with server data
    viewAsync.whenData(_syncDurationTimer);

    final scaffoldBg = isDark
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFEEF5F4);

    return Scaffold(
      backgroundColor: scaffoldBg,
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

  _StatusChipTheme _getStatusChipTheme(
    ChargingState state,
    bool isDark,
    ThemeData theme,
  ) {
    switch (state) {
      case ChargingState.charging:
        return _StatusChipTheme(
          bg: isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.6)
              : const Color(0xFFE6FDF4),
          fg: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
          border: isDark
              ? const Color(0xFF059669).withValues(alpha: 0.6)
              : const Color(0xFFA7F3D0),
          dotColor: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
        );
      case ChargingState.completed:
        return _StatusChipTheme(
          bg: isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.8)
              : const Color(0xFFD1FAE5),
          fg: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
          border: isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.7)
              : const Color(0xFF6EE7B7),
          dotColor: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
        );
      case ChargingState.connected:
        return _StatusChipTheme(
          bg: isDark
              ? const Color(0xFF1E3A5F).withValues(alpha: 0.6)
              : const Color(0xFFEFF6FF),
          fg: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          border: isDark
              ? const Color(0xFF2563EB).withValues(alpha: 0.5)
              : const Color(0xFFBFDBFE),
          dotColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
        );
      case ChargingState.paused:
        return _StatusChipTheme(
          bg: isDark
              ? const Color(0xFF451A03).withValues(alpha: 0.6)
              : const Color(0xFFFFFBEB),
          fg: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          border: isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.5)
              : const Color(0xFFFDE68A),
          dotColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
        );
      case ChargingState.interrupted:
        return _StatusChipTheme(
          bg: isDark
              ? const Color(0xFF450A0A).withValues(alpha: 0.6)
              : const Color(0xFFFEF2F2),
          fg: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
          border: isDark
              ? const Color(0xFFDC2626).withValues(alpha: 0.5)
              : const Color(0xFFFECACA),
          dotColor: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
        );
      case ChargingState.notConnected:
      case ChargingState.unknown:
        return _StatusChipTheme(
          bg: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : const Color(0xFFF1F5F9),
          fg: isDark
              ? theme.colorScheme.onSurfaceVariant
              : const Color(0xFF475569),
          border: isDark
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
          dotColor: isDark
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
              : const Color(0xFF94A3B8),
        );
    }
  }

  Widget _buildStatusAndBatteryCard(
    ThemeData theme,
    ChargingViewState data,
    int? displayDuration,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainer
        : const Color(0xFFF4F9F8);

    final cardBorder = isDark
        ? BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          )
        : const BorderSide(color: Color(0xFFE4EFEB), width: 1);

    final statusStyle = _getStatusChipTheme(data.state, isDark, theme);

    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF0A2540);

    final secondaryText = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF64748B);

    final accentTeal = isDark
        ? const Color(0xFF2DD4BF)
        : const Color(0xFF0D9488);

    final dividerColor = isDark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.35)
        : const Color(0xFFE2EBE9);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: cardBorder,
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
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusStyle.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusStyle.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusStyle.dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            ChargingDisplayHelpers.stateLabel(data.state),
                            style: TextStyle(
                              color: statusStyle.fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.currentSessionId != null)
                    TextButton.icon(
                      key: const Key('current_session_link'),
                      icon: Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: accentTeal,
                      ),
                      label: Text(
                        'Current session',
                        style: TextStyle(
                          color: accentTeal,
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
                      Text(
                        'Battery',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ChargingDisplayHelpers.formatBattery(data.batteryPercent),
                        key: const Key('battery_percent_text'),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: primaryText,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Target',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: secondaryText,
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
                          color: primaryText,
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
                isCharging: data.state == ChargingState.charging,
              ),
              const SizedBox(height: 20),

              // Horizontal Divider
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 18),

              // Charging Power & Session Duration Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Charging Power',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ChargingDisplayHelpers.formatPower(data.powerKw),
                          key: const Key('charging_power_text'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: dividerColor,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Session Duration',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ChargingDisplayHelpers.formatDuration(displayDuration),
                          key: const Key('charging_duration_text'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
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
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainer
        : const Color(0xFFF4F9F8);

    final cardBorder = isDark
        ? BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          )
        : const BorderSide(color: Color(0xFFE4EFEB), width: 1);

    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF0A2540);

    final secondaryText = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF64748B);

    final accentTeal = isDark
        ? const Color(0xFF2DD4BF)
        : const Color(0xFF0D9488);

    final buttonBg = isDark
        ? const Color(0xFF134E4A)
        : const Color(0xFFCEEFEA);

    final buttonFg = isDark
        ? const Color(0xFF5EEAD4)
        : const Color(0xFF004D40);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: cardBorder,
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
                  Icon(Icons.tune, color: accentTeal, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Charging Target',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.targetPercent != null
                              ? 'Target set to ${data.targetPercent}%.'
                              : 'No charge limit set.',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
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
                backgroundColor: buttonBg,
                foregroundColor: buttonFg,
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
              child: Text(
                'Edit target',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: buttonFg,
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
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainer
        : const Color(0xFFF4F9F8);

    final cardBorder = isDark
        ? BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          )
        : const BorderSide(color: Color(0xFFE4EFEB), width: 1);

    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF0A2540);

    final secondaryText = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF64748B);

    final accentTeal = isDark
        ? const Color(0xFF2DD4BF)
        : const Color(0xFF0D9488);

    final buttonBg = isDark
        ? const Color(0xFF134E4A)
        : const Color(0xFFCEEFEA);

    final buttonFg = isDark
        ? const Color(0xFF5EEAD4)
        : const Color(0xFF004D40);

    final schedule = data.schedule;
    final hasSchedule = schedule != null && schedule.enabled;
    final summary = ChargingDisplayHelpers.formatScheduleSummary(schedule);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: cardBorder,
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
                  Icon(
                    Icons.access_time,
                    color: accentTeal,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scheduled Charging',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          key: const Key('schedule_summary_text'),
                          style: TextStyle(
                            fontSize: 13,
                            color: hasSchedule
                                ? primaryText
                                : secondaryText,
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
                backgroundColor: buttonBg,
                foregroundColor: buttonFg,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: buttonFg,
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
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainer
        : const Color(0xFFF4F9F8);

    final cardBorder = isDark
        ? BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          )
        : const BorderSide(color: Color(0xFFE4EFEB), width: 1);

    final primaryText = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF0A2540);

    final secondaryText = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF64748B);

    final buttonBg = isDark
        ? const Color(0xFF134E4A)
        : const Color(0xFFCEEFEA);

    final buttonFg = isDark
        ? const Color(0xFF5EEAD4)
        : const Color(0xFF004D40);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: cardBorder,
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
                children: [
                  Text(
                    'Charging History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review previous charge logs and power telemetry',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('view_history_button'),
              style: FilledButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: buttonFg,
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
              child: Text(
                'View history',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: buttonFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChipTheme {
  const _StatusChipTheme({
    required this.bg,
    required this.fg,
    required this.border,
    required this.dotColor,
  });

  final Color bg;
  final Color fg;
  final Color border;
  final Color dotColor;
}
