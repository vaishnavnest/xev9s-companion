import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';
import 'package:xev9s_app/features/vehicles/presentation/add_vehicle_page.dart';

class MockAddVehiclesNotifier extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  MockAddVehiclesNotifier({this.onAssociate});

  final Future<List<VehicleSummary>> Function(String id, String code, String? name)?
      onAssociate;

  @override
  void reset() {}

  @override
  Future<List<VehicleSummary>> build() async => [];

  @override
  Future<void> refresh() async {}

  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async {
    if (onAssociate != null) {
      return onAssociate!(identifier, pairingCode, name);
    }
    return [];
  }
}

void main() {
  Widget buildSubject(VehiclesController controller) {
    return ProviderScope(
      overrides: [
        vehiclesControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(
        home: AddVehiclePage(),
      ),
    );
  }

  group('AddVehiclePage Widget Tests', () {
    testWidgets('submit is disabled until identifier and 6-digit code are entered', (tester) async {
      await tester.pumpWidget(buildSubject(MockAddVehiclesNotifier()));

      final submitFinder = find.byKey(const Key('add-vehicle-submit'));
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Enter identifier
      await tester.enterText(find.byKey(const Key('add-vehicle-identifier')), 'XEV9S-2026-0001');
      await tester.pump();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Enter code with letters (invalid)
      await tester.enterText(find.byKey(const Key('add-vehicle-code')), '12345A');
      await tester.pump();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Enter code with only 5 digits (invalid)
      await tester.enterText(find.byKey(const Key('add-vehicle-code')), '12345');
      await tester.pump();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Enter valid 6-digit code
      await tester.enterText(find.byKey(const Key('add-vehicle-code')), '123456');
      await tester.pump();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
    });

    testWidgets('shows VEHICLE_NOT_FOUND banner on failure', (tester) async {
      final controller = MockAddVehiclesNotifier(
        onAssociate: (id, code, name) async {
          throw const AppError(
            code: ApiErrorCode.vehicleNotFound,
            message: 'Vehicle not found',
          );
        },
      );

      await tester.pumpWidget(buildSubject(controller));

      await tester.enterText(find.byKey(const Key('add-vehicle-identifier')), 'UNKNOWN-VIN');
      await tester.enterText(find.byKey(const Key('add-vehicle-code')), '123456');
      await tester.pump();

      await tester.tap(find.byKey(const Key('add-vehicle-submit')));
      await tester.pumpAndSettle();

      expect(find.text("We couldn't find a vehicle with that identifier."), findsOneWidget);
    });
  });
}
