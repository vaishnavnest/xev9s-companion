import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/location/application/vehicle_location_provider.dart';
import 'package:xev9s_app/features/location/data/location_repository.dart';
import 'package:xev9s_app/features/location/domain/vehicle_location.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class FakeLocationRepository implements LocationRepository {
  VehicleLocation? locationResult;
  Exception? error;
  int getLocationCalls = 0;
  String? lastRequestedVehicleId;

  @override
  Future<VehicleLocation> getLocation(String vehicleId) async {
    getLocationCalls++;
    lastRequestedVehicleId = vehicleId;
    if (error != null) throw error!;
    return locationResult!;
  }
}

class FakeRealtimeService implements RealtimeService {
  final eventsController = StreamController<RealtimeEvent>.broadcast();
  final stateController = StreamController<RealtimeConnectionState>.broadcast();
  final resyncController = StreamController<void>.broadcast();

  @override
  Stream<RealtimeEvent> get events => eventsController.stream;

  @override
  Stream<RealtimeConnectionState> get connectionState => stateController.stream;

  @override
  RealtimeConnectionState get currentConnectionState =>
      RealtimeConnectionState.connected;

  @override
  Stream<void> get onResync => resyncController.stream;

  @override
  Future<void> connect({String? vehicleId}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    eventsController.close();
    stateController.close();
    resyncController.close();
  }
}

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

class TestAuthController extends AuthController {
  TestAuthController(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  void emit(AuthState state) => this.state = state;
}

class TestVehicleStatusNotifier extends VehicleStatusNotifier {
  TestVehicleStatusNotifier(this._initialStatus);
  final VehicleStatus? _initialStatus;

  @override
  FutureOr<VehicleStatus?> build() => _initialStatus;

  void setStatus(VehicleStatus? status) {
    state = AsyncData(status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationRepository fakeRepository;
  late FakeRealtimeService fakeRealtimeService;
  late ProviderContainer container;
  late SharedPreferences prefs;

  final initialLocation = VehicleLocation(
    vehicleId: 'veh_9S0001',
    latitude: 12.9716,
    longitude: 77.5946,
    description: 'MG Road, Bengaluru',
    vehicleState: VehicleState.driving,
    reportedAt: DateTime.parse('2026-11-23T10:00:00Z'),
    isCurrent: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_vehicle_id': 'veh_9S0001'});
    prefs = await SharedPreferences.getInstance();

    fakeRepository = FakeLocationRepository()..locationResult = initialLocation;
    fakeRealtimeService = FakeRealtimeService();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        locationRepositoryProvider.overrideWithValue(fakeRepository),
        realtimeServiceProvider.overrideWithValue(fakeRealtimeService),
        authControllerProvider.overrideWith(
          () => TestAuthController(
            const AuthAuthenticated(
              UserSummary(userId: 'u1', name: 'Test User', email: 'test@example.com'),
            ),
          ),
        ),
      ],
    );
    container.listen(vehicleLocationProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    fakeRealtimeService.dispose();
  });

  group('VehicleLocationNotifier Provider Tests', () {
    test('initial load fetches via repository for selected vehicle', () async {
      final loc = await container.read(vehicleLocationProvider.future);

      expect(loc, equals(initialLocation));
      expect(fakeRepository.getLocationCalls, 1);
      expect(fakeRepository.lastRequestedVehicleId, 'veh_9S0001');
    });

    test('returns null when no vehicle is selected', () async {
      final emptyPrefs = await SharedPreferences.getInstance();
      await emptyPrefs.remove('selected_vehicle_id');
      final emptyRepo = FakeLocationRepository();

      final emptyContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(emptyPrefs),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          locationRepositoryProvider.overrideWithValue(emptyRepo),
          realtimeServiceProvider.overrideWithValue(fakeRealtimeService),
        ],
      );

      final loc = await emptyContainer.read(vehicleLocationProvider.future);
      expect(loc, isNull);
      expect(emptyRepo.getLocationCalls, 0);

      emptyContainer.dispose();
    });

    test('refresh re-fetches and preserves existing data during load without flashing spinner', () async {
      await container.read(vehicleLocationProvider.future);
      expect(fakeRepository.getLocationCalls, 1);

      final updatedLocation = initialLocation.copyWith(
        latitude: 12.9720,
        longitude: 77.5950,
        description: 'Updated Point',
      );
      fakeRepository.locationResult = updatedLocation;

      final refreshFuture = container.read(vehicleLocationProvider.notifier).refresh();

      // Check state while loading: hasValue is true (data is preserved)
      final stateWhileLoading = container.read(vehicleLocationProvider);
      expect(stateWhileLoading.hasValue, isTrue);
      expect(stateWhileLoading.value, equals(initialLocation));

      await refreshFuture;

      final finalState = container.read(vehicleLocationProvider);
      expect(finalState.value, equals(updatedLocation));
      expect(fakeRepository.getLocationCalls, 2);
    });

    test('vehicle.location event updates state when newer', () async {
      await container.read(vehicleLocationProvider.future);

      final newerTime = DateTime.parse('2026-11-23T10:05:00Z');
      final event = RealtimeEvent(
        type: RealtimeEventType.vehicleLocation,
        vehicleId: 'veh_9S0001',
        timestamp: newerTime,
        rawData: {
          'vehicleId': 'veh_9S0001',
          'latitude': 12.9730,
          'longitude': 77.5960,
          'description': 'Brigade Road',
          'vehicleState': 'DRIVING',
          'reportedAt': newerTime.toIso8601String(),
          'isCurrent': true,
        },
      );

      fakeRealtimeService.eventsController.add(event);
      await pumpEventQueue();

      final current = container.read(vehicleLocationProvider).value;
      expect(current?.latitude, 12.9730);
      expect(current?.description, 'Brigade Road');
    });

