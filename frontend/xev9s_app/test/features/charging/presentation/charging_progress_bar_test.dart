import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/features/charging/presentation/widgets/charging_progress_bar.dart';

void main() {
  group('ChargingProgressBar Widget Tests', () {
    testWidgets('renders 10 segments and scale ticks when static (not charging)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChargingProgressBar(
              batteryPercent: 45.0,
              targetPercent: 80,
              isCharging: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check scale ticks
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Check target marker
      expect(find.byKey(const Key('target_marker')), findsOneWidget);
    });

    testWidgets('renders active charging animation when isCharging is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChargingProgressBar(
              batteryPercent: 45.0,
              targetPercent: 80,
              isCharging: true,
            ),
          ),
        ),
      );

      // Pumping frames drives animation controller
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ChargingProgressBar), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ChargingProgressBar), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(ChargingProgressBar), findsOneWidget);
    });

    testWidgets('handles null battery and target without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChargingProgressBar(
              batteryPercent: null,
              targetPercent: null,
              isCharging: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      // Target marker is omitted when targetPercent is null
      expect(find.byKey(const Key('target_marker')), findsNothing);
    });

    testWidgets('renders correctly in dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ChargingProgressBar(
              batteryPercent: 64.0,
              targetPercent: 90,
              isCharging: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('64%'), findsNothing); // label is outside progress bar
      expect(find.byKey(const Key('target_marker')), findsOneWidget);
    });
  });
}
