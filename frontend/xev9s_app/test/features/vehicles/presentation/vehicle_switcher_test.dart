import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';
import 'package:xev9s_app/features/vehicles/presentation/vehicle_switcher_sheet.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockSwitcherNotifier extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  @override
  void reset() {}
  MockSwitcherNotifier(this.vehicles);
  final List<VehicleSummary> vehicles;

  @override
  Future<List<VehicleSummary>> build() async => vehicles;

  @override
  Future<void> refresh() async {}

  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async =>
      vehicles;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const v1 = VehicleSummary(
    vehicleId: 'veh_001',
    name: 'Stealth Black',
    model: 'XEV 9S AWD',
    identifier: 'VIN-001',
    associationStatus: AssociationStatus.associated,
  );

  const v2 = VehicleSummary(
    vehicleId: 'veh_002',
    name: 'Glacier White',
    model: 'XEV 9S RWD',
    identifier: 'VIN-002',
    associationStatus: AssociationStatus.associated,
  );

  group('VehicleSwitcher Widget Tests', () {
    testWidgets('lists vehicles and selecting updates selectedVehicleProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          vehiclesControllerProvider.overrideWith(() => MockSwitcherNotifier([v1, v2])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(selectedVehicleProvider.notifier).select('veh_001');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showVehicleSwitcher(context),
                  child: const Text('Open Switcher'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Switcher'));
      await tester.pumpAndSettle();

      expect(find.text('Switch Vehicle'), findsOneWidget);
      expect(find.text('Stealth Black'), findsOneWidget);
      expect(find.text('Glacier White'), findsOneWidget);

      // Tap second vehicle
      await tester.tap(find.text('Glacier White'));
      await tester.pumpAndSettle();

      expect(container.read(selectedVehicleProvider), equals('veh_002'));
      expect(container.read(currentVehicleProvider)?.displayName, equals('Glacier White'));
    });
  });
}
