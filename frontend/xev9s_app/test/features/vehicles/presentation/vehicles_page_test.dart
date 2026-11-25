import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_connectivity.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';
import 'package:xev9s_app/features/vehicles/presentation/vehicle_card.dart';
import 'package:xev9s_app/features/vehicles/presentation/vehicles_page.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';
import 'package:xev9s_app/shared/widgets/empty_state.dart';
import 'package:xev9s_app/shared/widgets/error_view.dart';
import 'package:xev9s_app/shared/widgets/loading_view.dart';

class MockVehiclesNotifier extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  MockVehiclesNotifier(this.initialValue);
  final AsyncValue<List<VehicleSummary>> initialValue;

  @override
  void reset() {}

  @override
  Future<List<VehicleSummary>> build() async {
    return initialValue.requireValue;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async =>
      [];
}

class MockVehiclesErrorNotifier extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  @override
  void reset() {}

  @override
  Future<List<VehicleSummary>> build() async {
    throw AppError.noConnection();
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async =>
      [];
}

class MockVehiclesLoadingNotifier extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  @override
  void reset() {}
  @override
  Future<List<VehicleSummary>> build() => Completer<List<VehicleSummary>>().future;

  @override
  Future<void> refresh() async {}

  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const vAssociated = VehicleSummary(
    vehicleId: 'veh_001',
    name: 'My Beast',
    model: 'XEV 9S Performance',
    identifier: 'XEV-001',
    associationStatus: AssociationStatus.associated,
    connectivity: VehicleConnectivity.online,
  );

  const vPending = VehicleSummary(
    vehicleId: 'veh_002',
    name: 'Pending Vehicle',
    model: 'XEV 9S Base',
    identifier: 'XEV-002',
    associationStatus: AssociationStatus.pending,
  );

  group('VehiclesPage Widget Tests', () {
    testWidgets('renders LoadingView while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesControllerProvider.overrideWith(() => MockVehiclesLoadingNotifier()),
          ],
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );

      expect(find.byType(LoadingView), findsOneWidget);
    });

    testWidgets('renders ErrorView with retry when error occurs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesControllerProvider.overrideWith(() => MockVehiclesErrorNotifier()),
          ],
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders EmptyState when vehicles list is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesControllerProvider.overrideWith(
              () => MockVehiclesNotifier(const AsyncData([])),
            ),
          ],
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No vehicles yet'), findsOneWidget);
      expect(find.text('Add Vehicle'), findsWidgets);
    });

    testWidgets('renders populated vehicles list with cards and chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesControllerProvider.overrideWith(
              () => MockVehiclesNotifier(const AsyncData([vAssociated, vPending])),
            ),
          ],
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VehicleCard), findsNWidgets(2));
      expect(find.text('My Beast'), findsOneWidget);
      expect(find.text('Pending Vehicle'), findsOneWidget);
      expect(find.text('Associated'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('tapping pending vehicle shows snackbar notice', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesControllerProvider.overrideWith(
              () => MockVehiclesNotifier(const AsyncData([vAssociated, vPending])),
            ),
          ],
          child: const MaterialApp(home: VehiclesPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pending Vehicle'));
      await tester.pump();

      expect(find.text('This vehicle is still pending association.'), findsOneWidget);
    });

    testWidgets('tapping associated vehicle updates selected vehicle', (tester) async {
      final container = ProviderContainer(
        overrides: [
          vehiclesControllerProvider.overrideWith(
            () => MockVehiclesNotifier(const AsyncData([vAssociated])),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/vehicles',
        routes: [
          GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesPage()),
          GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Beast'));
      await tester.pumpAndSettle();

      expect(container.read(selectedVehicleProvider), equals('veh_001'));
    });
  });
}
