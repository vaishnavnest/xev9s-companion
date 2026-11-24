import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/features/charging/data/charging_repository.dart';
import 'package:xev9s_app/features/charging/domain/charging_overview.dart';
import 'package:xev9s_app/features/charging/presentation/providers/charging_overview_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockChargingRepository extends Mock implements ChargingRepository {}

void main() {
  late MockChargingRepository mockRepository;
  late StreamController<RealtimeEvent> eventController;
  late StreamController<void> resyncController;

  setUp(() {
    mockRepository = MockChargingRepository();
    eventController = StreamController<RealtimeEvent>.broadcast();
    resyncController = StreamController<void>.broadcast();
  });

  tearDown(() {
    eventController.close();
    resyncController.close();
  });

  ProviderContainer createContainer({String? vehicleId = 'veh_9S0001'}) {
    final container = ProviderContainer(
      overrides: [
        chargingRepositoryProvider.overrideWithValue(mockRepository),
        realtimeEventsProvider.overrideWith((ref) => eventController.stream),
        realtimeResyncProvider.overrideWith((ref) => resyncController.stream),
        selectedVehicleProvider.overrideWith(() => _TestSelectedVehicleNotifier(vehicleId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ChargingOverviewProvider', () {
    test('build loads overview and refresh preserves data', () async {
      const overview = ChargingOverview(
        state: ChargingState.charging,
        batteryPercent: 64.0,
      );

      when(() => mockRepository.getOverview('veh_9S0001'))
          .thenAnswer((_) async => overview);

      final container = createContainer();
      final first = await container.read(chargingOverviewProvider.future);
      expect(first?.state, ChargingState.charging);
      expect(first?.batteryPercent, 64.0);

      // Refresh
      final refreshOverview = const ChargingOverview(
        state: ChargingState.charging,
        batteryPercent: 66.0,
      );
      when(() => mockRepository.getOverview('veh_9S0001'))
          .thenAnswer((_) async => refreshOverview);

      await container.read(chargingOverviewProvider.notifier).refresh();
      expect(container.read(chargingOverviewProvider).value?.batteryPercent, 66.0);
    });

    test('setTarget updates from server response and surfaces 422 error', () async {
      const initial = ChargingOverview(
        state: ChargingState.connected,
        targetPercent: 80,
      );
      const updated = ChargingOverview(
        state: ChargingState.connected,
        targetPercent: 90,
      );

      when(() => mockRepository.getOverview('veh_9S0001'))
          .thenAnswer((_) async => initial);
      when(() => mockRepository.setTarget('veh_9S0001', 90))
          .thenAnswer((_) async => updated);

      final container = createContainer();
      container.listen(chargingOverviewProvider, (previous, next) {});
      await container.read(chargingOverviewProvider.future);

      final result =
          await container.read(chargingOverviewProvider.notifier).setTarget(90);
      expect(result.targetPercent, 90);
      expect(container.read(chargingOverviewProvider).value?.targetPercent, 90);

      // 422 error
      when(() => mockRepository.setTarget('veh_9S0001', 10))
          .thenThrow(const AppError(
        code: ApiErrorCode.chargingTargetNotApplicable,
        message: 'Charging target cannot be set below minimum',
      ));

      expect(
        () => container.read(chargingOverviewProvider.notifier).setTarget(10),
        throwsA(isA<AppError>()),
      );
    });

    test('merges charging.updated event for active vehicle and ignores other vehicle', () async {
      const initial = ChargingOverview(
        state: ChargingState.connected,
        batteryPercent: 50.0,
      );

      when(() => mockRepository.getOverview('veh_9S0001'))
          .thenAnswer((_) async => initial);

      final container = createContainer();
      container.listen(chargingOverviewProvider, (previous, next) {});
      await container.read(chargingOverviewProvider.future);

      // Event for other vehicle -> ignored
      eventController.add(RealtimeEvent(
        type: RealtimeEventType.chargingUpdated,
        vehicleId: 'veh_OTHER',
        timestamp: DateTime.now(),
        rawData: {'state': 'CHARGING', 'batteryPercent': 99.0},
      ));
      await pumpEventQueue();
      expect(container.read(chargingOverviewProvider).value?.batteryPercent, 50.0);

      // Event for active vehicle -> merged
      eventController.add(RealtimeEvent(
        type: RealtimeEventType.chargingUpdated,
        vehicleId: 'veh_9S0001',
        timestamp: DateTime.now(),
        rawData: {'state': 'CHARGING', 'batteryPercent': 55.0},
      ));
      await pumpEventQueue();
      expect(container.read(chargingOverviewProvider).value?.batteryPercent, 55.0);
      expect(container.read(chargingOverviewProvider).value?.state, ChargingState.charging);
    });

    test('resync signal triggers refresh', () async {
      const initial = ChargingOverview(
        state: ChargingState.connected,
        batteryPercent: 50.0,
      );
      const resynced = ChargingOverview(
        state: ChargingState.charging,
        batteryPercent: 52.0,
      );

      when(() => mockRepository.getOverview('veh_9S0001'))
          .thenAnswer((_) async => initial);

      final container = createContainer();
      container.listen(chargingOverviewProvider, (previous, next) {});
      await container.read(chargingOverviewProvider.future);

      when(() => mockRepository.getOverview('veh_9S0001'))
          .thenAnswer((_) async => resynced);

      resyncController.add(null);
      await pumpEventQueue();
      expect(container.read(chargingOverviewProvider).value?.batteryPercent, 52.0);
    });
  });
}

class _TestSelectedVehicleNotifier extends SelectedVehicleNotifier {
  _TestSelectedVehicleNotifier(this.initialId);
  final String? initialId;

  @override
  String? build() => initialId;
}
