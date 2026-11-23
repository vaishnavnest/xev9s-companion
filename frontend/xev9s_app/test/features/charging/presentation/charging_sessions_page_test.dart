import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/features/charging/domain/charging_session.dart';
import 'package:xev9s_app/features/charging/presentation/charging_sessions_page.dart';
import 'package:xev9s_app/features/charging/presentation/providers/charging_sessions_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  ChargingSession createSession({
    required String id,
    ChargingState status = ChargingState.completed,
    DateTime? endedAt,
  }) {
    return ChargingSession(
      sessionId: id,
      vehicleId: 'veh_9S0001',
      startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
      endedAt: endedAt,
      durationSeconds: 3600,
      startBatteryPercent: 20.0,
      endBatteryPercent: 80.0,
      status: status,
    );
  }

  Widget buildPage(AsyncValue<ChargingSessionsState> state) {
    return ProviderScope(
      overrides: [
        chargingSessionsProvider.overrideWith(() => _TestSessionsNotifier(state)),
      ],
      child: const MaterialApp(
        home: ChargingSessionsPage(),
      ),
    );
  }

  group('ChargingSessionsPage Widget Tests', () {
    testWidgets('renders filter chips and session items with In progress badge for active', (tester) async {
      final s1 = createSession(id: 's1', status: ChargingState.completed, endedAt: DateTime.now());
      final s2 = createSession(id: 's2', status: ChargingState.charging, endedAt: null);

      final state = AsyncData(ChargingSessionsState(items: [s1, s2]));

      await tester.pumpWidget(buildPage(state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_all')), findsOneWidget);
      expect(find.byKey(const Key('filter_completed')), findsOneWidget);
      expect(find.byKey(const Key('filter_interrupted')), findsOneWidget);
      expect(find.byKey(const Key('filter_charging')), findsOneWidget);

      expect(find.byKey(const Key('session_item_s1')), findsOneWidget);
      expect(find.byKey(const Key('session_item_s2')), findsOneWidget);

      // Active session shows In progress badge
      expect(find.text('In progress'), findsOneWidget);
    });

    testWidgets('renders empty state when no sessions recorded', (tester) async {
      const state = AsyncData(ChargingSessionsState(items: []));

      await tester.pumpWidget(buildPage(state));
      await tester.pumpAndSettle();

      expect(find.text('No charging sessions yet'), findsOneWidget);
    });

    testWidgets('renders filter-aware empty state when filtered', (tester) async {
      const state = AsyncData(
        ChargingSessionsState(
          items: [],
          statusFilter: ChargingState.interrupted,
        ),
      );

      await tester.pumpWidget(buildPage(state));
      await tester.pumpAndSettle();

      expect(find.text('No interrupted sessions'), findsOneWidget);
      expect(find.text('Clear filter'), findsOneWidget);
    });
  });
}

class _TestSessionsNotifier extends ChargingSessionsNotifier {
  _TestSessionsNotifier(this.initialState);
  final AsyncValue<ChargingSessionsState> initialState;

  @override
  Future<ChargingSessionsState> build() async => initialState.value!;
}
