import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/trips/domain/route_point.dart';
import 'package:xev9s_app/features/trips/domain/route_utils.dart';

void main() {
  group('downsampleRoute', () {
    List<RoutePoint> makePoints(int count) {
      return List.generate(
        count,
        (i) => RoutePoint(
          latitude: 12.9 + i * 0.0001,
          longitude: 77.5 + i * 0.0001,
        ),
      );
    }

    test('returns empty or single-point route unchanged', () {
      expect(downsampleRoute(const [], maxPoints: 10), isEmpty);
      final single = makePoints(1);
      expect(downsampleRoute(single, maxPoints: 10), equals(single));
    });

    test('returns input unchanged when length <= maxPoints', () {
      final points = makePoints(50);
      expect(downsampleRoute(points, maxPoints: 50), equals(points));
      expect(downsampleRoute(points, maxPoints: 100), equals(points));
    });

    test('reduces points to <= maxPoints keeping first, last, and order', () {
      final points = makePoints(1200);
      final sampled = downsampleRoute(points, maxPoints: 500);

      expect(sampled.length, lessThanOrEqualTo(500));
      expect(sampled.first, equals(points.first));
      expect(sampled.last, equals(points.last));

      for (var i = 1; i < sampled.length; i++) {
        expect(sampled[i].latitude, greaterThan(sampled[i - 1].latitude));
      }
    });
  });

  group('computeRouteBounds', () {
    test('returns null for empty route', () {
      expect(computeRouteBounds(const []), isNull);
    });

    test('handles single point and identical points', () {
      const p = RoutePoint(latitude: 12.9716, longitude: 77.5946);
      final singleBounds = computeRouteBounds([p])!;
      expect(singleBounds.isSinglePoint, isTrue);
      expect(singleBounds.centerLat, 12.9716);
      expect(singleBounds.centerLng, 77.5946);

      final identicalBounds = computeRouteBounds([p, p, p])!;
      expect(identicalBounds.isSinglePoint, isTrue);
    });

    test('computes min/max bounds for multi-point route', () {
      const points = [
        RoutePoint(latitude: 12.95, longitude: 77.58),
        RoutePoint(latitude: 12.99, longitude: 77.62),
        RoutePoint(latitude: 12.96, longitude: 77.55),
      ];
      final bounds = computeRouteBounds(points)!;
      expect(bounds.isSinglePoint, isFalse);
      expect(bounds.minLat, 12.95);
      expect(bounds.maxLat, 12.99);
      expect(bounds.minLng, 77.55);
      expect(bounds.maxLng, 77.62);
    });
  });

  group('dateRangeToQuery', () {
    test('converts today preset with positive UTC+05:30 offset', () {
      // 2026-11-25 10:00:00 IST (+05:30) == 2026-11-25 04:30:00 UTC
      final now = DateTime.utc(2026, 11, 25, 4, 30);
      final (fromIso, toIso) = dateRangeToQuery(
        const TripDateRange.today(),
        now: now,
        localOffset: const Duration(hours: 5, minutes: 30),
      );

      // Local 2026-11-25 00:00:00 IST == 2026-11-24 18:30:00 UTC
      expect(DateTime.parse(fromIso), DateTime.utc(2026, 11, 24, 18, 30));
      // Local 2026-11-25 23:59:59.999 IST == 2026-11-25 18:29:59.999 UTC
      expect(
        DateTime.parse(toIso),
        DateTime.utc(2026, 11, 25, 18, 29, 59, 999),
      );
    });

    test('converts last 7 days with negative UTC-05:00 offset', () {
      // 2026-11-25 22:00:00 EST (-05:00) == 2026-11-26 03:00:00 UTC
      final now = DateTime.utc(2026, 11, 26, 3, 0);
      final (fromIso, toIso) = dateRangeToQuery(
        const TripDateRange.last7Days(),
        now: now,
        localOffset: const Duration(hours: -5),
      );

      // 6 days before Nov 25 is Nov 19 00:00:00 EST == Nov 19 05:00:00 UTC
      expect(DateTime.parse(fromIso), DateTime.utc(2026, 11, 19, 5, 0));
      // Nov 25 23:59:59.999 EST == Nov 26 04:59:59.999 UTC
      expect(
        DateTime.parse(toIso),
        DateTime.utc(2026, 11, 26, 4, 59, 59, 999),
      );
    });

    test('converts custom range inclusive of end day', () {
      final (fromIso, toIso) = dateRangeToQuery(
        TripDateRange.custom(
          DateTime(2026, 11, 10),
          DateTime(2026, 11, 12),
        ),
        now: DateTime.utc(2026, 11, 25),
        localOffset: Duration.zero,
      );

      expect(DateTime.parse(fromIso), DateTime.utc(2026, 11, 10, 0, 0));
      expect(
        DateTime.parse(toIso),
        DateTime.utc(2026, 11, 12, 23, 59, 59, 999),
      );
    });
  });
}
