import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/features/controls/application/command_session.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/controls/presentation/widgets/active_command_card.dart';

void main() {
  const vehicleId = 'veh_9S0001';
  final now = DateTime.parse('2026-11-24T12:00:00Z');

  Widget buildCard({
    required CommandSession session,
    VoidCallback? onRetry,
    VoidCallback? onConfirmRetry,
    VoidCallback? onDismiss,
    VoidCallback? onManualPoll,
    VoidCallback? onRetryStatusRefresh,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ActiveCommandCard(
          session: session,
          vehicleId: vehicleId,
          onRetry: onRetry ?? () {},
          onConfirmRetry: onConfirmRetry ?? () {},
          onDismiss: onDismiss ?? () {},
          onManualPoll: onManualPoll ?? () {},
          onRetryStatusRefresh: onRetryStatusRefresh ?? () {},
        ),
      ),
    );
  }

  group('ActiveCommandCard Widget Tests', () {
    testWidgets('renders nothing when phase is idle', (tester) async {
      await tester.pumpWidget(buildCard(session: const CommandSession()));
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('renders submitting state with progress indicator and operation name', (tester) async {
      final session = CommandSession(
        phase: CommandPhase.submitting,
        lastAttemptedType: CommandType.unlock,
        startedAt: now,
      );

      await tester.pumpWidget(buildCard(session: session));
      expect(find.text('Sending request...'), findsOneWidget);
      expect(find.text('Submitting Unlock to vehicle'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders tracking state with progress bar and formatted elapsed time', (tester) async {
      final cmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.executing,
        requestedAt: now.subtract(const Duration(seconds: 15)),
      );

      final session = CommandSession(
        phase: CommandPhase.tracking,
        command: cmd,
        startedAt: now.subtract(const Duration(seconds: 15)),
      );

      await tester.pumpWidget(buildCard(session: session));
      expect(find.text('Lock'), findsOneWidget);
      expect(find.text('Executing'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
    });

    testWidgets('renders waiting too long banner with manual refresh button', (tester) async {
      var manualPollCalled = false;
      final cmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.accepted,
        requestedAt: now.subtract(const Duration(seconds: 65)),
      );

      final session = CommandSession(
        phase: CommandPhase.tracking,
        command: cmd,
        waitingTooLong: true,
        startedAt: now.subtract(const Duration(seconds: 65)),
      );

      await tester.pumpWidget(buildCard(
        session: session,
        onManualPoll: () => manualPollCalled = true,
      ));

      expect(find.text('This is taking longer than expected. We will keep checking.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('command-refresh-status')));
      expect(manualPollCalled, isTrue);
    });

    testWidgets('renders submitUnconfirmed with try again button', (tester) async {
      var confirmRetryCalled = false;
      final session = CommandSession(
        phase: CommandPhase.submitUnconfirmed,
        idempotencyKey: 'key-123',
        lastAttemptedType: CommandType.startPreconditioning,
      );

      await tester.pumpWidget(buildCard(
        session: session,
        onConfirmRetry: () => confirmRetryCalled = true,
      ));

      expect(find.text("We couldn't confirm that the request was sent."), findsOneWidget);
      expect(find.byKey(const Key('command-retry-unconfirmed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('command-retry-unconfirmed')));
      expect(confirmRetryCalled, isTrue);
    });

    testWidgets('renders succeeded finished state with dismiss button', (tester) async {
      var dismissCalled = false;
      final cmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.succeeded,
        requestedAt: now,
        completedAt: now.add(const Duration(seconds: 5)),
      );

      final session = CommandSession(
        phase: CommandPhase.finished,
        command: cmd,
      );

      await tester.pumpWidget(buildCard(
        session: session,
        onDismiss: () => dismissCalled = true,
      ));

      expect(find.text('Vehicle unlocked'), findsOneWidget);
      expect(find.byKey(const Key('command-dismiss')), findsOneWidget);
      await tester.tap(find.byKey(const Key('command-dismiss')));
      expect(dismissCalled, isTrue);
    });

    testWidgets('renders refresh failed state with retry refresh button', (tester) async {
      var retryRefreshCalled = false;
      final cmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.succeeded,
        requestedAt: now,
      );

      final session = CommandSession(
        phase: CommandPhase.finished,
        command: cmd,
        refreshFailed: true,
      );

      await tester.pumpWidget(buildCard(
        session: session,
        onRetryStatusRefresh: () => retryRefreshCalled = true,
      ));

      expect(find.text("Command succeeded, but we couldn't refresh the vehicle state."), findsOneWidget);
      await tester.tap(find.byKey(const Key('command-retry-refresh')));
      expect(retryRefreshCalled, isTrue);
    });

    testWidgets('renders failed finished state with reason and retry button', (tester) async {
      var retryCalled = false;
      final cmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.failed,
        failureReason: 'VEHICLE_MOVING',
        requestedAt: now,
      );

      final session = CommandSession(
        phase: CommandPhase.finished,
        command: cmd,
      );

      await tester.pumpWidget(buildCard(
        session: session,
        onRetry: () => retryCalled = true,
      ));

      expect(find.text('Command failed'), findsOneWidget);
      expect(find.text('VEHICLE_MOVING'), findsOneWidget);
      expect(find.byKey(const Key('command-retry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('command-retry')));
      expect(retryCalled, isTrue);
    });
  });
}
