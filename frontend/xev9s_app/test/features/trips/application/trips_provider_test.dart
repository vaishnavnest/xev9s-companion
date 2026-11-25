import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/constants/app_constants.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/trips/application/trips_provider.dart';
import 'package:xev9s_app/features/trips/data/trip_repository.dart';
import 'package:xev9s_app/features/trips/domain/route_utils.dart';
import 'package:xev9s_app/features/trips/domain/trip.dart';
import 'package:xev9s_app/features/trips/domain/trip_detail.dart';
import 'package:xev9s_app/features/trips/domain/trip_location.dart';
import 'package:xev9s_app/features/trips/domain/trip_status.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class _FakeAuthController extends Notifier<AuthState> implements AuthController {
  _FakeAuthController([
    this._initial = const AuthAuthenticated(
      UserSummary(userId: 'u1', name: 'Aarav', email: 'a@b.com'),
    ),
  ]);
  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void setAuthState(AuthState next) => state = next;

  @override
  Future<void> checkSession() async {}
  @override
  Future<void> login(String identifier, String password) async {}
  @override
  Future<void> register(String name, String email, String password) async {}
  @override
  Future<void> logout() async {
    state = const AuthUnauthenticated();
  }
  @override
  Future<void> handleSessionExpired() async {}
  @override
  void consumeSessionExpiredReason() {}
}

class _FakeVehicleStatusNotifier extends AsyncNotifier<VehicleStatus?>
    implements VehicleStatusNotifier {
  @override
  FutureOr<VehicleStatus?> build() => null;

  void emitStatus(VehicleStatus status) => state = AsyncData(status);

  @override
  Object? get lastRefreshError => null;

  @override
  Future<void> refresh() async {}
}

class _FakeTripRepository implements TripRepository {
  final List<({int page, TripStatus? status, String? from, String? to})> calls = [];
  Future<PagedResult<Trip>> Function(int page, TripStatus? status, String? from, String? to)?
      onList;

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
    final p = page ?? 1;
    calls.add((page: p, status: status, from: from, to: to));
    if (onList != null) {
      return onList!(p, status, from, to);
    }
    return const PagedResult(items: []);
  }

  @override
  Future<TripDetail> getTrip(String vehicleId, String tripId) async {
    throw UnimplementedError();
  }
}

