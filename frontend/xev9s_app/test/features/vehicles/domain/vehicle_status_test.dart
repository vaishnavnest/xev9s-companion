import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('VehicleStatus Model Tests', () {
    final completeJson = {
      'vehicleId': 'veh_9S0001',
      'name': 'Asha\'s XEV 9S',
      'model': 'XEV 9S AWD Performance',
      'vehicleState': 'PARKED',
      'connectivity': 'ONLINE',
      'battery': {
        'percent': 64.0,
        'level': 'NORMAL',
      },
      'range': {
        'estimatedKm': 312.5,
      },
      'odometerKm': 12874.3,
      'speedKmh': 0.0,
      'lockState': 'LOCKED',
      'preconditioningState': 'INACTIVE',
      'charging': {
        'state': 'NOT_CONNECTED',
        'powerKw': null,
      },
      'lastUpdatedAt': '2026-11-18T04:30:00.000Z',
      'isStale': false,
    };

    test('fromJson parses complete JSON accurately', () {
      final status = VehicleStatus.fromJson(completeJson);

      expect(status.vehicleId, 'veh_9S0001');
      expect(status.name, 'Asha\'s XEV 9S');
      expect(status.model, 'XEV 9S AWD Performance');
      expect(status.vehicleState, VehicleState.parked);
      expect(status.connectivity, ConnectivityStatus.online);
      expect(status.battery?.percent, 64.0);
      expect(status.battery?.level, BatteryLevel.normal);
      expect(status.range?.estimatedKm, 312.5);
      expect(status.odometerKm, 12874.3);
      expect(status.speedKmh, 0.0);
      expect(status.lockState, LockState.locked);
      expect(status.preconditioningState, PreconditioningState.inactive);
      expect(status.charging?.state, ChargingState.notConnected);
      expect(status.charging?.powerKw, isNull);
      expect(status.lastUpdatedAt, DateTime.parse('2026-11-18T04:30:00.000Z'));
      expect(status.isStale, isFalse);
      expect(status.isOffline, isFalse);
      expect(status.showStale, isFalse);
    });

    test('fromJson parses offline variant with null speed/power and isStale=true', () {
      final offlineJson = {
        'vehicleId': 'veh_9S0001',
        'vehicleState': 'OFFLINE',
        'connectivity': 'OFFLINE',
        'battery': {'percent': 42.0},
        'odometerKm': 12874.3,
        'speedKmh': null,
        'charging': {'state': 'NOT_CONNECTED', 'powerKw': null},
        'lastUpdatedAt': '2026-11-18T02:00:00.000Z',
        'isStale': true,
      };

      final status = VehicleStatus.fromJson(offlineJson);

      expect(status.vehicleState, VehicleState.offline);
      expect(status.connectivity, ConnectivityStatus.offline);
      expect(status.speedKmh, isNull);
      expect(status.charging?.powerKw, isNull);
      expect(status.isStale, isTrue);
      expect(status.isOffline, isTrue);
      expect(status.showStale, isTrue);
    });

    test('unknown enum values fallback to unknown without throwing', () {
      final unknownEnumsJson = {
        'vehicleId': 'veh_9S0001',
        'vehicleState': 'FLYING_FUTURE_STATE',
        'connectivity': 'SATELLITE_MESH',
        'lockState': 'CYBER_LOCKED',
        'preconditioningState': 'TURBO_HEATING',
        'charging': {'state': 'SUPER_CHARGING_LEVEL_9'},
        'battery': {'level': 'SUPER_CRITICAL'},
        'lastUpdatedAt': '2026-11-18T04:30:00.000Z',
      };

      final status = VehicleStatus.fromJson(unknownEnumsJson);

      expect(status.vehicleState, VehicleState.unknown);
      expect(status.connectivity, ConnectivityStatus.unknown);
      expect(status.lockState, LockState.unknown);
      expect(status.preconditioningState, PreconditioningState.unknown);
      expect(status.charging?.state, ChargingState.unknown);
      expect(status.battery?.level, BatteryLevel.unknown);
    });

    test('missing required fields throw FormatException', () {
      expect(
        () => VehicleStatus.fromJson(Map.from(completeJson)..remove('vehicleId')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VehicleStatus.fromJson(Map.from(completeJson)..remove('vehicleState')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VehicleStatus.fromJson(Map.from(completeJson)..remove('connectivity')),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VehicleStatus.fromJson(Map.from(completeJson)..remove('lastUpdatedAt')),
        throwsA(isA<FormatException>()),
      );
    });

    group('merge()', () {
      final initial = VehicleStatus.fromJson(completeJson);

      test('newer replaces older status', () {
        final newer = initial.copyWith(
          speedKmh: 45.0,
          vehicleState: VehicleState.driving,
          lastUpdatedAt: DateTime.parse('2026-11-18T04:31:00.000Z'),
        );

        final merged = initial.merge(newer);
        expect(merged.speedKmh, 45.0);
        expect(merged.vehicleState, VehicleState.driving);
        expect(merged.lastUpdatedAt, DateTime.parse('2026-11-18T04:31:00.000Z'));
      });

      test('older or out-of-date event is ignored', () {
        final older = initial.copyWith(
          speedKmh: 90.0,
          lastUpdatedAt: DateTime.parse('2026-11-18T04:20:00.000Z'),
        );

        final merged = initial.merge(older);
        expect(merged.speedKmh, 0.0);
        expect(merged.lastUpdatedAt, initial.lastUpdatedAt);
      });
    });

    group('effectiveBatteryLevel', () {
      test('uses server level when available and recognized', () {
        final status = VehicleStatus.fromJson(Map.from(completeJson)
          ..['battery'] = {'percent': 10.0, 'level': 'NORMAL'});
        expect(status.effectiveBatteryLevel, BatteryLevel.normal);
      });

      test('derives unavailable when battery or percent is null', () {
        final statusNoBattery = VehicleStatus.fromJson(Map.from(completeJson)..remove('battery'));
        expect(statusNoBattery.effectiveBatteryLevel, BatteryLevel.unavailable);

        final statusNullPct = VehicleStatus.fromJson(Map.from(completeJson)
          ..['battery'] = {'percent': null});
        expect(statusNullPct.effectiveBatteryLevel, BatteryLevel.unavailable);
      });

      test('derives warning when percent <= 20% and server level unknown or missing', () {
        final status20 = VehicleStatus.fromJson(Map.from(completeJson)
          ..['battery'] = {'percent': 20.0});
        expect(status20.effectiveBatteryLevel, BatteryLevel.warning);

        final status15 = VehicleStatus.fromJson(Map.from(completeJson)
          ..['battery'] = {'percent': 15.0});
        expect(status15.effectiveBatteryLevel, BatteryLevel.warning);
      });

      test('derives normal when percent > 20% and server level unknown or missing', () {
        final status21 = VehicleStatus.fromJson(Map.from(completeJson)
          ..['battery'] = {'percent': 21.0});
        expect(status21.effectiveBatteryLevel, BatteryLevel.normal);

        final status80 = VehicleStatus.fromJson(Map.from(completeJson)
          ..['battery'] = {'percent': 80.0});
        expect(status80.effectiveBatteryLevel, BatteryLevel.normal);
      });
    });
  });
}
