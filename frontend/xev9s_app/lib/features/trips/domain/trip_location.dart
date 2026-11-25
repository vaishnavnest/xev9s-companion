import 'package:equatable/equatable.dart';

/// Geographic coordinates with an optional human-readable description.
class TripLocation extends Equatable {
  const TripLocation({
    this.latitude,
    this.longitude,
    this.description,
  });

  final double? latitude;
  final double? longitude;
  final String? description;

  /// Returns true only when both latitude and longitude are non-null, finite,
  /// and within valid geographic bounds (`[-90, 90]` and `[-180, 180]`).
  bool get hasCoordinates {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    final rawLat = json['latitude'] ?? json['lat'];
    final rawLng = json['longitude'] ?? json['lng'] ?? json['lon'];
    final rawDesc = json['description'] ?? json['address'] ?? json['name'];

    return TripLocation(
      latitude: rawLat is num ? rawLat.toDouble() : null,
      longitude: rawLng is num ? rawLng.toDouble() : null,
      description: rawDesc is String && rawDesc.trim().isNotEmpty
          ? rawDesc.trim()
          : null,
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, description];
}
