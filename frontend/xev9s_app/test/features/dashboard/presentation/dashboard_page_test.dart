import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide LockState;
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/dashboard/presentation/dashboard_page.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';
import 'package:xev9s_app/shared/widgets/empty_state.dart';
import 'package:xev9s_app/shared/widgets/error_view.dart';
import 'package:xev9s_app/shared/widgets/stale_banner.dart';

class FakeTokenStorage implements TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'test_token';
  @override
  Future<String?> getRefreshToken() async => 'test_refresh_token';
  @override
  Future<void> saveAccessToken(String token) async {}
  @override
  Future<void> saveRefreshToken(String token) async {}
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clearTokens() async {}
}

class FakeAuthController extends AuthController {
  FakeAuthController(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class FakeSelectedVehicleNotifier extends SelectedVehicleNotifier {
  FakeSelectedVehicleNotifier(this._initialId);
  final String? _initialId;

  @override
  String? build() => _initialId;
}

class MockTestRealtimeService implements RealtimeService {
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _state = StreamController<RealtimeConnectionState>.broadcast();
  final _resync = StreamController<void>.broadcast();

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Stream<RealtimeConnectionState> get connectionState => _state.stream;

  @override
  RealtimeConnectionState get currentConnectionState => RealtimeConnectionState.connected;

  @override
  Stream<void> get onResync => _resync.stream;

  @override
  Future<void> connect({String? vehicleId}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    _events.close();
    _state.close();
    _resync.close();
  }
}

class TestVehicleStatusNotifier extends VehicleStatusNotifier {
  TestVehicleStatusNotifier(this._initial);

  final AsyncValue<VehicleStatus?> _initial;

  @override
  FutureOr<VehicleStatus?> build() {
    if (_initial.hasError) {
      throw _initial.error!;
    }
    return _initial.asData?.value;
  }
}

class DelayedVehicleStatusNotifier extends VehicleStatusNotifier {
  DelayedVehicleStatusNotifier(this._completer);

  final Completer<VehicleStatus?> _completer;

  @override
  FutureOr<VehicleStatus?> build() => _completer.future;
}

void main() {
  group('DashboardPage Widget Tests', () {
    late MockTestRealtimeService realtimeService;

    final baseStatus = VehicleStatus(
      vehicleId: 'veh_01',
      name: 'Asha\'s XEV 9S',
      model: 'XEV 9S AWD Performance',
      vehicleState: VehicleState.parked,
      connectivity: ConnectivityStatus.online,
      battery: const BatterySummary(percent: 75.0, level: BatteryLevel.normal),
      range: const RangeSummary(estimatedKm: 340.0),
      odometerKm: 15000.0,
      speedKmh: 0.0,
      lockState: LockState.locked,
      preconditioningState: PreconditioningState.inactive,
      charging: const ChargingSummary(state: ChargingState.notConnected),
      lastUpdatedAt: DateTime.parse('2026-11-18T05:00:00.000Z'),
      isStale: false,
    );

    setUp(() {
      realtimeService = MockTestRealtimeService();
    });

    tearDown(() {
      realtimeService.dispose();
    });

    Widget createWidget({
      String? selectedVehicleId = 'veh_01',
      required AsyncValue<VehicleStatus?> statusValue,
      GoRouter? customRouter,
    }) {
      final router = customRouter ??
          GoRouter(
            initialLocation: '/home',
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardPage(),
              ),
              GoRoute(
                path: '/location',
                builder: (context, state) => const Scaffold(body: Text('Location Page')),
              ),
              GoRoute(
                path: '/charging',
                builder: (context, state) => const Scaffold(body: Text('Charging Page')),
              ),
              GoRoute(
                path: '/controls',
                builder: (context, state) => const Scaffold(body: Text('Controls Page')),
              ),
            ],
          );

      return ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          authControllerProvider.overrideWith(
            () => FakeAuthController(
              const AuthAuthenticated(
                UserSummary(userId: 'u1', name: 'Asha', email: 'asha@example.com'),
              ),
            ),
          ),
          realtimeServiceProvider.overrideWithValue(realtimeService),
          realtimeConnectionStateProvider.overrideWith(
            (ref) => Stream.value(RealtimeConnectionState.connected),
          ),
          selectedVehicleProvider.overrideWith(
            () => FakeSelectedVehicleNotifier(selectedVehicleId),
          ),
          vehicleStatusProvider.overrideWith(
            () => TestVehicleStatusNotifier(statusValue),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('shows empty state when no vehicle is selected', (tester) async {
      await tester.pumpWidget(
        createWidget(
          selectedVehicleId: null,
          statusValue: AsyncData(baseStatus),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No vehicle selected'), findsOneWidget);
    });

    testWidgets('shows loading view when vehicle status is loading', (tester) async {
      final completer = Completer<VehicleStatus?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
            authControllerProvider.overrideWith(
              () => FakeAuthController(
                const AuthAuthenticated(
                  UserSummary(userId: 'u1', name: 'Asha', email: 'asha@example.com'),
                ),
              ),
            ),
            realtimeServiceProvider.overrideWithValue(realtimeService),
            selectedVehicleProvider.overrideWith(
              () => FakeSelectedVehicleNotifier('veh_01'),
            ),
            vehicleStatusProvider.overrideWith(
              () => DelayedVehicleStatusNotifier(completer),
            ),
          ],
          child: const MaterialApp(home: DashboardPage()),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error view when initial load fails', (tester) async {
      await tester.pumpWidget(
        createWidget(
          statusValue: AsyncError(AppError.noConnection(), StackTrace.empty),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders populated dashboard cards and formats null values with "-"', (tester) async {
      final nullTelemetryStatus = baseStatus.copyWith(
        speedKmh: null,
        battery: const BatterySummary(percent: null),
        charging: const ChargingSummary(state: ChargingState.notConnected, powerKw: null),
      );

      await tester.pumpWidget(
        createWidget(statusValue: AsyncData(nullTelemetryStatus)),
      );
      await tester.pumpAndSettle();

      // Vehicle header
      expect(find.text('Asha\'s XEV 9S'), findsOneWidget);
      expect(find.text('XEV 9S AWD Performance'), findsOneWidget);

      // Battery & Range card
      expect(find.text('-'), findsWidgets); // Speed, battery, charging power all return '-'
      expect(find.text('0'), findsNothing); // NULL MUST NEVER BE SHOWN AS '0'
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('340.0 km'), findsOneWidget);

      // Info card
      expect(find.text('15000.0 km'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);

      // Charging card
      expect(find.text('Charging Status'), findsOneWidget);
      expect(find.text('Not Connected'), findsOneWidget);

      // Footer
      expect(find.textContaining('Updated'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('offline vehicle displays StaleBanner and dimmed values', (tester) async {
      final offlineStatus = baseStatus.copyWith(
        connectivity: ConnectivityStatus.offline,
        vehicleState: VehicleState.offline,
        isStale: true,
        speedKmh: null,
      );

      await tester.pumpWidget(
        createWidget(statusValue: AsyncData(offlineStatus)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StaleBanner), findsOneWidget);
      expect(find.textContaining('Offline - showing last known data'), findsOneWidget);
    });

    testWidgets('tapping charging card navigates to /charging', (tester) async {
      await tester.pumpWidget(createWidget(statusValue: AsyncData(baseStatus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Charging Status'));
      await tester.pumpAndSettle();

      expect(find.text('Charging Page'), findsOneWidget);
    });

    testWidgets('tapping quick action buttons navigate to respective routes', (tester) async {
      await tester.pumpWidget(createWidget(statusValue: AsyncData(baseStatus)));
      await tester.pumpAndSettle();

      // Tap Location button
      await tester.tap(find.text('Location'));
      await tester.pumpAndSettle();
      expect(find.text('Location Page'), findsOneWidget);
    });

    testWidgets('responsive layout adapts across 720px threshold', (tester) async {
      // 1. Narrow viewport (< 720)
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(statusValue: AsyncData(baseStatus)));
      await tester.pumpAndSettle();

      expect(find.text('Asha\'s XEV 9S'), findsOneWidget);

      // 2. Wide viewport (>= 720)
      tester.view.physicalSize = const Size(1024, 900);
      await tester.pumpWidget(createWidget(statusValue: AsyncData(baseStatus)));
      await tester.pumpAndSettle();

      expect(find.text('Asha\'s XEV 9S'), findsOneWidget);
    });
  });
}
