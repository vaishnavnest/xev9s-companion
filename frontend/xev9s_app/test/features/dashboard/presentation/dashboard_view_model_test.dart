import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('DashboardViewModel Tests', () {
    final baseStatus = VehicleStatus(
      vehicleId: 'veh_01',
      name: 'Primary Car',
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

    test('populates valid data correctly', () {
      final vm = DashboardViewModel(
        status: baseStatus,
        clock: DateTime.parse('2026-11-18T05:05:00.000Z'),
      );

      expect(vm.displayName, 'Primary Car');
      expect(vm.modelName, 'XEV 9S Performance');
      expect(vm.vehicleStateLabel, 'Parked');
      expect(vm.connectivityLabel, 'Online');
      expect(vm.batteryPercentDisplay, '75%');
      expect(vm.batteryRangeDisplay, '340.0 km');
      expect(vm.odometerDisplay, '15000.0 km');
      expect(vm.speedDisplay, '0 km/h');
      expect(vm.lockStateDisplay, 'Locked');
      expect(vm.preconditioningDisplay, 'Inactive');
      expect(vm.chargingStateDisplay, 'Not Connected');
      expect(vm.chargingPowerDisplay, '-');
      expect(vm.showStale, isFalse);
      expect(vm.isLiveValuesDimmed, isFalse);
      expect(vm.relativeLastUpdated, '5m ago');
    });

    test('null battery produces "-" and Unavailable', () {
      final status = baseStatus.copyWith(
        battery: const BatterySummary(percent: null),
      );
      final vm = DashboardViewModel(status: status);

      expect(vm.batteryPercentDisplay, '-');
      expect(vm.isBatteryUnavailable, isTrue);
      expect(vm.batteryLevelLabel, 'Unavailable');
      expect(vm.batteryProgressFraction, 0.0);
      expect(vm.batterySemanticsLabel, contains('Battery unavailable'));
    });

    test('null speed produces "-" and NEVER "0"', () {
      final status = baseStatus.copyWith(speedKmh: null);
      final vm = DashboardViewModel(status: status);

      expect(vm.speedDisplay, '-');
      expect(vm.speedDisplay, isNot('0'));
      expect(vm.speedDisplay, isNot('0 km/h'));
    });

    test('offline status activates showStale and dimmed flags', () {
      final offlineStatus = baseStatus.copyWith(
        connectivity: ConnectivityStatus.offline,
        vehicleState: VehicleState.offline,
        isStale: true,
        speedKmh: null,
      );
      final vm = DashboardViewModel(status: offlineStatus);

      expect(vm.isOffline, isTrue);
      expect(vm.showStale, isTrue);
      expect(vm.isLiveValuesDimmed, isTrue);
      expect(vm.speedDisplay, '-');
      expect(vm.staleBannerMessage, contains('Offline - showing last known data'));
    });
  });
}
