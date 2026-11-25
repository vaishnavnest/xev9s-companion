import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/app/app_shell.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/trips/data/trip_repository.dart';
import 'package:xev9s_app/features/trips/domain/route_point.dart';
import 'package:xev9s_app/features/trips/domain/trip.dart';
import 'package:xev9s_app/features/trips/domain/trip_detail.dart';
import 'package:xev9s_app/features/trips/domain/trip_location.dart';
import 'package:xev9s_app/features/trips/domain/trip_status.dart';
import 'package:xev9s_app/features/trips/presentation/trip_detail_page.dart';
import 'package:xev9s_app/features/trips/presentation/trips_page.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';
import 'package:xev9s_app/shared/widgets/app_map.dart';

final Uint8List _kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_kTransparentPng);
  }
}

class _FakeAuthController extends Notifier<AuthState> implements AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
        UserSummary(userId: 'u1', name: 'Aarav', email: 'a@b.com'),
      );
  @override
  Future<void> checkSession() async {}
  @override
  Future<void> login(String identifier, String password) async {}
  @override
  Future<void> register(String name, String email, String password) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> handleSessionExpired() async {}
  @override
  void consumeSessionExpiredReason() {}
}

class _FakeVehicleStatusNotifier extends AsyncNotifier<VehicleStatus?>
    implements VehicleStatusNotifier {
  @override
  FutureOr<VehicleStatus?> build() => null;
  @override
  Object? get lastRefreshError => null;
  @override
  Future<void> refresh() async {}
}

class _FakeVehiclesController extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  @override
  Future<List<VehicleSummary>> build() async => const [
        VehicleSummary(
          vehicleId: 'veh_1',
          name: 'XEV 9S',
          model: 'Pack 3',
          identifier: 'VIN1',
          associationStatus: AssociationStatus.associated,
        ),
      ];
  @override
  void reset() {}
  @override
  Future<void> refresh() async {}
  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async =>
      const [];
}

class _FakeTripRepository implements TripRepository {
  _FakeTripRepository(this.onGet);
  final Future<TripDetail> Function(String tripId) onGet;

  @override
  Future<TripDetail> getTrip(String vehicleId, String tripId) => onGet(tripId);

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
    return const PagedResult(items: []);
  }
}