Trip _makeTrip(String id, {TripStatus status = TripStatus.completed}) {
  return Trip(
    tripId: id,
    status: status,
    startedAt: DateTime.utc(2026, 11, 25, 9, 0),
    startLocation: const TripLocation(description: 'MG Road'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads first page, appends loadMore, de-duplicates, and sets hasMore=false at end', () async {
    final repo = _FakeTripRepository()
      ..onList = (page, _, _, _) async {
        if (page == 1) {
          return PagedResult(
            items: [_makeTrip('t1'), _makeTrip('t2')],
            pagination: const Pagination(page: 1, pageSize: 2, totalItems: 3, totalPages: 2),
          );
        }
        return PagedResult(
          // t2 duplicated intentionally to verify de-duplication
          items: [_makeTrip('t2'), _makeTrip('t3')],
          pagination: const Pagination(page: 2, pageSize: 2, totalItems: 3, totalPages: 2),
        );
      };

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        tripRepositoryProvider.overrideWithValue(repo),
        vehicleStatusProvider.overrideWith(_FakeVehicleStatusNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedVehicleProvider.notifier).select('veh_1');
    final initial = await container.read(tripsProvider.future);
    expect(initial.items.map((e) => e.tripId), ['t1', 't2']);
    expect(initial.hasMore, isTrue);

    await container.read(tripsProvider.notifier).loadMore();
    final afterMore = container.read(tripsProvider).requireValue;
    expect(afterMore.items.map((e) => e.tripId), ['t1', 't2', 't3']);
    expect(afterMore.hasMore, isFalse);

    // Subsequent loadMore does nothing when hasMore is false
    await container.read(tripsProvider.notifier).loadMore();
    expect(repo.calls.length, 2);
  });

  test('prevents duplicate concurrent loadMore requests and keeps items on failed loadMore', () async {
    final completer = Completer<PagedResult<Trip>>();
    final repo = _FakeTripRepository()
      ..onList = (page, _, _, _) async {
        if (page == 1) {
          return PagedResult(
            items: [_makeTrip('t1')],
            pagination: const Pagination(page: 1, pageSize: 1, totalItems: 2, totalPages: 2),
          );
        }
        return completer.future;
      };

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        tripRepositoryProvider.overrideWithValue(repo),
        vehicleStatusProvider.overrideWith(_FakeVehicleStatusNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedVehicleProvider.notifier).select('veh_1');
    await container.read(tripsProvider.future);

    final f1 = container.read(tripsProvider.notifier).loadMore();
    final f2 = container.read(tripsProvider.notifier).loadMore();
    expect(repo.calls.where((c) => c.page == 2).length, 1);

    completer.completeError(AppError.noConnection());
    await Future.wait([f1, f2]);

    final failedState = container.read(tripsProvider).requireValue;
    expect(failedState.items.map((e) => e.tripId), ['t1']);
    expect(failedState.error, isNotNull);
    expect(failedState.isLoadingMore, isFalse);
  });

  test('filter and dateRange changes reset and reload; refresh keeps items visible', () async {
    final repo = _FakeTripRepository()
      ..onList = (page, status, from, to) async {
        return PagedResult(
          items: [_makeTrip(status == TripStatus.ongoing ? 't_on' : 't_all')],
        );
      };

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        tripRepositoryProvider.overrideWithValue(repo),
        vehicleStatusProvider.overrideWith(_FakeVehicleStatusNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedVehicleProvider.notifier).select('veh_1');
    await container.read(tripsProvider.future);

    await container.read(tripsProvider.notifier).setStatusFilter(TripStatus.ongoing);
    expect(container.read(tripsProvider).requireValue.items.first.tripId, 't_on');

    await container.read(tripsProvider.notifier).setDateRange(const TripDateRange.today());
    expect(repo.calls.last.from, isNotNull);
    expect(repo.calls.last.to, isNotNull);

    await container.read(tripsProvider.notifier).clearFilters();
    expect(container.read(tripsProvider).requireValue.hasActiveFilters, isFalse);
  });

  test('DRIVING -> PARKED transition and resync signal trigger refresh', () async {
    final resyncController = StreamController<void>.broadcast();
    addTearDown(resyncController.close);

    final repo = _FakeTripRepository()
      ..onList = (page, _, _, _) async => PagedResult(items: [_makeTrip('t1')]);

    final statusNotifier = _FakeVehicleStatusNotifier();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        tripRepositoryProvider.overrideWithValue(repo),
        vehicleStatusProvider.overrideWith(() => statusNotifier),
        realtimeResyncProvider.overrideWith((ref) => resyncController.stream),
      ],
    );
    addTearDown(container.dispose);
    container.listen(tripsProvider, (previous, next) {});

    await container.read(selectedVehicleProvider.notifier).select('veh_1');
    await container.read(tripsProvider.future);
    expect(repo.calls.length, 1);

    statusNotifier.emitStatus(
      VehicleStatus(
        vehicleId: 'veh_1',
        connectivity: VehicleConnectivity.online,
        vehicleState: VehicleState.driving,
        lastUpdatedAt: DateTime.utc(2026, 11, 25),
      ),
    );
    await pumpEventQueue();
    expect(repo.calls.length, 1);

    statusNotifier.emitStatus(
      VehicleStatus(
        vehicleId: 'veh_1',
        connectivity: VehicleConnectivity.online,
        vehicleState: VehicleState.parked,
        lastUpdatedAt: DateTime.utc(2026, 11, 25, 0, 1),
      ),
    );
    await pumpEventQueue();
    expect(repo.calls.length, 2);

    resyncController.add(null);
    await pumpEventQueue();
    expect(repo.calls.length, 3);
  });

  test('ongoing auto-refresh runs only while screen is visible and ongoing trip exists', () {
    fakeAsync((async) {
      final repo = _FakeTripRepository()
        ..onList = (_, _, _, _) async =>
            PagedResult(items: [_makeTrip('t_on', status: TripStatus.ongoing)]);

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          tripRepositoryProvider.overrideWithValue(repo),
          vehicleStatusProvider.overrideWith(_FakeVehicleStatusNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_1');
      container.read(tripsProvider);
      async.flushMicrotasks();
      expect(repo.calls.length, 1);

      // Not visible yet -> no periodic refresh
      async.elapse(const Duration(seconds: AppConstants.ongoingTripRefreshSeconds * 2));
      expect(repo.calls.length, 1);

      // Screen visible -> periodic refresh fires
      container.read(tripsProvider.notifier).setScreenVisible(true);
      async.elapse(const Duration(seconds: AppConstants.ongoingTripRefreshSeconds));
      expect(repo.calls.length, 2);

      // Screen hidden -> timer stops
      container.read(tripsProvider.notifier).setScreenVisible(false);
      async.elapse(const Duration(seconds: AppConstants.ongoingTripRefreshSeconds * 2));
      expect(repo.calls.length, 2);
    });
  });

  test('resets on vehicle change and logout', () async {
    final auth = _FakeAuthController();
    final repo = _FakeTripRepository()
      ..onList = (_, _, _, _) async => PagedResult(items: [_makeTrip('t1')]);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        tripRepositoryProvider.overrideWithValue(repo),
        vehicleStatusProvider.overrideWith(_FakeVehicleStatusNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedVehicleProvider.notifier).select('veh_1');
    await container.read(tripsProvider.future);
    expect(container.read(tripsProvider).requireValue.items.length, 1);

    await auth.logout();
    final afterLogout = await container.read(tripsProvider.future);
    expect(afterLogout.items, isEmpty);
  });
}
