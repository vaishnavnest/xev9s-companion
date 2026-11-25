import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_status_repository.dart';

class FakeStatusApiClient extends ApiClient {
  FakeStatusApiClient({this.getHandler}) : super(baseUrl: 'http://test.local');

  final Future<dynamic> Function(String path, dynamic query)? getHandler;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    required T Function(Object? json) parse,
  }) async {
    if (getHandler != null) {
      final res = await getHandler!(path, query);
      return parse(res);
    }
    return parse({});
  }
}

void main() {
  group('VehicleStatusRepository Tests', () {
    test('getStatus calls GET /vehicles/{id}/telemetry/latest and parses VehicleStatus', () async {
      final client = FakeStatusApiClient(
        getHandler: (path, _) async {
          expect(path, equals('/vehicles/veh_9S0001/telemetry/latest'));
          return {
            'vehicleId': 'veh_9S0001',
            'name': 'My EV',
            'model': 'XEV 9S Performance',
            'vehicleState': 'PARKED',
            'connectivity': 'ONLINE',
            'battery': {'percent': 80.0, 'level': 'NORMAL'},
            'lastUpdatedAt': '2026-11-18T05:00:00Z',
          };
        },
      );

      final repo = ApiVehicleStatusRepository(apiClient: client);
      final status = await repo.getStatus('veh_9S0001');

      expect(status.vehicleId, 'veh_9S0001');
      expect(status.name, 'My EV');
      expect(status.battery?.percent, 80.0);
    });

    test('getStatus propagates AppError on failure', () async {
      final client = FakeStatusApiClient(
        getHandler: (path, _) async {
          throw const AppError(
            code: ApiErrorCode.vehicleNotFound,
            message: 'Vehicle not found',
            httpStatus: 404,
          );
        },
      );

      final repo = ApiVehicleStatusRepository(apiClient: client);

      expect(
        () => repo.getStatus('veh_unknown'),
        throwsA(
          isA<AppError>().having((e) => e.code, 'code', ApiErrorCode.vehicleNotFound),
        ),
      );
    });
  });
}
