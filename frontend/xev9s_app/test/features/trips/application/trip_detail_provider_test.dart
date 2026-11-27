import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/constants/app_constants.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/features/trips/application/trip_detail_provider.dart';
import 'package:xev9s_app/features/trips/data/trip_repository.dart';
import 'package:xev9s_app/features/trips/domain/route_point.dart';
import 'package:xev9s_app/features/trips/domain/trip.dart';
import 'package:xev9s_app/features/trips/domain/trip_detail.dart';
import 'package:xev9s_app/features/trips/domain/trip_location.dart';
import 'package:xev9s_app/features/trips/domain/trip_status.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';

class _FakeDetailTripRepository implements TripRepository {
  int getTripCalls = 0;
  Future<TripDetail> Function(String vehicleId, String tripId)? onGetTrip;

  @override
  Future<TripDetail> getTrip(String vehicleId, String tripId) async {
    getTripCalls++;
    return onGetTrip!(vehicleId, tripId);
  }

  @override
  Future<PagedResult<Trip>> listTrips(
    String vehicleId, {
    int? page,
    int? pageSize,
    String? sort,
    TripStatus? status,
    String? from,
    String? to,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  const key = TripDetailKey(vehicleId: 'veh_1', tripId: 'trp_01');

  test('loads detail by id directly and computes tripRouteForMapProvider', () async {
    final repo = _FakeDetailTripRepository()
      ..onGetTrip = (_, id) async => TripDetail(
            trip: Trip(
              tripId: id,
              status: TripStatus.completed,
              startedAt: DateTime.utc(2026, 11, 24, 9, 0),
              startLocation: const TripLocation(latitude: 12.97, longitude: 77.59),
            ),
            route: const [
              RoutePoint(latitude: 12.97, longitude: 77.59),
              RoutePoint(latitude: 12.98, longitude: 77.60),
            ],
          );

    final container = ProviderContainer(
      overrides: [tripRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final state = await container.read(tripDetailProvider(key).future);
    expect(state.isNotFound, isFalse);
    expect(state.detail?.tripId, 'trp_01');

    final mapData = container.read(tripRouteForMapProvider(key));
    expect(mapData?.points.length, 2);
    expect(mapData?.bounds?.minLat, 12.97);
    expect(mapData?.bounds?.maxLat, 12.98);
  });

  test('404 returns TripDetailState.notFound without crashing', () async {
    final repo = _FakeDetailTripRepository()
      ..onGetTrip = (_, _) async => throw const AppError(
            code: ApiErrorCode.notFound,
            message: 'Trip not found',
          );

    final container = ProviderContainer(
      overrides: [tripRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final state = await container.read(tripDetailProvider(key).future);
    expect(state.isNotFound, isTrue);
    expect(state.detail, isNull);
  });

  test('ongoing detail refreshes on interval and stops with one final refresh when completed', () {
    fakeAsync((async) {
      var callCount = 0;
      final repo = _FakeDetailTripRepository()
        ..onGetTrip = (_, id) async {
          callCount++;
          // First 2 calls are ongoing, then transitions to completed
          final completed = callCount >= 3;
          return TripDetail(
            trip: Trip(
              tripId: id,
              status: completed ? TripStatus.completed : TripStatus.ongoing,
              startedAt: DateTime.utc(2026, 11, 24, 9, 0),
              startLocation: const TripLocation(latitude: 12.97, longitude: 77.59),
              distanceKm: completed ? 14.5 : 4.2,
            ),
          );
        };

      final container = ProviderContainer(
        overrides: [tripRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(tripDetailProvider(key));
      async.flushMicrotasks();
      expect(repo.getTripCalls, 1);

      // 15s -> ongoing refresh #2 (still ongoing)
      async.elapse(const Duration(seconds: AppConstants.ongoingTripRefreshSeconds));
      expect(repo.getTripCalls, 2);

      // 15s -> refresh #3 returns COMPLETED -> triggers 1 final refresh (#4) and stops timer
      async.elapse(const Duration(seconds: AppConstants.ongoingTripRefreshSeconds));
      expect(repo.getTripCalls, 4);
      expect(
        container.read(tripDetailProvider(key)).requireValue.detail?.status,
        TripStatus.completed,
      );

      // Further intervals do NOT poll
      async.elapse(const Duration(seconds: AppConstants.ongoingTripRefreshSeconds * 3));
      expect(repo.getTripCalls, 4);
    });
  });

  test('trip.completed event refreshes matching trip detail only', () async {
    final eventsController = StreamController<RealtimeEvent>.broadcast();
    addTearDown(eventsController.close);

    final repo = _FakeDetailTripRepository()
      ..onGetTrip = (_, id) async => TripDetail(
            trip: Trip(
              tripId: id,
              status: TripStatus.completed,
              startedAt: DateTime.utc(2026, 11, 24, 9, 0),
              startLocation: const TripLocation(latitude: 12.97, longitude: 77.59),
            ),
          );

    final container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        realtimeEventsProvider.overrideWith((ref) => eventsController.stream),
      ],
    );
    addTearDown(container.dispose);
    container.listen(tripDetailProvider(key), (previous, next) {});

    await container.read(tripDetailProvider(key).future);
    expect(repo.getTripCalls, 1);

    // Different trip_id is ignored
    eventsController.add(
      RealtimeEvent(
        type: RealtimeEventType.tripCompleted,
        vehicleId: 'veh_1',
        timestamp: DateTime.utc(2026, 11, 24, 9, 30),
        rawData: const {'trip_id': 'trp_OTHER'},
      ),
    );
    await pumpEventQueue();
    expect(repo.getTripCalls, 1);

    // Matching vehicle_id and trip_id triggers refresh
    eventsController.add(
      RealtimeEvent(
        type: RealtimeEventType.tripCompleted,
        vehicleId: 'veh_1',
        timestamp: DateTime.utc(2026, 11, 24, 9, 35),
        rawData: const {'trip_id': 'trp_01'},
      ),
    );
    await pumpEventQueue();
    expect(repo.getTripCalls, 2);
  });
}
