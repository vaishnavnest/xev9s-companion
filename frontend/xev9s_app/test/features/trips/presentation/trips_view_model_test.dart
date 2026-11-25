import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/trips/domain/trip.dart';
import 'package:xev9s_app/features/trips/domain/trip_detail.dart';
import 'package:xev9s_app/features/trips/domain/trip_location.dart';
import 'package:xev9s_app/features/trips/domain/trip_status.dart';
import 'package:xev9s_app/features/trips/presentation/trips_view_model.dart';

void main() {
  group('TripsViewModel', () {
    test('formats completed vs ongoing wording and "-" for null fields', () {
      final completed = Trip(
        tripId: 't1',
        status: TripStatus.completed,
        startedAt: DateTime.utc(2026, 11, 24, 9, 0),
        endedAt: DateTime.utc(2026, 11, 24, 9, 34),
        startLocation: const TripLocation(description: 'MG Road'),
        endLocation: null,
        distanceKm: 0.0,
        durationSeconds: 2040,
        energyConsumedKwh: null,
      );

      expect(TripsViewModel.routeLabel(completed), 'MG Road \u2192 Unknown location');
      expect(TripsViewModel.distanceLabel(completed.distanceKm), '0.0 km');
      expect(TripsViewModel.energyLabel(completed.energyConsumedKwh), '-');
      expect(TripsViewModel.rowDurationLabel(completed), '34m');

      final ongoing = Trip(
        tripId: 't2',
        status: TripStatus.ongoing,
        startedAt: DateTime.utc(2026, 11, 24, 10, 0),
        startLocation: const TripLocation(),
      );

      expect(TripsViewModel.timeRangeLabel(ongoing), contains('In progress'));
      expect(
        TripsViewModel.rowDurationLabel(
          ongoing,
          now: DateTime.utc(2026, 11, 24, 10, 12),
        ),
        'Driving for 12 min',
      );
      expect(TripsViewModel.distanceLabel(ongoing.distanceKm), '-');
      expect(TripsViewModel.liveElapsedLabel(const Duration(minutes: 12, seconds: 5)), '12m 05s');
    });

    test('formats battery range and detail null placeholders', () {
      final detail = TripDetail(
        trip: Trip(
          tripId: 't1',
          status: TripStatus.completed,
          startedAt: DateTime.utc(2026, 11, 24, 9, 0),
          startLocation: const TripLocation(description: 'A'),
        ),
        batteryStartPercent: 72.0,
        batteryEndPercent: 68.0,
      );

      expect(TripsViewModel.batteryRangeLabel(detail), '72% \u2192 68%');
      expect(TripsViewModel.averageSpeedLabel(detail.averageSpeedKmh), '-');

      final ongoingDetail = TripDetail(
        trip: Trip(
          tripId: 't2',
          status: TripStatus.ongoing,
          startedAt: DateTime.utc(2026, 11, 24, 9, 0),
          startLocation: const TripLocation(description: 'A'),
        ),
      );
      expect(TripsViewModel.endedAtLabel(ongoingDetail), 'In progress');
      expect(TripsViewModel.detailDurationLabel(ongoingDetail), '-');
      expect(TripsViewModel.batteryRangeLabel(ongoingDetail), '- \u2192 -');
    });

    test('groups trips by day with Today, Yesterday, and formatted date headers', () {
      final now = DateTime(2026, 11, 25, 12, 0);
      final trips = [
        Trip(
          tripId: 'today',
          status: TripStatus.completed,
          startedAt: DateTime(2026, 11, 25, 9, 0),
          startLocation: const TripLocation(),
        ),
        Trip(
          tripId: 'yesterday',
          status: TripStatus.completed,
          startedAt: DateTime(2026, 11, 24, 18, 0),
          startLocation: const TripLocation(),
        ),
        Trip(
          tripId: 'older',
          status: TripStatus.completed,
          startedAt: DateTime(2026, 11, 20, 14, 0),
          startLocation: const TripLocation(),
        ),
      ];

      final groups = TripsViewModel.groupTripsByDay(trips, now: now);
      expect(groups.map((g) => g.header).toList(), ['Today', 'Yesterday', 'Nov 20, 2026']);
    });
  });
}
