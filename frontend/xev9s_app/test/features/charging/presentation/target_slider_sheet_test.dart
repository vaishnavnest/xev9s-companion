import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/charging/data/charging_repository.dart';
import 'package:xev9s_app/features/charging/domain/charging_overview.dart';
import 'package:xev9s_app/features/charging/presentation/widgets/target_slider_sheet.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockChargingRepository extends Mock implements ChargingRepository {}

void main() {
  late MockChargingRepository mockRepo;

  setUp(() {
    mockRepo = MockChargingRepository();
  });

  Widget buildSheet({
    required int? initialTarget,
    double? currentBattery,
    bool isOffline = false,
  }) {
    when(() => mockRepo.getOverview('veh_9S0001')).thenAnswer(
      (_) async => ChargingOverview(
        state: ChargingState.connected,
        targetPercent: initialTarget,
        batteryPercent: currentBattery,
      ),
    );

    return ProviderScope(
      overrides: [
        chargingRepositoryProvider.overrideWithValue(mockRepo),
        selectedVehicleProvider.overrideWith(() => _TestSelectedVehicle('veh_9S0001')),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TargetSliderSheet(
            initialTarget: initialTarget,
            currentBatteryPercent: currentBattery,
            isVehicleOffline: isOffline,
          ),
        ),
      ),
    );
  }

  group('TargetSliderSheet Widget Tests', () {
    testWidgets('Save button is disabled until target changes and is valid', (tester) async {
      await tester.pumpWidget(buildSheet(initialTarget: 80));
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('target_save_button')),
      );
      expect(saveButton.onPressed, isNull);

      // Change text field to 85
      await tester.enterText(find.byKey(const Key('target_input_field')), '85');
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<FilledButton>(
        find.byKey(const Key('target_save_button')),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('slider and input field stay in sync', (tester) async {
      await tester.pumpWidget(buildSheet(initialTarget: 80));
      await tester.pumpAndSettle();

      // Enter 90 in field
      await tester.enterText(find.byKey(const Key('target_input_field')), '90');
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byKey(const Key('target_slider')));
      expect(slider.value, 90.0);
    });

    testWidgets('warns when target is below current battery percentage', (tester) async {
      await tester.pumpWidget(buildSheet(initialTarget: 80, currentBattery: 85.0));
      await tester.pumpAndSettle();

      expect(find.text('Battery is already above this target'), findsOneWidget);
    });

    testWidgets('displays 422 server message inside sheet on error and keeps input', (tester) async {
      when(() => mockRepo.setTarget('veh_9S0001', 90)).thenThrow(
        const AppError(
          code: ApiErrorCode.chargingTargetNotApplicable,
          message: 'Target cannot be applied at this time',
        ),
      );

      await tester.pumpWidget(buildSheet(initialTarget: 80));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('target_input_field')), '90');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('target_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Target cannot be applied at this time'), findsOneWidget);
      // Input is kept
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('successful save invokes repository once', (tester) async {
      when(() => mockRepo.setTarget('veh_9S0001', 85)).thenAnswer(
        (_) async => const ChargingOverview(
          state: ChargingState.connected,
          targetPercent: 85,
        ),
      );

      await tester.pumpWidget(buildSheet(initialTarget: 80));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('target_input_field')), '85');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('target_save_button')));
      await tester.pumpAndSettle();

      verify(() => mockRepo.setTarget('veh_9S0001', 85)).called(1);
    });
  });
}

class _TestSelectedVehicle extends SelectedVehicleNotifier {
  _TestSelectedVehicle(this.id);
  final String id;
  @override
  String? build() => id;
}
