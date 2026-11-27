import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/features/trips/data/trip_repository.dart';
import 'package:xev9s_app/features/trips/domain/trip_status.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('ApiTripRepository listTrips parses paginated snake_case response and sends filters', () async {
    final adapter = _StubAdapter((options) {
      return ResponseBody.fromString(
        '''
        {
          "trips": [
            {
              "trip_id": "trp_01",
              "status": "completed",
              "started_at": "2026-11-24T09:00:00Z",
              "start_location": {"latitude": 12.97, "longitude": 77.59, "description": "MG Road"}
            }
          ],
          "pagination": {
            "page": 2,
            "page_size": 20,
            "total_items": 25,
            "total_pages": 2
          }
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4012'))
      ..httpClientAdapter = adapter;
    final repo = ApiTripRepository(apiClient: ApiClient(dio: dio));

    final result = await repo.listTrips(
      'veh_1',
      page: 2,
      status: TripStatus.completed,
      from: '2026-11-24T00:00:00Z',
      to: '2026-11-24T23:59:59Z',
    );

    expect(adapter.lastRequest?.path, '/vehicles/veh_1/trips');
    expect(adapter.lastRequest?.queryParameters['page'], 2);
    expect(adapter.lastRequest?.queryParameters['page_size'], 20);
    expect(adapter.lastRequest?.queryParameters['status'], 'completed');
    expect(adapter.lastRequest?.queryParameters['sort'], '-started_at');
    expect(result.items.length, 1);
    expect(result.items.first.tripId, 'trp_01');
    expect(result.pagination?.totalItems, 25);
    expect(result.pagination?.totalPages, 2);
  });

  test('ApiTripRepository getTrip parses TripDetail', () async {
    final adapter = _StubAdapter((options) {
      return ResponseBody.fromString(
        '''
        {
          "trip_id": "trp_0105",
          "status": "completed",
          "started_at": "2026-11-24T09:00:00Z",
          "start_location": {"latitude": 12.97, "longitude": 77.59},
          "average_speed_kmh": 30.2,
          "battery": {"start_percent": 75, "end_percent": 70},
          "route": [
            {"latitude": 12.97, "longitude": 77.59, "timestamp": "2026-11-24T09:00:00Z"}
          ]
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4012'))
      ..httpClientAdapter = adapter;
    final repo = ApiTripRepository(apiClient: ApiClient(dio: dio));

    final detail = await repo.getTrip('veh_1', 'trp_0105');
    expect(adapter.lastRequest?.path, '/vehicles/veh_1/trips/trp_0105');
    expect(detail.tripId, 'trp_0105');
    expect(detail.averageSpeedKmh, 30.2);
    expect(detail.route.length, 1);
  });
}
