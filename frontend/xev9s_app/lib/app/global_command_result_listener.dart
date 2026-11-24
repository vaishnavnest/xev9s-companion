import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../features/controls/application/command_session.dart';
import '../features/controls/application/command_tracker_provider.dart';
import '../features/controls/domain/command.dart';
import '../features/controls/domain/command_status.dart';
import '../features/vehicles/application/vehicles_controller.dart';
import 'router.dart';

/// Global listener placed above the router shell that observes command outcomes
/// and surfaces SnackBars when completed while navigating outside /controls (UC-05).
class GlobalCommandResultListener extends ConsumerStatefulWidget {
  const GlobalCommandResultListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<GlobalCommandResultListener> createState() =>
      _GlobalCommandResultListenerState();
}

class _GlobalCommandResultListenerState
    extends ConsumerState<GlobalCommandResultListener> {
  final Set<String> _notifiedCommandIds = {};

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, CommandSession>>(commandTrackerProvider,
        (previous, next) {
      _checkCompletedCommands(next);
    });

    return widget.child;
  }

  void _checkCompletedCommands(Map<String, CommandSession> sessions) {
    final router = ref.read(routerProvider);
    final location =
        router.routerDelegate.currentConfiguration.uri.toString();
    final isOnControls = location.startsWith('/controls');

    for (final entry in sessions.entries) {
      final session = entry.value;
      if (session.phase != CommandPhase.finished || session.command == null) {
        continue;
      }

      final command = session.command!;
      if (!command.status.isFinal) continue;

      if (_notifiedCommandIds.contains(command.commandId)) continue;
      _notifiedCommandIds.add(command.commandId);

      // Only present snackbar notification when user is outside /controls
      if (isOnControls) continue;

      _showResultSnackBar(command);
    }
  }

  void _showResultSnackBar(Command command) {
    // Resolve human-friendly vehicle name
    String vehicleName = command.vehicleId;
    final vehiclesAsync = ref.read(vehiclesControllerProvider);
    final vehicles = vehiclesAsync.asData?.value;
    if (vehicles != null) {
      for (final v in vehicles) {
        if (v.vehicleId == command.vehicleId) {
          vehicleName = v.name;
          break;
        }
      }
    }

    final String message;
    switch (command.status) {
      case CommandStatus.succeeded:
        message = '${command.commandType.label} succeeded for $vehicleName';
        break;
      case CommandStatus.failed:
        final reason = command.failureReason ??
            'The vehicle did not complete the request.';
        message = '${command.commandType.label} failed: $reason';
        break;
      case CommandStatus.timedOut:
        message = '${command.commandType.label} timed out';
        break;
      default:
        return;
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            context.go('/controls');
          },
        ),
      ),
    );
  }
}
