import 'package:equatable/equatable.dart';
import '../../../core/constants/app_constants.dart';
import 'route_point.dart';

/// Pure bounding box without any Flutter or map-library dependency.
class RouteBounds extends Equatable {
  const RouteBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  bool get isSinglePoint => minLat == maxLat && minLng == maxLng;

  double get centerLat => (minLat + maxLat) / 2.0;
  double get centerLng => (minLng + maxLng) / 2.0;

  @override
  List<Object?> get props => [minLat, maxLat, minLng, maxLng];
}

/// Computes the geographic bounding box for [points], or returns `null` if empty.
RouteBounds? computeRouteBounds(List<RoutePoint> points) {
  if (points.isEmpty) return null;

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;

  for (var i = 1; i < points.length; i++) {
    final p = points[i];
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  return RouteBounds(
    minLat: minLat,
    maxLat: maxLat,
    minLng: minLng,
    maxLng: maxLng,
  );
}

/// Uniform-stride route downsampler.
///
/// Always keeps the first and last point when `points.length > maxPoints`.
/// Returns [points] unchanged when `points.length <= maxPoints`.
List<RoutePoint> downsampleRoute(
  List<RoutePoint> points, {
  int maxPoints = AppConstants.routeMaxRenderPoints,
}) {
  if (maxPoints <= 0) return const [];
  if (points.length <= maxPoints) return points;
  if (maxPoints == 1) return [points.first];
  if (maxPoints == 2) return [points.first, points.last];

  final result = <RoutePoint>[points.first];
  final interiorSlots = maxPoints - 2;
  final span = points.length - 1;

  for (var i = 1; i <= interiorSlots; i++) {
    final index = (i * span / (interiorSlots + 1)).round();
    if (index > 0 && index < span) {
      result.add(points[index]);
    }
  }
  result.add(points.last);
  return result;
}

/// Date filter preset options for trip history.
enum TripDatePreset {
  today,
  last7Days,
  last30Days,
  custom,
}

/// Selected date filter range for trips.
class TripDateRange extends Equatable {
  const TripDateRange({
    required this.preset,
    this.customStart,
    this.customEnd,
  });

  const TripDateRange.today() : this(preset: TripDatePreset.today);
  const TripDateRange.last7Days() : this(preset: TripDatePreset.last7Days);
  const TripDateRange.last30Days() : this(preset: TripDatePreset.last30Days);
  const TripDateRange.custom(DateTime start, DateTime end)
      : this(
          preset: TripDatePreset.custom,
          customStart: start,
          customEnd: end,
        );

  final TripDatePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  @override
  List<Object?> get props => [preset, customStart, customEnd];
}

/// Converts a [TripDateRange] into UTC ISO-8601 `(fromUtcIso, toUtcIso)` query strings.
///
/// Uses [now] and [localOffset] for deterministic, DST-safe calendar-day math.
(String fromUtcIso, String toUtcIso) dateRangeToQuery(
  TripDateRange range, {
  DateTime? now,
  Duration? localOffset,
}) {
  final reference = now ?? DateTime.now();
  final offset = localOffset ?? reference.timeZoneOffset;

  // Shift reference instant into wall-clock UTC representation so calendar-day
  // boundaries are immune to host DST transitions.
  final wallNow = reference.toUtc().add(offset);

  DateTime startWall;
  DateTime endWall;

  switch (range.preset) {
    case TripDatePreset.today:
      startWall = DateTime.utc(wallNow.year, wallNow.month, wallNow.day);
      endWall = DateTime.utc(wallNow.year, wallNow.month, wallNow.day, 23, 59, 59, 999);
      break;
    case TripDatePreset.last7Days:
      final startDay = DateTime.utc(wallNow.year, wallNow.month, wallNow.day)
          .subtract(const Duration(days: 6));
      startWall = startDay;
      endWall = DateTime.utc(wallNow.year, wallNow.month, wallNow.day, 23, 59, 59, 999);
      break;
    case TripDatePreset.last30Days:
      final startDay = DateTime.utc(wallNow.year, wallNow.month, wallNow.day)
          .subtract(const Duration(days: 29));
      startWall = startDay;
      endWall = DateTime.utc(wallNow.year, wallNow.month, wallNow.day, 23, 59, 59, 999);
      break;
    case TripDatePreset.custom:
      final s = range.customStart ?? wallNow;
      final e = range.customEnd ?? s;
      final orderedStart = s.isAfter(e) ? e : s;
      final orderedEnd = s.isAfter(e) ? s : e;
      startWall = DateTime.utc(orderedStart.year, orderedStart.month, orderedStart.day);
      endWall = DateTime.utc(
        orderedEnd.year,
        orderedEnd.month,
        orderedEnd.day,
        23,
        59,
        59,
        999,
      );
      break;
  }

  final fromUtc = startWall.subtract(offset);
  final toUtc = endWall.subtract(offset);
  return (fromUtc.toIso8601String(), toUtc.toIso8601String());
}
