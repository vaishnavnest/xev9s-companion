import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('RealtimeEvent Model Tests', () {
    test('parses vehicle.status event', () {
      final json = {
        'event': 'vehicle.status',
        'vehicleId': 'veh_9S0001',
        'timestamp': '2026-11-18T05:00:00.000Z',
        'data': {
          'vehicleId': 'veh_9S0001',
          'vehicleState': 'DRIVING',
          'connectivity': 'ONLINE',
          'speedKmh': 55.4,
          'lastUpdatedAt': '2026-11-18T05:00:00.000Z',
        },
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.vehicleStatus);
      expect(event.vehicleId, 'veh_9S0001');

      final status = event.asVehicleStatus();
      expect(status, isNotNull);
      expect(status!.vehicleState, VehicleState.driving);
      expect(status.speedKmh, 55.4);
    });

    test('parses vehicle.location event', () {
      final json = {
        'event': 'vehicle.location',
        'vehicleId': 'veh_9S0001',
        'timestamp': '2026-11-18T05:00:00.000Z',
        'data': {
          'latitude': 12.9716,
          'longitude': 77.5946,
          'isCurrent': true,
        },
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.vehicleLocation);
      expect(event.rawData?['latitude'], 12.9716);
    });

    test('parses charging.updated event', () {
      final json = {
        'event': 'charging.updated',
        'vehicleId': 'veh_9S0001',
        'timestamp': '2026-11-18T05:00:00.000Z',
        'data': {
          'state': 'CHARGING',
          'powerKw': 22.0,
          'batteryPercent': 78.5,
        },
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.chargingUpdated);

      final charging = event.asChargingOverview();
      expect(charging, isNotNull);
      expect(charging!.state, ChargingState.charging);
      expect(charging.powerKw, 22.0);
      expect(charging.batteryPercent, 78.5);
    });

    test('parses command.updated event', () {
      final json = {
        'event': 'command.updated',
        'vehicleId': 'veh_9S0001',
        'timestamp': '2026-11-18T05:00:00.000Z',
        'data': {
          'commandId': 'cmd_123',
          'status': 'SUCCEEDED',
        },
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.commandUpdated);
    });

    test('parses flat backend command_updated event', () {
      final json = {
        'event': 'command_updated',
        'command_id': 'cmd_123',
        'vehicle_id': 'XEV-DEMO-001',
        'operation': 'lock',
        'status': 'succeeded',
        'requested_at': '2026-11-24T12:00:00Z',
        'completed_at': '2026-11-24T12:00:03Z',
        'failure_reason': null,
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.commandUpdated);
      expect(event.vehicleId, 'XEV-DEMO-001');
      expect(event.rawData, isNotNull);
      expect(event.rawData?['command_id'], 'cmd_123');
    });

    test('parses notification.created event', () {
      final json = {
        'event': 'notification.created',
        'vehicleId': 'veh_9S0001',
        'timestamp': '2026-11-18T05:00:00.000Z',
        'data': {
          'notificationId': 'notif_001',
          'title': 'Charging Completed',
        },
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.notificationCreated);
    });

    test('parses connectivity.changed event', () {
      final json = {
        'event': 'connectivity.changed',
        'vehicleId': 'veh_9S0001',
        'timestamp': '2026-11-18T05:00:00.000Z',
        'data': {
          'status': 'OFFLINE',
          'lastCommunicationAt': '2026-11-18T04:55:00.000Z',
        },
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.connectivityChanged);

      final conn = event.asConnectivity();
      expect(conn, isNotNull);
      expect(conn!.status, ConnectivityStatus.offline);
      expect(conn.lastCommunicationAt, DateTime.parse('2026-11-18T04:55:00.000Z'));
    });

    test('unknown event maps to RealtimeEventType.unknown without throwing', () {
      final json = {
        'event': 'unknown.future.event',
        'vehicleId': 'veh_9S0001',
        'timestamp': '2026-11-18T05:00:00.000Z',
        'data': {'foo': 'bar'},
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.type, RealtimeEventType.unknown);
      expect(event.asVehicleStatus(), isNull);
    });

    test('malformed JSON data handled gracefully returning null in typed accessors', () {
      final json = {
        'event': 'vehicle.status',
        'vehicleId': 'veh_9S0001',
        'timestamp': 'invalid-timestamp-string',
        'data': 'not-a-map',
      };

      final event = RealtimeEvent.fromJson(json);
      expect(event.asVehicleStatus(), isNull);
      expect(event.asChargingOverview(), isNull);
      expect(event.asConnectivity(), isNull);
    });
  });
}
