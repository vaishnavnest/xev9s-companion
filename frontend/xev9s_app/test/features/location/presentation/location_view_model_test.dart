import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/location/domain/vehicle_location.dart';
import 'package:xev9s_app/features/location/presentation/location_view_model.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/shared/widgets/status_chip.dart';

void main() {
  group('LocationViewModel Tests', () {
    final fixedTime = DateTime.parse('2026-11-23T10:00:00Z');

    test('description null or empty yields "Address unavailable"', () {
      final locNull = const VehicleLocation(
        vehicleId: 'veh_1',
        description: null,
      );
      final vmNull = LocationViewModel(location: locNull, now: fixedTime);
      expect(vmNull.displayAddress, 'Address unavailable');

      final locEmpty = const VehicleLocation(
        vehicleId: 'veh_1',
        description: '   ',
      );
      final vmEmpty = LocationViewModel(location: locEmpty, now: fixedTime);
      expect(vmEmpty.displayAddress, 'Address unavailable');

      final locValid = const VehicleLocation(
        vehicleId: 'veh_1',
        description: 'MG Road, Bengaluru',
      );
      final vmValid = LocationViewModel(location: locValid, now: fixedTime);
      expect(vmValid.displayAddress, 'MG Road, Bengaluru');
    });

    test('isCurrent=false displays last-known position and never uses "current" or "live"', () {
      final offlineLoc = VehicleLocation(
        vehicleId: 'veh_1',
        latitude: 12.9716,
        longitude: 77.5946,
        description: 'MG Road, Bengaluru',
        isCurrent: false,
        reportedAt: fixedTime.subtract(const Duration(minutes: 10)),
      );
      final vm = LocationViewModel(location: offlineLoc, now: fixedTime);

      expect(vm.headerTitle, 'Last known position');
      expect(vm.headerTitle.toLowerCase(), isNot(contains('current')));
      expect(vm.headerTitle.toLowerCase(), isNot(contains('live')));

      final offlineNotice = vm.offlineNoticeMessage;
      expect(offlineNotice, contains('Last known position - the vehicle is offline'));
      expect(offlineNotice.toLowerCase(), isNot(contains('current')));
      expect(offlineNotice.toLowerCase(), isNot(contains('live')));
      expect(offlineNotice, contains('10m ago'));
    });

    test('isCurrent=true displays "Current location"', () {
      final liveLoc = VehicleLocation(
        vehicleId: 'veh_1',
        latitude: 12.9716,
        longitude: 77.5946,
        description: 'MG Road, Bengaluru',
        isCurrent: true,
        reportedAt: fixedTime,
      );
      final vm = LocationViewModel(location: liveLoc, now: fixedTime);

      expect(vm.headerTitle, 'Current location');
    });

    test('coordinates formatting produces 5 decimal places or "-" when unavailable', () {
      final validLoc = const VehicleLocation(
        vehicleId: 'veh_1',
        latitude: 12.9716001,
        longitude: 77.5946002,
        isCurrent: true,
      );
      final vmValid = LocationViewModel(location: validLoc, now: fixedTime);
      expect(vmValid.formattedCoordinates, '12.97160, 77.59460');

      final noCoords = const VehicleLocation(
        vehicleId: 'veh_1',
        latitude: null,
        longitude: null,
      );
      final vmNoCoords = LocationViewModel(location: noCoords, now: fixedTime);
      expect(vmNoCoords.formattedCoordinates, '-');
    });

    test('relative time and tooltip formatting', () {
      final reported = fixedTime.subtract(const Duration(minutes: 5));
      final loc = VehicleLocation(
        vehicleId: 'veh_1',
        reportedAt: reported,
      );
      final vm = LocationViewModel(location: loc, now: fixedTime);

      expect(vm.relativeReportedTime, '5m ago');
      expect(vm.exactReportedTimeTooltip, isNotEmpty);
      expect(vm.exactReportedTimeTooltip, isNot(equals('Timestamp unavailable')));

      final nullLoc = const VehicleLocation(vehicleId: 'veh_1', reportedAt: null);
      final vmNull = LocationViewModel(location: nullLoc, now: fixedTime);
      expect(vmNull.relativeReportedTime, '-');
      expect(vmNull.exactReportedTimeTooltip, 'Timestamp unavailable');
    });

    test('vehicleStateLabel and vehicleStateType mappings', () {
      final states = [
        VehicleState.parked,
        VehicleState.driving,
        VehicleState.charging,
        VehicleState.offline,
        VehicleState.unknown,
      ];

      for (final state in states) {
        final loc = VehicleLocation(vehicleId: 'veh_1', vehicleState: state);
        final vm = LocationViewModel(location: loc, now: fixedTime);
        expect(vm.vehicleStateLabel, isNotEmpty);
        expect(vm.vehicleStateType, isA<ChipStatusType>());
      }
    });

    test('semanticsLabel produces readable screen-reader sentence', () {
      final loc = VehicleLocation(
        vehicleId: 'veh_1',
        latitude: 12.9716,
        longitude: 77.5946,
        description: 'MG Road, Bengaluru',
        vehicleState: VehicleState.parked,
        reportedAt: fixedTime.subtract(const Duration(minutes: 2)),
        isCurrent: true,
      );
      final vm = LocationViewModel(location: loc, now: fixedTime);

      expect(
        vm.semanticsLabel,
        'Vehicle parked at MG Road, Bengaluru, reported 2m ago',
      );
    });
  });
}
