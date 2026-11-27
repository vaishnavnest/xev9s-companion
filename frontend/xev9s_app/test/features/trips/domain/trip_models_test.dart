import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/trips/domain/route_point.dart';
import 'package:xev9s_app/features/trips/domain/trip.dart';
import 'package:xev9s_app/features/trips/domain/trip_detail.dart';
import 'package:xev9s_app/features/trips/domain/trip_location.dart';
import 'package:xev9s_app/features/trips/domain/trip_status.dart';

void main() {
  group('TripLocation', () {
    test('hasCoordinates validates bounds and rejects null or out-of-range', () {
      expect(
        const TripLocation(latitude: 12.97, longitude: 77.59).hasCoordinates,
        isTrue,
      );
      expect(const TripLocation(latitude: null, longitude: 77.59).hasCoordinates, isFalse);
      expect(const TripLocation(latitude: 95.0, longitude: 77.59).hasCoordinates, isFalse);
      expect(const TripLocation(latitude: 12.97, longitude: 185.0).hasCoordinates, isFalse);
    });
  });

  group('Trip.fromJson', () {
    test('parses complete snake_case completed trip', () {
      final trip = Trip.fromJson({
        'trip_id': 'trp_0105',
        'status': 'completed',
        'started_at': '2026-11-24T09:00:00Z',
        'ended_at': '2026-11-24T09:34:00Z',
        'start_location': {
          'latitude': 12.9716,
          'longitude': 77.5946,
          'description': 'MG Road, Bengaluru',
        },
        'end_location': {
          'latitude': 12.9759,
          'longitude': 77.6010,
          'description': 'Trinity Circle',
        },
        'distance_km': 14.8,
        'duration_seconds': 2040,
        'energy_consumed_kwh': 2.6,
      });

      expect(trip.tripId, 'trp_0105');
      expect(trip.status, TripStatus.completed);
      expect(trip.isOngoing, isFalse);
      expect(trip.distanceKm, 14.8);
      expect(trip.durationSeconds, 2040);
      expect(trip.energyConsumedKwh, 2.6);
      expect(trip.startLocation.description, 'MG Road, Bengaluru');
      expect(trip.endLocation?.description, 'Trinity Circle');
    });

    test('parses ongoing trip with null end fields without turning null into 0', () {
      final trip = Trip.fromJson({
        'tripId': 'trp_ongoing',
        'status': 'ONGOING',
        'startedAt': '2026-11-24T09:00:00Z',
        'endedAt': null,
        'startLocation': {'latitude': 12.97, 'longitude': 77.59},
        'endLocation': null,
        'distanceKm': null,
        'durationSeconds': null,
        'energyConsumedKwh': null,
      });

      expect(trip.isOngoing, isTrue);
      expect(trip.endedAt, isNull);
      expect(trip.endLocation, isNull);
      expect(trip.distanceKm, isNull);
      expect(trip.durationSeconds, isNull);
      expect(trip.energyConsumedKwh, isNull);
      expect(
        trip.elapsedAt(DateTime.utc(2026, 11, 24, 9, 12, 30)),
        const Duration(minutes: 12, seconds: 30),
      );
    });

    test('preserves explicit 0.0 distance', () {
      final trip = Trip.fromJson({
        'trip_id': 'trp_zero',
        'status': 'completed',
        'started_at': '2026-11-24T09:00:00Z',
        'start_location': {},
        'distance_km': 0.0,
      });
      expect(trip.distanceKm, 0.0);
    });

    test('maps unknown status safely', () {
      final trip = Trip.fromJson({
        'trip_id': 'trp_u',
        'status': 'PAUSED',
        'started_at': '2026-11-24T09:00:00Z',
      });
      expect(trip.status, TripStatus.unknown);
      expect(trip.status.toApi(), isNull);
    });

    test('throws FormatException when required fields are missing', () {
      expect(
        () => Trip.fromJson({'status': 'completed', 'started_at': '2026-11-24T09:00:00Z'}),
        throwsFormatException,
      );
      expect(
        () => Trip.fromJson({'trip_id': 't1', 'started_at': '2026-11-24T09:00:00Z'}),
        throwsFormatException,
      );
      expect(
        () => Trip.fromJson({'trip_id': 't1', 'status': 'completed'}),
        throwsFormatException,
      );
    });
  });

  group('TripDetail.fromJson', () {
    test('parses route, battery range, drops invalid points, and sorts by timestamp', () {
      final detail = TripDetail.fromJson({
        'trip_id': 'trp_0105',
        'status': 'completed',
        'started_at': '2026-11-24T09:00:00Z',
        'start_location': {'latitude': 12.97, 'longitude': 77.59},
        'average_speed_kmh': 32.5,
        'battery': {'start_percent': 72.0, 'end_percent': 68.0},
        'route': [
          {'latitude': 12.98, 'longitude': 77.60, 'timestamp': '2026-11-24T09:10:00Z'},
          {'latitude': 999.0, 'longitude': 77.59, 'timestamp': '2026-11-24T09:05:00Z'}, // invalid lat
          {'latitude': 12.97, 'longitude': null}, // missing lng
          {'latitude': 12.97, 'longitude': 77.59, 'timestamp': '2026-11-24T09:00:00Z', 'speed_kmh': 20.0},
        ],
      });

      expect(detail.averageSpeedKmh, 32.5);
      expect(detail.batteryStartPercent, 72.0);
      expect(detail.batteryEndPercent, 68.0);
      expect(detail.route.length, 2);
      expect(detail.route.first.latitude, 12.97);
      expect(detail.route.last.latitude, 12.98);
    });

    test('returns empty route when route is null or missing', () {
      final detail = TripDetail.fromJson({
        'trip_id': 'trp_empty',
        'status': 'completed',
        'started_at': '2026-11-24T09:00:00Z',
        'route': null,
      });
      expect(detail.route, isEmpty);
      expect(RoutePoint.parseList(null), isEmpty);
    });
    test('parses naive ISO timestamps without Z suffix as UTC', () {
      final trip = Trip.fromJson({
        'trip_id': 'trp_naive',
        'status': 'completed',
        'started_at': '2026-11-27T07:30:00',
        'ended_at': '2026-11-27T08:15:00',
        'start_location': {'description': 'A'},
      });
      expect(trip.startedAt.isUtc, isTrue);
      expect(trip.startedAt, DateTime.utc(2026, 11, 27, 7, 30));
      expect(trip.endedAt?.isUtc, isTrue);
      expect(trip.endedAt, DateTime.utc(2026, 11, 27, 8, 15));
    });
  });
}
