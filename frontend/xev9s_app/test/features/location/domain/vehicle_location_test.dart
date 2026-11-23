import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/location/domain/vehicle_location.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('VehicleLocation Domain Tests', () {
    test('VehicleLocation.fromJson parses complete payload correctly', () {
      final json = {
        'vehicleId': 'veh_9S0001',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'description': 'MG Road, Bengaluru',
        'vehicleState': 'DRIVING',
        'reportedAt': '2026-11-23T09:30:00Z',
        'isCurrent': true,
      };

      final location = VehicleLocation.fromJson(json);

      expect(location.vehicleId, 'veh_9S0001');
      expect(location.latitude, 12.9716);
      expect(location.longitude, 77.5946);
      expect(location.description, 'MG Road, Bengaluru');
      expect(location.vehicleState, VehicleState.driving);
      expect(location.reportedAt, DateTime.parse('2026-11-23T09:30:00Z'));
      expect(location.isCurrent, isTrue);
      expect(location.hasCoordinates, isTrue);
    });

    test('VehicleLocation.fromJson handles null coordinates properly', () {
      final json = {
        'vehicleId': 'veh_9S0001',
        'latitude': null,
        'longitude': null,
        'description': null,
        'vehicleState': 'PARKED',
        'reportedAt': null,
        'isCurrent': false,
      };

      final location = VehicleLocation.fromJson(json);

      expect(location.latitude, isNull);
      expect(location.longitude, isNull);
      expect(location.hasCoordinates, isFalse);
      expect(location.description, isNull);
      expect(location.reportedAt, isNull);
      expect(location.isCurrent, isFalse);
    });

    test('Null is never turned into 0.0 coordinates', () {
      final json = {
        'vehicleId': 'veh_9S0001',
        'latitude': null,
        'longitude': null,
        'vehicleState': 'PARKED',
        'isCurrent': false,
      };

      final location = VehicleLocation.fromJson(json);

      expect(location.latitude, isNull);
      expect(location.longitude, isNull);
      expect(location.latitude, isNot(0.0));
      expect(location.longitude, isNot(0.0));
      expect(location.hasCoordinates, isFalse);
    });

    test('Explicit 0.0, 0.0 sent as numbers is treated as valid coordinates', () {
      final json = {
        'vehicleId': 'veh_9S0001',
        'latitude': 0.0,
        'longitude': 0.0,
        'description': 'Null Island',
        'vehicleState': 'PARKED',
        'isCurrent': true,
      };

      final location = VehicleLocation.fromJson(json);

      expect(location.latitude, 0.0);
      expect(location.longitude, 0.0);
      expect(location.hasCoordinates, isTrue);
    });

    test('Out-of-range coordinates count as NO coordinates and do not crash', () {
      // Latitude > 90
      final loc1 = VehicleLocation.fromJson({
        'vehicleId': 'veh_9S0001',
        'latitude': 91.5,
        'longitude': 77.0,
        'isCurrent': true,
      });
      expect(loc1.hasCoordinates, isFalse);

      // Latitude < -90
      final loc2 = VehicleLocation.fromJson({
        'vehicleId': 'veh_9S0001',
        'latitude': -95.0,
        'longitude': 77.0,
        'isCurrent': true,
      });
      expect(loc2.hasCoordinates, isFalse);

      // Longitude > 180
      final loc3 = VehicleLocation.fromJson({
        'vehicleId': 'veh_9S0001',
        'latitude': 12.0,
        'longitude': 185.0,
        'isCurrent': true,
      });
      expect(loc3.hasCoordinates, isFalse);

      // Longitude < -180
      final loc4 = VehicleLocation.fromJson({
        'vehicleId': 'veh_9S0001',
        'latitude': 12.0,
        'longitude': -185.0,
        'isCurrent': true,
      });
      expect(loc4.hasCoordinates, isFalse);

      // One coordinate null while other valid
      final loc5 = VehicleLocation.fromJson({
        'vehicleId': 'veh_9S0001',
        'latitude': 12.0,
        'longitude': null,
        'isCurrent': true,
      });
      expect(loc5.hasCoordinates, isFalse);
    });

    test('Unknown vehicleState string parses tolerantly to VehicleState.unknown', () {
      final json = {
        'vehicleId': 'veh_9S0001',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'vehicleState': 'HOVERING',
        'isCurrent': true,
      };

      final location = VehicleLocation.fromJson(json);
      expect(location.vehicleState, VehicleState.unknown);
    });

    test('Missing required vehicleId throws FormatException', () {
      expect(
        () => VehicleLocation.fromJson({
          'latitude': 12.9716,
          'longitude': 77.5946,
          'isCurrent': true,
        }),
        throwsFormatException,
      );

      expect(
        () => VehicleLocation.fromJson({
          'vehicleId': '',
          'latitude': 12.9716,
          'longitude': 77.5946,
        }),
        throwsFormatException,
      );
    });

    test('copyWith and toJson work as expected', () {
      final loc = const VehicleLocation(
        vehicleId: 'veh_1',
        latitude: 10.0,
        longitude: 20.0,
        isCurrent: true,
      );

      final updated = loc.copyWith(isCurrent: false, description: 'Updated');
      expect(updated.isCurrent, isFalse);
      expect(updated.description, 'Updated');
      expect(updated.latitude, 10.0);
      expect(updated.vehicleId, 'veh_1');

      final json = updated.toJson();
      expect(json['vehicleId'], 'veh_1');
      expect(json['isCurrent'], isFalse);
      expect(json['description'], 'Updated');
    });

    test('Equality and props comparison', () {
      final loc1 = const VehicleLocation(
        vehicleId: 'veh_1',
        latitude: 10.0,
        longitude: 20.0,
        isCurrent: true,
      );
      final loc2 = const VehicleLocation(
        vehicleId: 'veh_1',
        latitude: 10.0,
        longitude: 20.0,
        isCurrent: true,
      );
      final loc3 = const VehicleLocation(
        vehicleId: 'veh_2',
        latitude: 10.0,
        longitude: 20.0,
        isCurrent: true,
      );

      expect(loc1, equals(loc2));
      expect(loc1, isNot(equals(loc3)));
    });
  });
}
