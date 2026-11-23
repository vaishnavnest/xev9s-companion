import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/charging/domain/charging_session.dart';
import 'package:xev9s_app/features/charging/presentation/charging_session_detail_page.dart';
import 'package:xev9s_app/features/charging/presentation/providers/charging_session_detail_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  Widget buildPage(String sessionId, ChargingSession session) {
    return ProviderScope(
      overrides: [
        chargingSessionDetailProvider(sessionId)
            .overrideWith((ref) => Future<ChargingSession>.value(session)),
      ],
      child: MaterialApp(
        home: ChargingSessionDetailPage(sessionId: sessionId),
      ),
    );
  }

  group('ChargingSessionDetailPage Widget Tests', () {
    testWidgets('renders completed session attributes and format nulls with "-"', (tester) async {
      final session = ChargingSession(
        sessionId: 'chs_42',
        vehicleId: 'veh_9S0001',
        startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
        endedAt: DateTime.parse('2026-11-20T11:30:00Z'),
        durationSeconds: 5400,
        startBatteryPercent: 20.0,
        endBatteryPercent: 80.0,
        targetPercent: 80,
        avgPowerKw: 11.0,
        maxPowerKw: null, // should display "-"
        status: ChargingState.completed,
      );

      await tester.pumpWidget(buildPage('chs_42', session));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Charging complete'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('80%'), findsAtLeastNWidgets(1));
      expect(find.text('11.0 kW'), findsOneWidget);
      expect(find.text('-'), findsOneWidget); // Max power null -> '-'
    });

    testWidgets('renders in-progress banner for active sessions', (tester) async {
      final session = ChargingSession(
        sessionId: 'chs_active',
        vehicleId: 'veh_9S0001',
        startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
        endedAt: null,
        status: ChargingState.charging,
      );

      await tester.pumpWidget(buildPage('chs_active', session));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('in_progress_banner')), findsOneWidget);
    });

    testWidgets('renders interrupted session reason prominently with icon and text', (tester) async {
      final session = ChargingSession(
        sessionId: 'chs_interrupted',
        vehicleId: 'veh_9S0001',
        startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
        endedAt: DateTime.parse('2026-11-20T10:15:00Z'),
        status: ChargingState.interrupted,
        interruptionReason: 'Connector unlatched during charge',
      );

      await tester.pumpWidget(buildPage('chs_interrupted', session));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('interrupted_banner')), findsOneWidget);
      expect(find.text('Charging Interrupted'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('interrupted_banner')),
          matching: find.text('Connector unlatched during charge'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders 404 session not found empty state', (tester) async {
      final widget = ProviderScope(
        overrides: [
          chargingSessionDetailProvider('missing_id').overrideWith(
            (ref) => Future<ChargingSession>.error(
              const AppError(
                code: ApiErrorCode.notFound,
                message: 'Session missing',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChargingSessionDetailPage(sessionId: 'missing_id'),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('session_not_found')), findsOneWidget);
      expect(find.text('Session not found'), findsOneWidget);
      expect(find.text('Back to sessions'), findsOneWidget);
    });
  });
}
