import 'package:equatable/equatable.dart';
import 'trip_location.dart';
import 'trip_status.dart';

/// Summary of a single vehicle trip (UC-06).
class Trip extends Equatable {
  const Trip({
    required this.tripId,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.startLocation,
    this.endLocation,
    this.distanceKm,
    this.durationSeconds,
    this.energyConsumedKwh,
  });

  final String tripId;
  final TripStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TripLocation startLocation;
  final TripLocation? endLocation;
  final double? distanceKm;
  final int? durationSeconds;
  final double? energyConsumedKwh;

  bool get isOngoing => status == TripStatus.ongoing;

  /// Returns elapsed duration at [now] for ongoing trips, or `null` if not ongoing.
  Duration? elapsedAt(DateTime now) {
    if (!isOngoing) return null;
    final diff = now.toUtc().difference(startedAt.toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    final rawId = json['trip_id'] ?? json['tripId'];
    if (rawId is! String || rawId.trim().isEmpty) {
      throw const FormatException('Missing required field: trip_id / tripId');
    }

    final rawStatus = json['status'];
    if (rawStatus is! String || rawStatus.trim().isEmpty) {
      throw const FormatException('Missing required field: status');
    }

    final rawStartedAt = json['started_at'] ?? json['startedAt'];
    if (rawStartedAt is! String) {
      throw const FormatException('Missing required field: started_at / startedAt');
    }
    final startedAt = DateTime.tryParse(rawStartedAt);
    if (startedAt == null) {
      throw FormatException('Invalid started_at timestamp: $rawStartedAt');
    }

    final rawEndedAt = json['ended_at'] ?? json['endedAt'];
    final endedAt = rawEndedAt is String ? DateTime.tryParse(rawEndedAt) : null;

    final rawStartLoc = json['start_location'] ?? json['startLocation'];
    final startLocation = rawStartLoc is Map<String, dynamic>
        ? TripLocation.fromJson(rawStartLoc)
        : const TripLocation();

    final rawEndLoc = json['end_location'] ?? json['endLocation'];
    final endLocation = rawEndLoc is Map<String, dynamic>
        ? TripLocation.fromJson(rawEndLoc)
        : null;

    final rawDist = json['distance_km'] ?? json['distanceKm'];
    final distanceKm = rawDist is num && rawDist.isFinite ? rawDist.toDouble() : null;

    final rawDuration = json['duration_seconds'] ?? json['durationSeconds'];
    final durationSeconds =
        rawDuration is num && rawDuration.isFinite ? rawDuration.toInt() : null;

    final rawEnergy = json['energy_consumed_kwh'] ?? json['energyConsumedKwh'];
    final energyConsumedKwh =
        rawEnergy is num && rawEnergy.isFinite ? rawEnergy.toDouble() : null;

    return Trip(
      tripId: rawId.trim(),
      status: TripStatus.fromApi(rawStatus),
      startedAt: startedAt,
      endedAt: endedAt,
      startLocation: startLocation,
      endLocation: endLocation,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      energyConsumedKwh: energyConsumedKwh,
    );
  }

  @override
  List<Object?> get props => [
        tripId,
        status,
        startedAt,
        endedAt,
        startLocation,
        endLocation,
        distanceKm,
        durationSeconds,
        energyConsumedKwh,
      ];
}
