import 'package:equatable/equatable.dart';

/// Single GPS coordinate sample recorded along a trip route.
class RoutePoint extends Equatable {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.speedKmh,
  });

  final double latitude;
  final double longitude;
  final DateTime? timestamp;
  final double? speedKmh;

  /// Attempts to parse a [RoutePoint] from JSON, returning `null` if
  /// coordinates are missing, non-finite, or out of valid bounds.
  static RoutePoint? tryFromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;

    final rawLat = raw['latitude'] ?? raw['lat'];
    final rawLng = raw['longitude'] ?? raw['lng'] ?? raw['lon'];
    if (rawLat is! num || rawLng is! num) return null;

    final lat = rawLat.toDouble();
    final lng = rawLng.toDouble();
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90.0 || lat > 90.0 || lng < -180.0 || lng > 180.0) {
      return null;
    }

    final rawTs = raw['timestamp'] ?? raw['recorded_at'] ?? raw['recordedAt'];
    final ts = rawTs is String ? DateTime.tryParse(rawTs) : null;

    final rawSpeed = raw['speed_kmh'] ?? raw['speedKmh'] ?? raw['speed_kph'];
    final speed = rawSpeed is num && rawSpeed.isFinite ? rawSpeed.toDouble() : null;

    return RoutePoint(
      latitude: lat,
      longitude: lng,
      timestamp: ts,
      speedKmh: speed,
    );
  }

  /// Parses a JSON array of route points, dropping any invalid entries.
  static List<RoutePoint> parseList(Object? rawList) {
    if (rawList is! List) return const [];
    final points = <RoutePoint>[];
    for (final item in rawList) {
      final pt = tryFromJson(item);
      if (pt != null) {
        points.add(pt);
      }
    }
    return List.unmodifiable(points);
  }

  @override
  List<Object?> get props => [latitude, longitude, timestamp, speedKmh];
}
