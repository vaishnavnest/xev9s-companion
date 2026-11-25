import 'package:intl/intl.dart';
import '../../../core/utils/formatters.dart';
import '../domain/trip.dart';
import '../domain/trip_detail.dart';
import '../domain/trip_location.dart';

/// Pure Dart display formatting helpers for Trips list and detail screens (UC-06).
/// Contains no Flutter widget dependencies.
class TripsViewModel {
  TripsViewModel._();

  static const String unknownLocation = 'Unknown location';
  static const String inProgressLabel = 'In progress';

  /// Formats a location description, returning "Unknown location" when null/empty.
  static String locationLabel(TripLocation? location) {
    final desc = location?.description?.trim();
    if (desc == null || desc.isEmpty) return unknownLocation;
    return desc;
  }

  /// Formats "From -> To" route summary for a trip row.
  static String routeLabel(Trip trip) {
    final from = locationLabel(trip.startLocation);
    final to = locationLabel(trip.endLocation);
    return '$from \u2192 $to';
  }

  /// Formats start-end time range, e.g. "9:00 AM - 9:34 AM" or "9:00 AM - In progress".
  static String timeRangeLabel(Trip trip) {
    final start = Formatters.formatTime(trip.startedAt);
    if (trip.isOngoing || trip.endedAt == null) {
      return '$start - $inProgressLabel';
    }
    final end = Formatters.formatTime(trip.endedAt);
    return '$start - $end';
  }

  /// Formats trip duration for a row, showing "Driving for X min" for ongoing trips
  /// when [Trip.durationSeconds] is null.
  static String rowDurationLabel(Trip trip, {DateTime? now}) {
    if (trip.durationSeconds != null) {
      return Formatters.formatDuration(trip.durationSeconds);
    }
    if (trip.isOngoing) {
      final elapsed = trip.elapsedAt(now ?? DateTime.now());
      if (elapsed != null) {
        final mins = elapsed.inMinutes;
        return 'Driving for $mins min';
      }
    }
    return Formatters.nullPlaceholder;
  }

  /// Formats live ticking elapsed duration for an ongoing trip detail banner ("12m 05s" or "1h 05m 10s").
  static String liveElapsedLabel(Duration? elapsed) {
    if (elapsed == null) return Formatters.nullPlaceholder;
    final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  /// Formats distance using [Formatters.formatKm], returning "-" for null
  /// and "0.0 km" (never "-") when server explicitly sends 0.0.
  static String distanceLabel(double? distanceKm) {
    return Formatters.formatKm(distanceKm);
  }

  /// Formats energy consumed, returning "-" for null.
  static String energyLabel(double? energyKwh) {
    return Formatters.formatKwh(energyKwh);
  }

  /// Formats average speed, returning "-" for null.
  static String averageSpeedLabel(double? speedKmh) {
    return Formatters.formatKmh(speedKmh);
  }

  /// Formats battery start -> end string, e.g. "72% -> 68%" or "- -> -".
  static String batteryRangeLabel(TripDetail detail) {
    final start = Formatters.formatPercent(detail.batteryStartPercent);
    final end = Formatters.formatPercent(detail.batteryEndPercent);
    return '$start \u2192 $end';
  }

  /// Formats startedAt timestamp for summary card.
  static String startedAtLabel(DateTime startedAt) {
    return Formatters.formatDateTime(startedAt);
  }

  /// Formats endedAt timestamp for summary card ("In progress" when null for ongoing).
  static String endedAtLabel(TripDetail detail) {
    if (detail.endedAt == null) {
      return detail.isOngoing ? inProgressLabel : Formatters.nullPlaceholder;
    }
    return Formatters.formatDateTime(detail.endedAt);
  }

  /// Formats final duration for summary card ("-" when ongoing or null).
  static String detailDurationLabel(TripDetail detail) {
    if (detail.isOngoing) {
      return Formatters.nullPlaceholder;
    }
    return Formatters.formatDuration(detail.durationSeconds);
  }

  /// Returns day-group header ("Today", "Yesterday", or localized date like "Nov 22, 2026").
  static String dayGroupHeader(DateTime timestamp, {DateTime? now}) {
    final localTs = timestamp.toLocal();
    final localNow = (now ?? DateTime.now()).toLocal();

    final tsDay = DateTime(localTs.year, localTs.month, localTs.day);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (tsDay == today) return 'Today';
    if (tsDay == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(tsDay);
  }

  /// Groups a list of trips by local calendar day, preserving order.
  static List<TripDayGroup> groupTripsByDay(
    List<Trip> trips, {
    DateTime? now,
  }) {
    final groups = <String, List<Trip>>{};
    final order = <String>[];

    for (final trip in trips) {
      final header = dayGroupHeader(trip.startedAt, now: now);
      if (!groups.containsKey(header)) {
        groups[header] = <Trip>[];
        order.add(header);
      }
      groups[header]!.add(trip);
    }

    return order
        .map((h) => TripDayGroup(header: h, trips: List.unmodifiable(groups[h]!)))
        .toList(growable: false);
  }
}

/// Day-grouped slice of trips for the list view.
class TripDayGroup {
  const TripDayGroup({
    required this.header,
    required this.trips,
  });

  final String header;
  final List<Trip> trips;
}
