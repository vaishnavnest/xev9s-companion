import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_connectivity.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class FakeVehicleRepository implements VehicleRepository {
  List<VehicleSummary> vehiclesResult = [];
  Exception? listError;
  Exception? associateError;

  @override
  Future<List<VehicleSummary>> listVehicles() async {
    if (listError != null) throw listError!;
    return vehiclesResult;
  }

  @override
  Future<List<VehicleSummary>> associateVehicle({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async {
    if (associateError != null) throw associateError!;
    return vehiclesResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const v1 = VehicleSummary(
    vehicleId: 'veh_001',
    name: 'Primary Car',
    model: 'XEV 9S Performance',
    identifier: 'VIN-001',
    associationStatus: AssociationStatus.associated,
    connectivity: VehicleConnectivity.online,
  );

  const v2 = VehicleSummary(
    vehicleId: 'veh_002',
    name: 'Secondary Car',
    model: 'XEV 9S Base',
    identifier: 'VIN-002',
    associationStatus: AssociationStatus.associated,
  );

  const vPending = VehicleSummary(
    vehicleId: 'veh_pending',
    name: 'Pending Car',
    model: 'XEV 9S Alpha',
    identifier: 'VIN-P',
    associationStatus: AssociationStatus.pending,
  );

  group('VehiclesController', () {
    test('auto-selects single ASSOCIATED vehicle when nothing is selected', () async {
      final repo = FakeVehicleRepository()..vehiclesResult = [v1, vPending];

      final container = ProviderContainer(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedVehicleProvider), isNull);

      await container.read(vehiclesControllerProvider.future);

      expect(container.read(selectedVehicleProvider), equals('veh_001'));
      expect(container.read(currentVehicleProvider), equals(v1));
    });

    test('does NOT auto-select when multiple ASSOCIATED vehicles exist', () async {
      final repo = FakeVehicleRepository()..vehiclesResult = [v1, v2];

      final container = ProviderContainer(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(vehiclesControllerProvider.future);

      expect(container.read(selectedVehicleProvider), isNull);
      expect(container.read(currentVehicleProvider), isNull);
    });

    test('clears stale selection if vehicle is no longer in list', () async {
      final repo = FakeVehicleRepository()..vehiclesResult = [v2];

      final container = ProviderContainer(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(selectedVehicleProvider.notifier).select('veh_deleted');
      expect(container.read(selectedVehicleProvider), equals('veh_deleted'));

      await container.read(vehiclesControllerProvider.future);

      expect(container.read(selectedVehicleProvider), isNull);
    });

    test('associate updates list and surfaces error on failure', () async {
      final repo = FakeVehicleRepository()..vehiclesResult = [v1];

      final container = ProviderContainer(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(vehiclesControllerProvider.future);
      expect(container.read(vehiclesControllerProvider).value, equals([v1]));

      // Update repository for associate return
      repo.vehiclesResult = [v1, v2];
      final updated = await container.read(vehiclesControllerProvider.notifier).associate(
            identifier: 'VIN-002',
            pairingCode: '123456',
            name: 'Secondary Car',
          );

      expect(updated.length, equals(2));
      expect(container.read(vehiclesControllerProvider).value?.length, equals(2));

      // Error case
      repo.associateError = const AppError(
        code: ApiErrorCode.vehicleNotFound,
        message: 'Vehicle not found',
      );

      await expectLater(
        container.read(vehiclesControllerProvider.notifier).associate(
              identifier: 'UNKNOWN',
              pairingCode: '123456',
            ),
        throwsA(isA<AppError>()),
      );
    });

    test('refresh preserves existing data while loading', () async {
      final repo = FakeVehicleRepository()..vehiclesResult = [v1];

      final container = ProviderContainer(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(vehiclesControllerProvider.future);
      expect(container.read(vehiclesControllerProvider).value, equals([v1]));

      final refreshFuture = container.read(vehiclesControllerProvider.notifier).refresh();

      // In-flight refresh retains previous value
      final inFlightState = container.read(vehiclesControllerProvider);
      expect(inFlightState.isLoading, isTrue);
      expect(inFlightState.value, equals([v1]));

      await refreshFuture;
      expect(container.read(vehiclesControllerProvider).value, equals([v1]));
    });
  });
}
