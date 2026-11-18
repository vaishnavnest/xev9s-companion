import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_status_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class FakeTokenStorage implements TokenStorage {
  String? accessToken = 'mock_jwt_token_123';
  String? refreshToken = 'mock_refresh_token_123';

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<void> saveAccessToken(String token) async => accessToken = token;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveRefreshToken(String token) async => refreshToken = token;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

class FakeVehicleStatusRepository implements VehicleStatusRepository {
  VehicleStatus? statusResult;
  Exception? error;
  int getStatusCalls = 0;
  String? lastRequestedVehicleId;

  @override
  Future<VehicleStatus> getStatus(String vehicleId) async {
    getStatusCalls++;
    lastRequestedVehicleId = vehicleId;
    if (error != null) throw error!;
    return statusResult!;
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
  RealtimeConnectionState get currentConnectionState => RealtimeConnectionState.connected;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VehicleStatusProvider Tests', () {
    late FakeVehicleStatusRepository repo;
    late FakeRealtimeService realtimeService;
    late SharedPreferences prefs;

    final initialStatus = VehicleStatus(
      vehicleId: 'veh_01',
      name: 'My XEV 9S',
      model: 'XEV 9S Performance',
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = FakeVehicleStatusRepository()..statusResult = initialStatus;
      realtimeService = FakeRealtimeService();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          vehicleStatusRepositoryProvider.overrideWithValue(repo),
          realtimeServiceProvider.overrideWithValue(realtimeService),
        ],
      );
      return container;
    }

    test('returns null when no vehicle is selected', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final status = await container.read(vehicleStatusProvider.future);
      expect(status, isNull);
      expect(repo.getStatusCalls, 0);
    });

    test('initial load fetches status from repository for selected vehicle', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_01');

      final status = await container.read(vehicleStatusProvider.future);

      expect(status?.vehicleId, 'veh_01');
      expect(status?.battery?.percent, 75.0);
      expect(repo.getStatusCalls, 1);
      expect(repo.lastRequestedVehicleId, 'veh_01');
    });

    test('refresh keeps previous data and updates to new result', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);

      final updatedStatus = initialStatus.copyWith(
        battery: const BatterySummary(percent: 78.0, level: BatteryLevel.normal),
      );
      repo.statusResult = updatedStatus;

      await container.read(vehicleStatusProvider.notifier).refresh();

      final state = container.read(vehicleStatusProvider);
      expect(state.asData?.value?.battery?.percent, 78.0);
      expect(repo.getStatusCalls, 2);
    });

    test('live vehicle.status event updates state if newer', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      container.listen(vehicleStatusProvider, (previous, next) {});

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);

      final liveEvent = RealtimeEvent(
        type: RealtimeEventType.vehicleStatus,
        vehicleId: 'veh_01',
        timestamp: DateTime.parse('2026-11-18T05:02:00.000Z'),
        rawData: {
          'vehicleId': 'veh_01',
          'vehicleState': 'DRIVING',
          'connectivity': 'ONLINE',
          'speedKmh': 60.0,
          'lastUpdatedAt': '2026-11-18T05:02:00.000Z',
        },
      );

      realtimeService.eventsController.add(liveEvent);
      await pumpEventQueue();

      final state = container.read(vehicleStatusProvider);
      expect(state.asData?.value?.speedKmh, 60.0);
      expect(state.asData?.value?.vehicleState, VehicleState.driving);
    });

    test('live event for another vehicle is ignored', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);

      final otherVehicleEvent = RealtimeEvent(
        type: RealtimeEventType.vehicleStatus,
        vehicleId: 'veh_999',
        timestamp: DateTime.parse('2026-11-18T05:05:00.000Z'),
        rawData: {
          'vehicleId': 'veh_999',
          'vehicleState': 'DRIVING',
          'connectivity': 'ONLINE',
          'speedKmh': 100.0,
          'lastUpdatedAt': '2026-11-18T05:05:00.000Z',
        },
      );

      realtimeService.eventsController.add(otherVehicleEvent);
      await pumpEventQueue();

      final state = container.read(vehicleStatusProvider);
      expect(state.asData?.value?.speedKmh, 0.0);
    });

    test('out-of-date event is ignored', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);

      final oldEvent = RealtimeEvent(
        type: RealtimeEventType.vehicleStatus,
        vehicleId: 'veh_01',
        timestamp: DateTime.parse('2026-11-18T04:00:00.000Z'),
        rawData: {
          'vehicleId': 'veh_01',
          'vehicleState': 'DRIVING',
          'connectivity': 'ONLINE',
          'speedKmh': 90.0,
          'lastUpdatedAt': '2026-11-18T04:00:00.000Z',
        },
      );

      realtimeService.eventsController.add(oldEvent);
      await pumpEventQueue();

      final state = container.read(vehicleStatusProvider);
      expect(state.asData?.value?.speedKmh, 0.0);
    });

    test('onResync signal triggers REST re-fetch', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      container.listen(vehicleStatusProvider, (previous, next) {});

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);
      expect(repo.getStatusCalls, 1);

      realtimeService.resyncController.add(null);
      await pumpEventQueue();

      expect(repo.getStatusCalls, 2);
    });

    test('refresh failure keeps old data and exposes error', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);

      repo.error = Exception('Network glitch');

      await container.read(vehicleStatusProvider.notifier).refresh();

      final state = container.read(vehicleStatusProvider);
      // Data is still retained!
      expect(state.hasValue, isTrue);
      expect(state.value?.battery?.percent, 75.0);

      // Error is exposed
      final err = container.read(vehicleStatusRefreshErrorProvider);
      expect(err, isNotNull);
    });

    test('selected vehicle change reloads status for new vehicle', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);
      expect(repo.lastRequestedVehicleId, 'veh_01');

      final v2Status = initialStatus.copyWith(
        vehicleId: 'veh_02',
        name: 'Second EV',
      );
      repo.statusResult = v2Status;

      container.read(selectedVehicleProvider.notifier).select('veh_02');
      final status = await container.read(vehicleStatusProvider.future);

      expect(status?.vehicleId, 'veh_02');
      expect(repo.lastRequestedVehicleId, 'veh_02');
    });

    test('clearing vehicle selection resets status to null', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(selectedVehicleProvider.notifier).select('veh_01');
      await container.read(vehicleStatusProvider.future);

      container.read(selectedVehicleProvider.notifier).clear();
      final status = await container.read(vehicleStatusProvider.future);

      expect(status, isNull);
    });
  });
}
