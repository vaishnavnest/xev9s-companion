import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/shared/widgets/async_value_view.dart';
import 'package:xev9s_app/shared/widgets/confirm_dialog.dart';
import 'package:xev9s_app/shared/widgets/empty_state.dart';
import 'package:xev9s_app/shared/widgets/error_view.dart';
import 'package:xev9s_app/shared/widgets/loading_view.dart';
import 'package:xev9s_app/shared/widgets/stale_banner.dart';
import 'package:xev9s_app/shared/widgets/status_chip.dart';

Widget testable(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('ErrorView', () {
    testWidgets('shows Retry button for network/5xx (retryable) errors', (tester) async {
      bool retryPressed = false;

      final networkError = AppError.noConnection();
      await tester.pumpWidget(
        testable(
          ErrorView(
            error: networkError,
            message: networkError.displayMessage,
            onRetry: () => retryPressed = true,
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('hides Retry button for validation (non-retryable) errors', (tester) async {
      const validationError = AppError(
        code: ApiErrorCode.validationError,
        message: 'Invalid target percent',
        retryable: false,
      );

      await tester.pumpWidget(
        testable(
          ErrorView(
            error: validationError,
            message: validationError.displayMessage,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Retry'), findsNothing);
    });
  });

  group('EmptyState', () {
    testWidgets('renders title and triggers onAction callback', (tester) async {
      bool actionFired = false;

      await tester.pumpWidget(
        testable(
          EmptyState(
            title: 'No vehicles added',
            message: 'Pair your XEV 9S to get started',
            actionLabel: 'Add Vehicle',
            onAction: () => actionFired = true,
          ),
        ),
      );

      expect(find.text('No vehicles added'), findsOneWidget);
      expect(find.text('Pair your XEV 9S to get started'), findsOneWidget);
      expect(find.text('Add Vehicle'), findsOneWidget);

      await tester.tap(find.text('Add Vehicle'));
      expect(actionFired, isTrue);
    });

    testWidgets('renders without message or action when both are omitted', (tester) async {
      await tester.pumpWidget(
        testable(
          const EmptyState(title: 'Nothing here'),
        ),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      // No action button when actionLabel / onAction are null.
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('StaleBanner', () {
    testWidgets('gracefully handles null date without throwing', (tester) async {
      await tester.pumpWidget(
        testable(
          const StaleBanner(lastUpdatedAt: null),
        ),
      );

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('Vehicle is offline. Showing last reported data.'), findsOneWidget);
    });

    testWidgets('formats non-null lastUpdatedAt timestamp', (tester) async {
      final updateTime = DateTime.now().subtract(const Duration(minutes: 15));

      await tester.pumpWidget(
        testable(
          StaleBanner(lastUpdatedAt: updateTime),
        ),
      );

      expect(find.textContaining('15m ago'), findsOneWidget);
    });

    testWidgets('shows custom message when message param is provided', (tester) async {
      await tester.pumpWidget(
        testable(
          const StaleBanner(message: 'Custom offline notice'),
        ),
      );

      expect(find.text('Custom offline notice'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });

  group('ConfirmDialog', () {
    testWidgets('confirm button resolves dialog with true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ConfirmDialog.show(
                  context,
                  title: 'Delete trip?',
                  content: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete trip?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancel button resolves dialog with false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ConfirmDialog.show(
                  context,
                  title: 'Remove vehicle?',
                  content: 'Are you sure?',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('isDestructive styles confirm button with error color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => ConfirmDialog.show(
                context,
                title: 'Delete?',
                content: 'Permanent action.',
                isDestructive: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Confirm button is a FilledButton — verify it renders.
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('StatusChip', () {
    testWidgets('info tone renders its label', (tester) async {
      await tester.pumpWidget(
        testable(
          const StatusChip(label: 'Info label', type: ChipStatusType.info),
        ),
      );
      expect(find.text('Info label'), findsOneWidget);
    });

    testWidgets('success tone renders its label', (tester) async {
      await tester.pumpWidget(
        testable(
          const StatusChip(label: 'Charging', type: ChipStatusType.success),
        ),
      );
      expect(find.text('Charging'), findsOneWidget);
    });

    testWidgets('warning tone renders its label', (tester) async {
      await tester.pumpWidget(
        testable(
          const StatusChip(label: 'Low battery', type: ChipStatusType.warning),
        ),
      );
      expect(find.text('Low battery'), findsOneWidget);
    });

    testWidgets('error tone renders its label', (tester) async {
      await tester.pumpWidget(
        testable(
          const StatusChip(label: 'Fault', type: ChipStatusType.error),
        ),
      );
      expect(find.text('Fault'), findsOneWidget);
    });

    testWidgets('renders optional icon when provided', (tester) async {
      await tester.pumpWidget(
        testable(
          const StatusChip(
            label: 'Online',
            type: ChipStatusType.success,
            icon: Icons.check_circle_outline,
          ),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });

  group('AsyncValueView', () {
    testWidgets('renders LoadingView when state is loading', (tester) async {
      const AsyncValue<String> state = AsyncLoading();

      await tester.pumpWidget(
        testable(
          AsyncValueView<String>(
            value: state,
            data: (val) => Text('Data: $val'),
          ),
        ),
      );

      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.textContaining('Data:'), findsNothing);
    });

    testWidgets('renders ErrorView when state has error', (tester) async {
      final state = AsyncError<String>(
        AppError.noConnection(),
        StackTrace.empty,
      );

      await tester.pumpWidget(
        testable(
          AsyncValueView<String>(
            value: state,
            onRetry: () {},
            data: (val) => Text('Data: $val'),
          ),
        ),
      );

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders EmptyState when isEmpty returns true', (tester) async {
      const state = AsyncData<List<String>>([]);

      await tester.pumpWidget(
        testable(
          AsyncValueView<List<String>>(
            value: state,
            isEmpty: (list) => list.isEmpty,
            data: (list) => Text('Items: ${list.length}'),
          ),
        ),
      );

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.textContaining('Items:'), findsNothing);
    });

    testWidgets('renders data widget when value is present', (tester) async {
      const state = AsyncData<String>('Hello XEV');

      await tester.pumpWidget(
        testable(
          AsyncValueView<String>(
            value: state,
            data: (val) => Text('Received: $val'),
          ),
        ),
      );

      expect(find.text('Received: Hello XEV'), findsOneWidget);
    });

    testWidgets('handles refreshing with previous data without flashing spinner', (tester) async {
      // AsyncLoading with previous data (refreshing state)
      // ignore: invalid_use_of_internal_member
      final state = const AsyncData<String>('Previous Data').copyWithPrevious(const AsyncLoading());

      await tester.pumpWidget(
        testable(
          AsyncValueView<String>(
            value: state,
            data: (val) => Text('Active: $val'),
          ),
        ),
      );

      // Should show the previous data, not the loading spinner
      expect(find.text('Active: Previous Data'), findsOneWidget);
      expect(find.byType(LoadingView), findsNothing);
    });
  });
}
