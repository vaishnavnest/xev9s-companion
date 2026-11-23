import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_codes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../vehicles/domain/vehicle_status.dart';
import 'charging_display_helpers.dart';
import '../domain/charging_session.dart';
import 'providers/charging_session_detail_provider.dart';

/// Charging session detail page (/charging/sessions/:sessionId)
class ChargingSessionDetailPage extends ConsumerWidget {
  const ChargingSessionDetailPage({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(chargingSessionDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/charging/sessions'),
        ),
      ),
      body: detailAsync.when(
        loading: () => const LoadingView(message: 'Loading session details...'),
        error: (error, st) {
          final is404 = error is AppError &&
              (error.code == ApiErrorCode.notFound ||
                  error.code == ApiErrorCode.vehicleNotFound);

          if (is404) {
            return Center(
              child: EmptyState(
                key: const Key('session_not_found'),
                title: 'Session not found',
                message: 'The requested charging session could not be located.',
                actionLabel: 'Back to sessions',
                onAction: () => context.go('/charging/sessions'),
              ),
            );
          }

          final appError =
              error is AppError ? error : AppError.unknown(error.toString());
          return ErrorView(
            error: appError,
            message: appError.displayMessage,
            onRetry: () => ref.invalidate(chargingSessionDetailProvider(sessionId)),
          );
        },
        data: (session) => _buildDetailContent(context, theme, session),
      ),
    );
  }

  Widget _buildDetailContent(
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // In-progress banner
              if (session.isActive) ...[
                Container(
                  key: const Key('in_progress_banner'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This charging session is currently in progress.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Interrupted reason prominently
              if (session.isInterrupted) ...[
                Container(
                  key: const Key('interrupted_banner'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Charging Interrupted',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              session.interruptionReason ??
                                  'Session was prematurely disconnected or power was lost.',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Session Summary Card
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildRow(
                        theme,
                        'Status',
                        trailing: StatusChip(
                          label: ChargingDisplayHelpers.stateLabel(session.status),
                          type: chipType,
                        ),
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'Started',
                        value: Formatters.formatDateTime(session.startedAt),
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'Ended',
                        value: session.endedAt != null
                            ? Formatters.formatDateTime(session.endedAt!)
                            : 'In progress',
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'Duration',
                        value: ChargingDisplayHelpers.formatDuration(
                          session.durationSeconds,
                        ),
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'Start Battery',
                        value: ChargingDisplayHelpers.formatBattery(
                          session.startBatteryPercent,
                        ),
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'End Battery',
                        value: ChargingDisplayHelpers.formatBattery(
                          session.endBatteryPercent,
                        ),
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'Target',
                        value: session.targetPercent != null
                            ? '${session.targetPercent}%'
                            : '-',
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'Average Power',
                        value: ChargingDisplayHelpers.formatPower(
                          session.avgPowerKw,
                        ),
                      ),
                      const Divider(),
                      _buildRow(
                        theme,
                        'Max Power',
                        value: ChargingDisplayHelpers.formatPower(
                          session.maxPowerKw,
                        ),
                      ),
                      if (session.interruptionReason != null) ...[
                        const Divider(),
                        _buildRow(
                          theme,
                          'Interruption Reason',
                          value: session.interruptionReason!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    ThemeData theme,
    String label, {
    String? value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: trailing ??
                Text(
                  value ?? '-',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
