import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';

class FakeVehicleApiClient extends ApiClient {
  FakeVehicleApiClient({this.getHandler, this.postHandler})
      : super(baseUrl: 'http://test.local');

  final Future<dynamic> Function(String path, dynamic query)? getHandler;
  final Future<dynamic> Function(String path, dynamic body)? postHandler;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) parse,
  }) async {
    if (getHandler != null) {
      final res = await getHandler!(path, query);
      return parse(res);
    }
    return parse([]);
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    required T Function(Object? json) parse,
  }) async {
    if (postHandler != null) {
      final res = await postHandler!(path, body);
      return parse(res);
    }
    return parse([]);
  }
}

void main() {
  group('VehicleRepository', () {
    test('listVehicles calls GET /vehicles and parses list', () async {
      final client = FakeVehicleApiClient(
        getHandler: (path, _) async {
          expect(path, equals('/vehicles'));
          return [
            {
              'vehicleId': 'veh_9S0001',
              'name': 'My Beast',
              'model': 'XEV 9S Performance',
              'identifier': 'XEV9S-2026-0001',
              'associationStatus': 'ASSOCIATED',
              'connectivity': 'ONLINE',
            },
          ];
        },
      );

      final repo = ApiVehicleRepository(apiClient: client);
      final vehicles = await repo.listVehicles();

      expect(vehicles.length, equals(1));
      expect(vehicles.first.vehicleId, equals('veh_9S0001'));
      expect(vehicles.first.associationStatus, equals(AssociationStatus.associated));
    });

    test('associateVehicle trims inputs and returns updated list', () async {
      final client = FakeVehicleApiClient(
        postHandler: (path, body) async {
          expect(path, equals('/vehicles'));
          expect(body['vehicleIdentifier'], equals('XEV9S-2026-0002'));
          expect(body['pairingCode'], equals('123456'));
          expect(body['name'], equals('Second Car'));

          return [
            {
              'vehicleId': 'veh_9S0001',
              'name': 'Car 1',
              'model': 'Model 1',
              'identifier': 'ID1',
              'associationStatus': 'ASSOCIATED',
            },
            {
              'vehicleId': 'veh_9S0002',
              'name': 'Second Car',
              'model': 'Model 2',
              'identifier': 'XEV9S-2026-0002',
              'associationStatus': 'ASSOCIATED',
            },
          ];
        },
      );

      final repo = ApiVehicleRepository(apiClient: client);
      final vehicles = await repo.associateVehicle(
        identifier: '  XEV9S-2026-0002  ',
        pairingCode: '  123456  ',
        name: '  Second Car  ',
      );

      expect(vehicles.length, equals(2));
      expect(vehicles.last.vehicleId, equals('veh_9S0002'));
      expect(vehicles.last.name, equals('Second Car'));
    });
  });
}
