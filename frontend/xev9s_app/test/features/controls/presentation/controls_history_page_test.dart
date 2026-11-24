import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/controls/presentation/controls_history_page.dart';
import 'package:xev9s_app/features/controls/presentation/providers/command_history_provider.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class _TestHistoryNotifier extends CommandHistoryNotifier {
  _TestHistoryNotifier(this._initialState);
  final CommandHistoryState _initialState;

  @override
  FutureOr<CommandHistoryState> build() => _initialState;
}

class FakeSelectedVehicleNotifier extends SelectedVehicleNotifier {
  FakeSelectedVehicleNotifier([this._id = 'veh_9S0001']);
  final String? _id;

  @override
  String? build() => _id;
}

void main() {
  const vehicleId = 'veh_9S0001';
  final t0 = DateTime.parse('2026-11-24T12:00:00Z');

  Widget buildHistoryApp({required CommandHistoryState state}) {
    return ProviderScope(
      overrides: [
        selectedVehicleProvider.overrideWith(() => FakeSelectedVehicleNotifier(vehicleId)),
        commandHistoryProvider.overrideWith(() => _TestHistoryNotifier(state)),
      ],
      child: const MaterialApp(
        home: ControlsHistoryPage(),
      ),
    );
  }

  group('ControlsHistoryPage Widget Tests', () {
    testWidgets('renders EmptyState when no commands are present',
        (tester) async {
      const state = CommandHistoryState(items: [], hasMore: false);

      await tester.pumpWidget(buildHistoryApp(state: state));
      await tester.pumpAndSettle();

      expect(find.text('No commands yet'), findsOneWidget);
    });

    testWidgets('renders filter-aware EmptyState when filters are active',
        (tester) async {
      const state = CommandHistoryState(
        items: [],
        hasMore: false,
        statusFilter: CommandStatus.failed,
      );

      await tester.pumpWidget(buildHistoryApp(state: state));
      await tester.pumpAndSettle();

      expect(find.text('No matching commands'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets(
        'renders populated items with operation label, requested time, StatusChip, and failure reason',
        (tester) async {
      final items = [
        Command(
          commandId: 'cmd_1',
          vehicleId: vehicleId,
          commandType: CommandType.unlock,
          status: CommandStatus.succeeded,
          requestedAt: t0,
          completedAt: t0.add(const Duration(seconds: 4)),
        ),
        Command(
          commandId: 'cmd_2',
          vehicleId: vehicleId,
          commandType: CommandType.lock,
          status: CommandStatus.failed,
          requestedAt: t0.subtract(const Duration(minutes: 10)),
          failureReason: 'VEHICLE_DRIVING',
        ),
        Command(
          commandId: 'cmd_3',
          vehicleId: vehicleId,
          commandType: CommandType.startPreconditioning,
          status: CommandStatus.executing,
          requestedAt: t0.subtract(const Duration(minutes: 1)),
        ),
      ];

      final state = CommandHistoryState(items: items, hasMore: false);

      await tester.pumpWidget(buildHistoryApp(state: state));
      await tester.pumpAndSettle();

      // Operation labels
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Lock'), findsOneWidget);
      expect(find.text('Start climate'), findsOneWidget);

      // Status labels & chips (note: filter chip and row chip may both display Succeeded)
      expect(find.text('Succeeded'), findsAtLeastNWidgets(1));
      expect(find.text('Failed'), findsAtLeastNWidgets(1));
      expect(find.text('In progress'), findsAtLeastNWidgets(1));

      // Failure reason banner
      expect(find.text('VEHICLE_DRIVING'), findsOneWidget);
    });

    testWidgets(
        'renders load more error with retry button when loadMoreError occurs',
        (tester) async {
      final items = [
        Command(
          commandId: 'cmd_1',
          vehicleId: vehicleId,
          commandType: CommandType.lock,
          status: CommandStatus.succeeded,
          requestedAt: t0,
        ),
      ];

      final state = CommandHistoryState(
        items: items,
        hasMore: true,
        loadMoreError: Exception('Connection lost'),
      );

      await tester.pumpWidget(buildHistoryApp(state: state));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load more commands'), findsOneWidget);
      expect(find.byKey(const Key('retry-load-more')), findsOneWidget);
    });
  });
}
