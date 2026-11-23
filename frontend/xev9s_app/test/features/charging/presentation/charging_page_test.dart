import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/features/charging/domain/charging_schedule.dart';
import 'package:xev9s_app/features/charging/domain/day_of_week.dart';
import 'package:xev9s_app/features/charging/presentation/charging_page.dart';
import 'package:xev9s_app/features/charging/presentation/providers/charging_view_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  Widget buildTestableWidget(WidgetRefCallback? onInit, {AsyncValue<ChargingViewState?>? viewStateOverride}) {
    return ProviderScope(
      overrides: [
        if (viewStateOverride != null)
          chargingViewProvider.overrideWithValue(viewStateOverride),
      ],
      child: const MaterialApp(
        home: ChargingPage(),
      ),
    );
  }

  group('ChargingPage Widget Tests', () {
    testWidgets('renders populated charging state, separate target, power, and duration', (tester) async {
      final state = ChargingViewState(
        state: ChargingState.charging,
        batteryPercent: 64.0,
        targetPercent: 80,
        powerKw: 11.2,
        sessionDurationSeconds: 1260,
        schedule: const ChargingSchedule(
          enabled: true,
          startTime: ScheduleTime(hour: 22, minute: 0),
          endTime: ScheduleTime(hour: 6, minute: 0),
          daysOfWeek: {DayOfWeek.mon, DayOfWeek.tue, DayOfWeek.wed, DayOfWeek.thu, DayOfWeek.fri},
        ),
        currentSessionId: 'chs_0042',
      );

      await tester.pumpWidget(
        buildTestableWidget(null, viewStateOverride: AsyncData(state)),
      );
      await tester.pumpAndSettle();

      // Status chip and text
      expect(find.byKey(const Key('charging_status_chip')), findsOneWidget);
      expect(find.text('Charging'), findsAtLeastNWidgets(1));

      // Separate battery and target indicators
      expect(find.byKey(const Key('battery_percent_text')), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);

      expect(find.byKey(const Key('target_percent_text')), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      // Target marker on progress bar
      expect(find.byKey(const Key('target_marker')), findsOneWidget);

      // Telemetry
      expect(find.byKey(const Key('charging_power_text')), findsOneWidget);
      expect(find.text('11.2 kW'), findsOneWidget);

      expect(find.byKey(const Key('charging_duration_text')), findsOneWidget);
      expect(find.text('21m'), findsOneWidget);

      // Schedule summary
      expect(find.byKey(const Key('schedule_summary_text')), findsOneWidget);
      expect(find.text('22:00 - 06:00, Mon-Fri'), findsOneWidget);

      // Current session link
      expect(find.byKey(const Key('current_session_link')), findsOneWidget);
    });

    testWidgets('shows StaleBanner and dims values when offline', (tester) async {
      final state = ChargingViewState(
        state: ChargingState.notConnected,
        batteryPercent: 55.0,
        targetPercent: 80,
        isOffline: true,
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        buildTestableWidget(null, viewStateOverride: AsyncData(state)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Vehicle is offline'), findsOneWidget);
    });

    testWidgets('shows "No schedule set" when schedule is null', (tester) async {
      const state = ChargingViewState(
        state: ChargingState.notConnected,
        batteryPercent: 80.0,
        schedule: null,
      );

      await tester.pumpWidget(
        buildTestableWidget(null, viewStateOverride: const AsyncData(state)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No schedule set'), findsOneWidget);
      expect(find.text('Set schedule'), findsOneWidget);
    });

    testWidgets('duration ticks locally every second when CHARGING', (tester) async {
      final state = ChargingViewState(
        state: ChargingState.charging,
        batteryPercent: 60.0,
        sessionDurationSeconds: 59,
      );

      await tester.pumpWidget(
        buildTestableWidget(null, viewStateOverride: AsyncData(state)),
      );
      await tester.pump();

      expect(find.text('0m'), findsOneWidget);

      // Advance 2 seconds -> becomes 61s = 1m
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('1m'), findsOneWidget);
    });
  });
}

typedef WidgetRefCallback = void Function(WidgetRef ref);
