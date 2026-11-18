import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_connectivity.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';

void main() {
  group('AssociationStatus', () {
    test('fromString safely maps known and unknown values', () {
      expect(AssociationStatus.fromString('ASSOCIATED'), equals(AssociationStatus.associated));
      expect(AssociationStatus.fromString('associated'), equals(AssociationStatus.associated));
      expect(AssociationStatus.fromString('PENDING'), equals(AssociationStatus.pending));
      expect(AssociationStatus.fromString(null), equals(AssociationStatus.unknown));
      expect(AssociationStatus.fromString(''), equals(AssociationStatus.unknown));
      expect(AssociationStatus.fromString('FUTURE_STATUS'), equals(AssociationStatus.unknown));
    });
  });

  group('VehicleConnectivity', () {
    test('fromString safely maps known and unknown values', () {
      expect(VehicleConnectivity.fromString('ONLINE'), equals(VehicleConnectivity.online));
      expect(VehicleConnectivity.fromString('offline'), equals(VehicleConnectivity.offline));
      expect(VehicleConnectivity.fromString(null), equals(VehicleConnectivity.unknown));
      expect(VehicleConnectivity.fromString(''), equals(VehicleConnectivity.unknown));
      expect(VehicleConnectivity.fromString('5G_STANDBY'), equals(VehicleConnectivity.unknown));
    });
  });

  group('VehicleSummary', () {
    test('fromJson parses complete valid JSON with connectivity', () {
      final json = {
        'vehicleId': 'veh_9S0001',
        'name': 'My Beast',
        'model': 'XEV 9S Performance AWD',
        'identifier': 'XEV9S-2026-0001',
        'associationStatus': 'ASSOCIATED',
        'connectivity': 'ONLINE',
      };

      final vehicle = VehicleSummary.fromJson(json);

      expect(vehicle.vehicleId, equals('veh_9S0001'));
      expect(vehicle.name, equals('My Beast'));
      expect(vehicle.displayName, equals('My Beast'));
      expect(vehicle.model, equals('XEV 9S Performance AWD'));
      expect(vehicle.identifier, equals('XEV9S-2026-0001'));
      expect(vehicle.associationStatus, equals(AssociationStatus.associated));
      expect(vehicle.connectivity, equals(VehicleConnectivity.online));
      expect(vehicle.isAssociated, isTrue);
      expect(vehicle.isPending, isFalse);
      expect(vehicle.isOnline, isTrue);
      expect(vehicle.isOffline, isFalse);
      expect(vehicle.toJson(), equals(json));
    });

    test('displayName falls back to model if name is empty', () {
      final vehicle = VehicleSummary(
        vehicleId: 'v1',
        name: '   ',
        model: 'XEV 9S Alpha',
        identifier: 'ID1',
        associationStatus: AssociationStatus.associated,
      );
      expect(vehicle.displayName, equals('XEV 9S Alpha'));
    });

    test('fromJson handles optional connectivity field when absent', () {
      final json = {
        'vehicleId': 'veh_9S0002',
        'name': 'Pending Car',
        'model': 'XEV 9S Base',
        'identifier': 'XEV9S-2026-0002',
        'associationStatus': 'PENDING',
      };

      final vehicle = VehicleSummary.fromJson(json);

      expect(vehicle.vehicleId, equals('veh_9S0002'));
      expect(vehicle.connectivity, isNull);
      expect(vehicle.isPending, isTrue);
      expect(vehicle.isAssociated, isFalse);
    });

    test('fromJson throws FormatException on missing required fields', () {
      expect(
        () => VehicleSummary.fromJson({
          'name': 'Test',
          'model': 'Model',
          'identifier': 'ID',
          'associationStatus': 'ASSOCIATED',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VehicleSummary.fromJson({
          'vehicleId': 'v1',
          'name': 'Test',
          'identifier': 'ID',
          'associationStatus': 'ASSOCIATED',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VehicleSummary.fromJson({
          'vehicleId': 'v1',
          'name': 'Test',
          'model': 'Model',
          'associationStatus': 'ASSOCIATED',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VehicleSummary.fromJson({
          'vehicleId': 'v1',
          'name': 'Test',
          'model': 'Model',
          'identifier': 'ID',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
