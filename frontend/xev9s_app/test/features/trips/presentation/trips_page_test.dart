import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/trips/data/trip_repository.dart';
import 'package:xev9s_app/features/trips/domain/trip.dart';
import 'package:xev9s_app/features/trips/domain/trip_detail.dart';
import 'package:xev9s_app/features/trips/domain/trip_location.dart';
import 'package:xev9s_app/features/trips/domain/trip_status.dart';
import 'package:xev9s_app/features/trips/presentation/trips_page.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/shared/widgets/error_view.dart';
import 'package:xev9s_app/shared/widgets/loading_view.dart';

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

class _FakeTripRepository implements TripRepository {
  _FakeTripRepository(this.handler);
  final Future<PagedResult<Trip>> Function(int page, TripStatus? status, String? from, String? to)
      handler;

  @override
  Future<PagedResult<Trip>> listTrips(
    String vehicleId, {
    int? page,
    int? pageSize,
    String? sort,
    TripStatus? status,
    String? from,
    String? to,
  }) {
    return handler(page ?? 1, status, from, to);
  }

  @override
  Future<TripDetail> getTrip(String vehicleId, String tripId) async {
    throw UnimplementedError();
  }
}

Future<Widget> _buildTripsApp({
  required TripRepository repo,
  double width = 420,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/trips',
    routes: [
      GoRoute(
        path: '/trips',
        builder: (_, _) => const TripsPage(),
        routes: [
          GoRoute(
            path: ':tripId',
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: Text('Detail ${state.pathParameters['tripId']}')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authControllerProvider.overrideWith(_FakeAuthController.new),
      vehicleStatusProvider.overrideWith(_FakeVehicleStatusNotifier.new),
      tripRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: Size(width, 800)),
        child: child!,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'selected_vehicle_id': 'veh_1'});
  });

  testWidgets('renders loading, error with Retry, and empty states (unfiltered and filtered)', (tester) async {
    final completer = Completer<PagedResult<Trip>>();
    final loadingRepo = _FakeTripRepository((_, _, _, _) => completer.future);

    await tester.pumpWidget(await _buildTripsApp(repo: loadingRepo));
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);

    completer.completeError(AppError.noConnection());
    await tester.pumpAndSettle();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Empty unfiltered state
    final emptyRepo = _FakeTripRepository((_, _, _, _) async => const PagedResult(items: []));
    await tester.pumpWidget(await _buildTripsApp(repo: emptyRepo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trips_empty_all')), findsOneWidget);
    expect(find.text('No trips yet'), findsOneWidget);

    // Filtered empty state shows Clear filters
    await tester.tap(find.byKey(const Key('trip_filter_status_ongoing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trips_empty_filtered')), findsOneWidget);
    expect(find.text('No trips match these filters'), findsOneWidget);
    expect(find.byKey(const Key('trip_filter_clear')), findsWidgets);
  });

  testWidgets('renders grouped trips, ongoing badge, "-" for null energy, filters, and wide layout', (tester) async {
    final now = DateTime.now();
    final repo = _FakeTripRepository((page, status, from, to) async {
      final all = [
        Trip(
          tripId: 't_on',
          status: TripStatus.ongoing,
          startedAt: now.subtract(const Duration(minutes: 10)),
          startLocation: const TripLocation(description: 'MG Road'),
          distanceKm: null,
          energyConsumedKwh: null,
        ),
        Trip(
          tripId: 't_comp',
          status: TripStatus.completed,
          startedAt: now.subtract(const Duration(days: 1)),
          endedAt: now.subtract(const Duration(days: 1)).add(const Duration(minutes: 30)),
          startLocation: const TripLocation(description: 'Indiranagar'),
          endLocation: const TripLocation(description: 'Whitefield'),
          distanceKm: 12.4,
          durationSeconds: 1800,
          energyConsumedKwh: null,
        ),
      ];
      final filtered = status == null ? all : all.where((t) => t.status == status).toList();
      return PagedResult(items: filtered);
    });

    await tester.pumpWidget(await _buildTripsApp(repo: repo, width: 900));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byKey(const Key('trip_in_progress_badge_t_on')), findsOneWidget);
    expect(find.text('-'), findsWidgets);

    // Filter to Completed -> ongoing row disappears
    await tester.tap(find.byKey(const Key('trip_filter_status_completed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_row_t_on')), findsNothing);
    expect(find.byKey(const Key('trip_row_t_comp')), findsOneWidget);

    // Custom date range picker opens
    final customChip = find.byKey(const Key('trip_filter_date_custom'));
    await tester.ensureVisible(customChip);
    await tester.pumpAndSettle();
    await tester.tap(customChip);
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  });

  testWidgets('infinite scroll loads page 2, shows inline Retry on failure, and preserves scroll after detail pop', (tester) async {
    var failPage2 = true;
    final now = DateTime.now();
    final page1Trips = List.generate(
      12,
      (i) => Trip(
        tripId: 't_$i',
        status: TripStatus.completed,
        startedAt: now.subtract(Duration(hours: i + 1)),
        endedAt: now.subtract(Duration(hours: i)),
        startLocation: TripLocation(description: 'Start $i'),
        endLocation: TripLocation(description: 'End $i'),
        distanceKm: 5.0 + i,
        durationSeconds: 600,
        energyConsumedKwh: 1.2,
      ),
    );

    final repo = _FakeTripRepository((page, _, _, _) async {
      if (page == 1) {
        return PagedResult(
          items: page1Trips,
          pagination: const Pagination(page: 1, pageSize: 12, totalItems: 15, totalPages: 2),
        );
      }
      if (failPage2) {
        throw AppError.noConnection();
      }
      return PagedResult(
        items: [
          Trip(
            tripId: 't_page2',
            status: TripStatus.completed,
            startedAt: now.subtract(const Duration(hours: 20)),
            startLocation: const TripLocation(description: 'Page 2 Start'),
          ),
        ],
        pagination: const Pagination(page: 2, pageSize: 12, totalItems: 15, totalPages: 2),
      );
    });

    await tester.pumpWidget(await _buildTripsApp(repo: repo));
    await tester.pumpAndSettle();

    // Scroll to bottom to trigger loadMore (which fails first)
    await tester.drag(find.byKey(const PageStorageKey<String>('trips_list_view')), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trips_retry_load_more')), findsOneWidget);

    // Retry loadMore succeeds
    failPage2 = false;
    await tester.tap(find.byKey(const Key('trips_retry_load_more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_row_t_page2')), findsOneWidget);

    // Open a trip detail and pop back -> page2 item still present
    await tester.tap(find.byKey(const Key('trip_row_t_page2')));
    await tester.pumpAndSettle();
    expect(find.text('Detail t_page2'), findsOneWidget);

    await tester.tap(find.text('Go Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_row_t_page2')), findsOneWidget);
  });
}
