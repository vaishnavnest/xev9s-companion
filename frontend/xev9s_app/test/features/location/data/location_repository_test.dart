import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/features/location/data/location_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

class FakeLocationApiClient extends ApiClient {
  FakeLocationApiClient({this.getHandler}) : super(baseUrl: 'http://test.local');

  final Future<dynamic> Function(String path, dynamic query)? getHandler;

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
    return parse({});
  }
}

void main() {
  group('LocationRepository Tests', () {
    test('getLocation calls GET /vehicles/{id}/telemetry/latest and parses VehicleLocation', () async {
      final client = FakeLocationApiClient(
        getHandler: (path, _) async {
          expect(path, equals('/vehicles/veh_9S0001/telemetry/latest'));
          return {
            'vehicleId': 'veh_9S0001',
            'latitude': 12.9716,
            'longitude': 77.5946,
            'description': 'MG Road, Bengaluru',
            'vehicleState': 'PARKED',
            'reportedAt': '2026-11-20T10:00:00Z',
            'isCurrent': true,
          };
        },
      );

      final repo = ApiLocationRepository(apiClient: client);
      final loc = await repo.getLocation('veh_9S0001');

      expect(loc.vehicleId, 'veh_9S0001');
      expect(loc.latitude, 12.9716);
      expect(loc.longitude, 77.5946);
      expect(loc.description, 'MG Road, Bengaluru');
      expect(loc.vehicleState, VehicleState.parked);
      expect(loc.isCurrent, isTrue);
    });

    test('getLocation throws FormatException when response is not Map', () async {
      final client = FakeLocationApiClient(
        getHandler: (path, _) async => 'invalid string',
      );

      final repo = ApiLocationRepository(apiClient: client);
      expect(() => repo.getLocation('veh_9S0001'), throwsA(isA<FormatException>()));
    });

    test('getLocation propagates AppError on failure', () async {
      final client = FakeLocationApiClient(
        getHandler: (path, _) async {
          throw const AppError(
            code: ApiErrorCode.vehicleNotFound,
            message: 'Vehicle not found',
            httpStatus: 404,
          );
        },
      );

      final repo = ApiLocationRepository(apiClient: client);
      expect(
        () => repo.getLocation('veh_unknown'),
        throwsA(
          isA<AppError>().having((e) => e.code, 'code', ApiErrorCode.vehicleNotFound),
        ),
      );
    });

    test('locationRepositoryProvider builds ApiLocationRepository with apiClientProvider', () {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeLocationApiClient()),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(locationRepositoryProvider);
      expect(repo, isA<ApiLocationRepository>());
      expect((repo as ApiLocationRepository).apiClient, isA<FakeLocationApiClient>());
    });
  });
}