Widget _buildDetailApp({
  required TripRepository repo,
  String initialLocation = '/trips/trp_01',
  bool withShell = false,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      if (withShell)
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/location', builder: (_, _) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/charging', builder: (_, _) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/controls', builder: (_, _) => const SizedBox())]),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/trips',
                  builder: (_, _) => const TripsPage(),
                  routes: [
                    GoRoute(
                      path: ':tripId',
                      builder: (_, state) => TripDetailPage(tripId: state.pathParameters['tripId']!),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(routes: [GoRoute(path: '/analytics', builder: (_, _) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (_, _) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const SizedBox())]),
          ],
        )
      else
        GoRoute(
          path: '/trips',
          builder: (_, _) => const TripsPage(),
          routes: [
            GoRoute(
              path: ':tripId',
              builder: (_, state) => TripDetailPage(tripId: state.pathParameters['tripId']!),
            ),
          ],
        ),
    ],
  );

  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_FakeAuthController.new),
      vehicleStatusProvider.overrideWith(_FakeVehicleStatusNotifier.new),
      vehiclesControllerProvider.overrideWith(_FakeVehiclesController.new),
      tripRepositoryProvider.overrideWithValue(repo),
      mapTileProviderProvider.overrideWithValue(_FakeTileProvider()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'selected_vehicle_id': 'veh_1'});
  });

  testWidgets('completed trip renders map with polyline, start & end markers, and summary values', (tester) async {
    final repo = _FakeTripRepository((id) async {
      return TripDetail(
        trip: Trip(
          tripId: id,
          status: TripStatus.completed,
          startedAt: DateTime.utc(2026, 11, 24, 9, 0),
          endedAt: DateTime.utc(2026, 11, 24, 9, 34),
          startLocation: const TripLocation(latitude: 12.9716, longitude: 77.5946, description: 'MG Road'),
          endLocation: const TripLocation(latitude: 12.9759, longitude: 77.6010, description: 'Trinity Circle'),
          distanceKm: 14.8,
          durationSeconds: 2040,
          energyConsumedKwh: 2.6,
        ),
        averageSpeedKmh: 26.1,
        batteryStartPercent: 72.0,
        batteryEndPercent: 68.0,
        route: const [
          RoutePoint(latitude: 12.9716, longitude: 77.5946),
          RoutePoint(latitude: 12.9759, longitude: 77.6010),
        ],
      );
    });

    await tester.pumpWidget(_buildDetailApp(repo: repo, withShell: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip_detail_map')), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byKey(const Key('trip_start_marker')), findsOneWidget);
    expect(find.byKey(const Key('trip_end_marker')), findsOneWidget);
    expect(find.text('14.8 km'), findsOneWidget);
    expect(find.text('72% \u2192 68%'), findsOneWidget);
    expect(find.text('Trips'), findsWidgets); // Shell highlights Trips

    // Back navigation returns to /trips
    await tester.tap(find.byKey(const Key('trip_detail_back_button')));
    await tester.pumpAndSettle();
    expect(find.byType(TripsPage), findsOneWidget);
  });

  testWidgets('ongoing trip renders banner, "-" final values, and ticking elapsed time', (tester) async {
    final repo = _FakeTripRepository((id) async {
      return TripDetail(
        trip: Trip(
          tripId: id,
          status: TripStatus.ongoing,
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          startLocation: const TripLocation(latitude: 12.9716, longitude: 77.5946, description: 'MG Road'),
          distanceKm: 3.5,
        ),
        route: const [
          RoutePoint(latitude: 12.9716, longitude: 77.5946),
          RoutePoint(latitude: 12.9730, longitude: 77.5960),
        ],
      );
    });

    await tester.pumpWidget(_buildDetailApp(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip_ongoing_banner')), findsOneWidget);
    expect(find.text('Trip in progress'), findsOneWidget);
    expect(find.byKey(const Key('trip_ongoing_elapsed')), findsOneWidget);
    expect(find.byKey(const Key('trip_ongoing_end_marker')), findsOneWidget);
    expect(find.text('-'), findsWidgets);
  });

  testWidgets('empty route shows "Route unavailable" and no map; single-point route does not crash', (tester) async {
    final emptyRepo = _FakeTripRepository((id) async {
      return TripDetail(
        trip: Trip(
          tripId: id,
          status: TripStatus.completed,
          startedAt: DateTime.utc(2026, 11, 24, 9, 0),
          startLocation: const TripLocation(description: 'MG Road'),
        ),
        route: const [],
      );
    });

    await tester.pumpWidget(_buildDetailApp(repo: emptyRepo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip_route_unavailable_card')), findsOneWidget);
    expect(find.text('Route unavailable'), findsOneWidget);
    expect(find.byKey(const Key('trip_detail_map')), findsNothing);

    final singleRepo = _FakeTripRepository((id) async {
      return TripDetail(
        trip: Trip(
          tripId: id,
          status: TripStatus.completed,
          startedAt: DateTime.utc(2026, 11, 24, 9, 0),
          startLocation: const TripLocation(latitude: 12.9716, longitude: 77.5946),
        ),
        route: const [RoutePoint(latitude: 12.9716, longitude: 77.5946)],
      );
    });

    await tester.pumpWidget(_buildDetailApp(repo: singleRepo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_detail_map')), findsOneWidget);
  });

  testWidgets('404 returns "Trip not found" state with back button', (tester) async {
    final repo = _FakeTripRepository((_) async {
      throw const AppError(code: ApiErrorCode.notFound, message: 'Not found');
    });

    await tester.pumpWidget(_buildDetailApp(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip_not_found_state')), findsOneWidget);
    expect(find.text('Trip not found'), findsOneWidget);
    expect(find.text('Back to Trips'), findsOneWidget);
  });
}
