import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../application/command_session.dart';
import '../../domain/command_status.dart';
import '../../domain/command_type.dart';
import '../controls_view_model.dart';

/// Card showing the current in-flight or recently completed command status (UC-05).
class ActiveCommandCard extends StatefulWidget {
  const ActiveCommandCard({
    super.key,
    required this.session,
    required this.vehicleId,
    required this.onRetry,
    required this.onConfirmRetry,
    required this.onDismiss,
    required this.onManualPoll,
    required this.onRetryStatusRefresh,
  });

  final CommandSession session;
  final String vehicleId;
  final VoidCallback onRetry;
  final VoidCallback onConfirmRetry;
  final VoidCallback onDismiss;
  final VoidCallback onManualPoll;
  final VoidCallback onRetryStatusRefresh;

  @override
  State<ActiveCommandCard> createState() => _ActiveCommandCardState();
}

class _ActiveCommandCardState extends State<ActiveCommandCard> {
  Timer? _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startOrUpdateTicker();
  }

  @override
  void didUpdateWidget(ActiveCommandCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.phase != oldWidget.session.phase ||
        widget.session.startedAt != oldWidget.session.startedAt) {
      _startOrUpdateTicker();
    }
  }

  void _startOrUpdateTicker() {
    _ticker?.cancel();
    if (widget.session.phase == CommandPhase.tracking ||
        widget.session.phase == CommandPhase.submitting) {
      final started = widget.session.startedAt ?? DateTime.now();
      _elapsedSeconds = DateTime.now().difference(started).inSeconds;
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _elapsedSeconds = DateTime.now().difference(started).inSeconds;
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;

    if (session.phase == CommandPhase.idle) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (session.phase) {
          CommandPhase.submitting => _buildSubmitting(context, theme),
          CommandPhase.tracking => _buildTracking(context, theme),
          CommandPhase.submitUnconfirmed =>
            _buildSubmitUnconfirmed(context, theme),
          CommandPhase.finished => _buildFinished(context, theme),
          CommandPhase.idle => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _buildSubmitting(BuildContext context, ThemeData theme) {
    final typeLabel =
        widget.session.lastAttemptedType?.label ?? 'Command';

    return Row(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sending request...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Submitting $typeLabel to vehicle',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTracking(BuildContext context, ThemeData theme) {
    final command = widget.session.command;
    final typeLabel = command?.commandType.label ??
        widget.session.lastAttemptedType?.label ??
        'Command';
    final status = command?.status ?? CommandStatus.submitted;
    final currentStep = ControlsViewModel.progressStepIndex(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              typeLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ControlsViewModel.formatElapsed(_elapsedSeconds),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStepProgressBar(theme, currentStep),
        const SizedBox(height: 16),
        if (widget.session.stoppedWaiting) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Still waiting. Check the history later.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (widget.session.waitingTooLong) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_bottom,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is taking longer than expected. We will keep checking.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('command-refresh-status'),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh status'),
                    onPressed: widget.onManualPoll,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepProgressBar(ThemeData theme, int currentStep) {
    const steps = ['Submitted', 'Accepted', 'Executing', 'Result'];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i <= currentStep
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  child: i < currentStep
                      ? Icon(Icons.check,
                          size: 14, color: theme.colorScheme.onPrimary)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: i == currentStep
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == currentStep
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i <= currentStep
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < currentStep
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                margin: const EdgeInsets.only(bottom: 16),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSubmitUnconfirmed(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: theme.colorScheme.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "We couldn't confirm that the request was sent.",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'A connection issue occurred while dispatching the command. You can safely try again without duplicating the request.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const Key('command-check-history'),
              onPressed: () => context.go('/controls/history'),
              child: const Text('Check history'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('command-retry-unconfirmed'),
              onPressed: widget.onConfirmRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinished(BuildContext context, ThemeData theme) {
    final command = widget.session.command;
    final status = command?.status ?? CommandStatus.unknown;
    final type = command?.commandType ??
        widget.session.lastAttemptedType ??
        CommandType.unknown;

    if (status == CommandStatus.succeeded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ControlsViewModel.successTitle(type),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.session.refreshFailed) ...[
            Text(
              "Command succeeded, but we couldn't refresh the vehicle state.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('command-dismiss'),
                  onPressed: widget.onDismiss,
                  child: const Text('Dismiss'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: const Key('command-retry-refresh'),
                  onPressed: widget.onRetryStatusRefresh,
                  child: const Text('Retry refresh'),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Vehicle state successfully verified.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('command-dismiss'),
                onPressed: widget.onDismiss,
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ],
      );
    }

    if (status == CommandStatus.timedOut) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_off_outlined,
                  color: theme.colorScheme.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The vehicle did not respond in time',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The request timed out before the vehicle could confirm execution.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('command-dismiss'),
                onPressed: widget.onDismiss,
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('command-retry'),
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      );
    }

    // Default: FAILED
    final reason = command?.failureReason ??
        'The vehicle did not complete the request.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline,
                color: theme.colorScheme.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Command failed',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          reason,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const Key('command-dismiss'),
              onPressed: widget.onDismiss,
              child: const Text('Dismiss'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('command-retry'),
              onPressed: widget.onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ],
    );
  }
}
