import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/features/charging/data/charging_repository.dart';
import 'package:xev9s_app/features/charging/domain/charging_overview.dart';
import 'package:xev9s_app/features/charging/presentation/providers/charging_overview_provider.dart';
import 'package:xev9s_app/features/charging/presentation/providers/charging_view_provider.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_status_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockChargingRepository extends Mock implements ChargingRepository {}
class MockVehicleStatusRepository extends Mock implements VehicleStatusRepository {}

void main() {
  late MockChargingRepository mockChargingRepo;
  late MockVehicleStatusRepository mockStatusRepo;
  late StreamController<RealtimeEvent> eventController;
  late StreamController<void> resyncController;

  setUp(() {
    mockChargingRepo = MockChargingRepository();
    mockStatusRepo = MockVehicleStatusRepository();
    eventController = StreamController<RealtimeEvent>.broadcast();
    resyncController = StreamController<void>.broadcast();
  });

  tearDown(() {
    eventController.close();
    resyncController.close();
  });

  test('Consistency test: charging view-model and dashboard show the EXACT same state and power after charging.updated event', () async {
    final now = DateTime.now();

    final initialStatus = VehicleStatus(
      vehicleId: 'veh_9S0001',
      name: 'Test XEV',
      model: 'XEV 9S',
      vehicleState: VehicleState.parked,
      connectivity: ConnectivityStatus.online,
      battery: const BatterySummary(percent: 50.0, level: BatteryLevel.normal),
      range: const RangeSummary(estimatedKm: 240),
      charging: const ChargingSummary(
        state: ChargingState.connected,
        powerKw: 0.0,
      ),
      lastUpdatedAt: now.subtract(const Duration(minutes: 5)),
    );

    final initialOverview = ChargingOverview(
      state: ChargingState.connected,
      batteryPercent: 50.0,
      powerKw: 0.0,
      targetPercent: 80,
    );

    when(() => mockStatusRepo.getStatus('veh_9S0001'))
        .thenAnswer((_) async => initialStatus);
    when(() => mockChargingRepo.getOverview('veh_9S0001'))
        .thenAnswer((_) async => initialOverview);

    final container = ProviderContainer(
      overrides: [
        chargingRepositoryProvider.overrideWithValue(mockChargingRepo),
        vehicleStatusRepositoryProvider.overrideWithValue(mockStatusRepo),
        realtimeEventsProvider.overrideWith((ref) => eventController.stream),
        realtimeResyncProvider.overrideWith((ref) => resyncController.stream),
        selectedVehicleProvider.overrideWith(() => _ConsistencyTestVehicleNotifier('veh_9S0001')),
      ],
    );
    addTearDown(container.dispose);
    container.listen(chargingOverviewProvider, (previous, next) {});
    container.listen(vehicleStatusProvider, (previous, next) {});
    container.listen(chargingViewProvider, (previous, next) {});

    // Initial load
    await container.read(chargingOverviewProvider.future);
    await container.read(vehicleStatusProvider.future);

    // Dispatch charging.updated event
    final eventTime = DateTime.now();
    final event = RealtimeEvent(
      type: RealtimeEventType.chargingUpdated,
      vehicleId: 'veh_9S0001',
      timestamp: eventTime,
      rawData: {
        'state': 'CHARGING',
        'batteryPercent': 52.0,
        'powerKw': 11.2,
        'targetPercent': 80,
      },
    );
    eventController.add(event);
    await pumpEventQueue();

    // Dashboard state
    final dashboardStatus = container.read(vehicleStatusProvider).value;
    final chargingView = container.read(chargingViewProvider).value;

    expect(dashboardStatus, isNotNull);
    expect(chargingView, isNotNull);

    // Both screens must never disagree on live state, powerKw, and batteryPercent
    expect(dashboardStatus!.charging?.state, ChargingState.charging);
    expect(chargingView!.state, ChargingState.charging);
    expect(dashboardStatus.charging?.state, equals(chargingView.state));

    expect(dashboardStatus.charging?.powerKw, 11.2);
    expect(chargingView.powerKw, 11.2);
    expect(dashboardStatus.charging?.powerKw, equals(chargingView.powerKw));

    expect(dashboardStatus.battery?.percent, 52.0);
    expect(chargingView.batteryPercent, 52.0);
    expect(dashboardStatus.battery?.percent, equals(chargingView.batteryPercent));

    // When status changes to DRIVING, charging state MUST automatically transition to notConnected and power must be null
    final drivingTime = eventTime.add(const Duration(seconds: 2));
    final drivingEvent = RealtimeEvent(
      type: RealtimeEventType.vehicleStatus,
      vehicleId: 'veh_9S0001',
      timestamp: drivingTime,
      rawData: {
        'vehicleId': 'veh_9S0001',
        'vehicleState': 'DRIVING',
        'connectivity': 'ONLINE',
        'speedKmh': 45.0,
        'battery': {'percent': 52.0, 'level': 'NORMAL'},
        'lastUpdatedAt': drivingTime.toUtc().toIso8601String(),
      },
    );
    eventController.add(drivingEvent);
    await pumpEventQueue();

    final drivingChargingView = container.read(chargingViewProvider).value;
    expect(drivingChargingView, isNotNull);
    expect(drivingChargingView!.state, ChargingState.notConnected);
    expect(drivingChargingView.powerKw, isNull);
    expect(drivingChargingView.sessionDurationSeconds, isNull);
  });
}

class _ConsistencyTestVehicleNotifier extends SelectedVehicleNotifier {
  _ConsistencyTestVehicleNotifier(this.initialId);
  final String? initialId;

  @override
  String? build() => initialId;
}