    test('vehicle.location event for another vehicle is ignored', () async {
      await container.read(vehicleLocationProvider.future);

      final event = RealtimeEvent(
        type: RealtimeEventType.vehicleLocation,
        vehicleId: 'veh_OTHER',
        timestamp: DateTime.parse('2026-11-23T10:05:00Z'),
        rawData: {
          'vehicleId': 'veh_OTHER',
          'latitude': 99.0,
          'longitude': 99.0,
        },
      );

      fakeRealtimeService.eventsController.add(event);
      await pumpEventQueue();

      final current = container.read(vehicleLocationProvider).value;
      expect(current, equals(initialLocation));
    });

    test('older reportedAt event is ignored', () async {
      await container.read(vehicleLocationProvider.future);

      final olderTime = DateTime.parse('2026-11-23T09:00:00Z');
      final event = RealtimeEvent(
        type: RealtimeEventType.vehicleLocation,
        vehicleId: 'veh_9S0001',
        timestamp: olderTime,
        rawData: {
          'vehicleId': 'veh_9S0001',
          'latitude': 1.0,
          'longitude': 1.0,
          'reportedAt': olderTime.toIso8601String(),
        },
      );

      fakeRealtimeService.eventsController.add(event);
      await pumpEventQueue();

      final current = container.read(vehicleLocationProvider).value;
      expect(current, equals(initialLocation));
    });

    test('realtime resync stream triggers re-fetch', () async {
      await container.read(vehicleLocationProvider.future);
      expect(fakeRepository.getLocationCalls, 1);

      fakeRealtimeService.resyncController.add(null);
      await pumpEventQueue();

      expect(fakeRepository.getLocationCalls, 2);
    });

    test('vehicle going offline immediately marks location not-current without waiting for re-fetch', () async {
      final statusNotifier = TestVehicleStatusNotifier(
        VehicleStatus(
          vehicleId: 'veh_9S0001',
          connectivity: ConnectivityStatus.online,
          vehicleState: VehicleState.driving,
          isStale: false,
          lastUpdatedAt: DateTime.now(),
        ),
      );

      final testContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          locationRepositoryProvider.overrideWithValue(fakeRepository),
          realtimeServiceProvider.overrideWithValue(fakeRealtimeService),
          vehicleStatusProvider.overrideWith(() => statusNotifier),
          authControllerProvider.overrideWith(
            () => TestAuthController(
              const AuthAuthenticated(
                UserSummary(userId: 'u1', name: 'Test User', email: 'test@example.com'),
              ),
            ),
          ),
        ],
      );

      await testContainer.read(vehicleLocationProvider.future);
      expect(testContainer.read(vehicleLocationProvider).value?.isCurrent, isTrue);

      // Transition to OFFLINE
      statusNotifier.setStatus(
        VehicleStatus(
          vehicleId: 'veh_9S0001',
          connectivity: ConnectivityStatus.offline,
          vehicleState: VehicleState.offline,
          isStale: true,
          lastUpdatedAt: DateTime.now(),
        ),
      );

      await pumpEventQueue();

      final loc = testContainer.read(vehicleLocationProvider).value;
      expect(loc?.isCurrent, isFalse);

      // Transition back ONLINE triggers re-fetch
      final initialCalls = fakeRepository.getLocationCalls;
      statusNotifier.setStatus(
        VehicleStatus(
          vehicleId: 'veh_9S0001',
          connectivity: ConnectivityStatus.online,
          vehicleState: VehicleState.parked,
          isStale: false,
          lastUpdatedAt: DateTime.now(),
        ),
      );
      await pumpEventQueue();

      expect(fakeRepository.getLocationCalls, greaterThan(initialCalls));

      testContainer.dispose();
    });

    test('refresh failure preserves previous data and exposes error separately', () async {
      await container.read(vehicleLocationProvider.future);

      fakeRepository.error = Exception('Network error');

      await container.read(vehicleLocationProvider.notifier).refresh();

      final state = container.read(vehicleLocationProvider);
      expect(state.hasValue, isTrue);
      expect(state.value, equals(initialLocation));

      final refreshError = container.read(vehicleLocationRefreshErrorProvider);
      expect(refreshError, isNotNull);
      expect(refreshError.toString(), contains('Network error'));
    });

    test('changing selected vehicle reloads location for new vehicle', () async {
      await container.read(vehicleLocationProvider.future);
      expect(fakeRepository.lastRequestedVehicleId, 'veh_9S0001');

      final newLoc = initialLocation.copyWith(vehicleId: 'veh_9S0002');
      fakeRepository.locationResult = newLoc;

      await container.read(selectedVehicleProvider.notifier).select('veh_9S0002');
      await Future<void>.delayed(Duration.zero);

      final loc = await container.read(vehicleLocationProvider.future);
      expect(loc?.vehicleId, 'veh_9S0002');
      expect(fakeRepository.lastRequestedVehicleId, 'veh_9S0002');
    });

    test('logout resets vehicleLocationProvider to null', () async {
      await container.read(vehicleLocationProvider.future);
      expect(container.read(vehicleLocationProvider).value, isNotNull);

      final authNotifier = container.read(authControllerProvider.notifier) as TestAuthController;
      authNotifier.emit(const AuthUnauthenticated(UnauthenticatedReason.none));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(vehicleLocationProvider).value, isNull);
    });
  });
}
