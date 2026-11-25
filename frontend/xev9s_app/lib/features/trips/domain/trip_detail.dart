import 'package:equatable/equatable.dart';
import 'route_point.dart';
import 'trip.dart';
import 'trip_location.dart';
import 'trip_status.dart';

/// Detailed trip record including average speed, battery range, and GPS route (UC-06).
class TripDetail extends Equatable {
  const TripDetail({
    required this.trip,
    this.averageSpeedKmh,
    this.batteryStartPercent,
    this.batteryEndPercent,
    this.route = const [],
  });

  final Trip trip;
  final double? averageSpeedKmh;
  final double? batteryStartPercent;
  final double? batteryEndPercent;
  final List<RoutePoint> route;

  String get tripId => trip.tripId;
  TripStatus get status => trip.status;
  bool get isOngoing => trip.isOngoing;
  DateTime get startedAt => trip.startedAt;
  DateTime? get endedAt => trip.endedAt;
  TripLocation get startLocation => trip.startLocation;
  TripLocation? get endLocation => trip.endLocation;
  double? get distanceKm => trip.distanceKm;
  int? get durationSeconds => trip.durationSeconds;
  double? get energyConsumedKwh => trip.energyConsumedKwh;
  Duration? elapsedAt(DateTime now) => trip.elapsedAt(now);

  factory TripDetail.fromJson(Map<String, dynamic> json) {
    final trip = Trip.fromJson(json);

    final rawAvgSpeed = json['average_speed_kmh'] ?? json['averageSpeedKmh'];
    final averageSpeedKmh =
        rawAvgSpeed is num && rawAvgSpeed.isFinite ? rawAvgSpeed.toDouble() : null;

    double? batteryStart;
    double? batteryEnd;
    final rawBattery = json['battery'];
    if (rawBattery is Map<String, dynamic>) {
      final rawStart = rawBattery['start_percent'] ?? rawBattery['startPercent'];
      final rawEnd = rawBattery['end_percent'] ?? rawBattery['endPercent'];
      if (rawStart is num && rawStart.isFinite) batteryStart = rawStart.toDouble();
      if (rawEnd is num && rawEnd.isFinite) batteryEnd = rawEnd.toDouble();
    }

    var parsedRoute = RoutePoint.parseList(json['route']);
    if (parsedRoute.length > 1 && parsedRoute.every((p) => p.timestamp != null)) {
      final sorted = List<RoutePoint>.from(parsedRoute)
        ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
      parsedRoute = List.unmodifiable(sorted);
    }

    return TripDetail(
      trip: trip,
      averageSpeedKmh: averageSpeedKmh,
      batteryStartPercent: batteryStart,
      batteryEndPercent: batteryEnd,
      route: parsedRoute,
    );
  }

  @override
  List<Object?> get props => [
        trip,
        averageSpeedKmh,
        batteryStartPercent,
        batteryEndPercent,
        route,
      ];
}
