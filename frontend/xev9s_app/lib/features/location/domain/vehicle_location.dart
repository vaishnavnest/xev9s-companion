import 'package:equatable/equatable.dart';
import '../../vehicles/domain/vehicle_status.dart';

const _sentinel = Object();

/// Representation of the latest reported or last-known vehicle geographic position.
class VehicleLocation extends Equatable {
  const VehicleLocation({
    required this.vehicleId,
    this.latitude,
    this.longitude,
    this.description,
    this.vehicleState = VehicleState.unknown,
    this.reportedAt,
    this.isCurrent = false,
  });

  /// Unique identifier of the associated vehicle.
  final String vehicleId;

  /// Latitude in decimal degrees, or null if never reported.
  final double? latitude;

  /// Longitude in decimal degrees, or null if never reported.
  final double? longitude;

  /// Human-readable address description, or null if unavailable.
  final String? description;

  /// Operational state of the vehicle (PARKED, DRIVING, CHARGING, OFFLINE, UNKNOWN).
  final VehicleState vehicleState;

  /// Timestamp when this location reading was recorded by the vehicle/telemetry.
  final DateTime? reportedAt;

  /// True when the vehicle is actively communicating; false when offline (last-known position).
  final bool isCurrent;

  /// Whether both latitude and longitude are non-null and within legal coordinate bounds:
  /// latitude in [-90.0, 90.0] and longitude in [-180.0, 180.0].
  /// Out-of-range coordinates are treated as no coordinates and must not crash.
  bool get hasCoordinates {
    if (latitude == null || longitude == null) return false;
    if (!latitude!.isFinite || !longitude!.isFinite) return false;
    return latitude! >= -90.0 &&
        latitude! <= 90.0 &&
        longitude! >= -180.0 &&
        longitude! <= 180.0;
  }

  VehicleLocation copyWith({
    String? vehicleId,
    double? latitude,
    double? longitude,
    Object? description = _sentinel,
    VehicleState? vehicleState,
    DateTime? reportedAt,
    bool? isCurrent,
  }) {
    return VehicleLocation(
      vehicleId: vehicleId ?? this.vehicleId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
      vehicleState: vehicleState ?? this.vehicleState,
      reportedAt: reportedAt ?? this.reportedAt,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  factory VehicleLocation.fromJson(Map<String, dynamic> json) {
    final rawVehicleId = json['vehicleId'] ?? json['vehicle_id'];
    if (rawVehicleId == null ||
        rawVehicleId is! String ||
        rawVehicleId.trim().isEmpty) {
      throw const FormatException('Missing required field: vehicleId');
    }

    final rawLat = json['latitude'];
    final rawLng = json['longitude'];
    // Preserve explicit numbers sent by the server (including 0.0).
    // Never invent coordinates or turn null into 0.0.
    final double? latitude = (rawLat is num) ? rawLat.toDouble() : null;
    final double? longitude = (rawLng is num) ? rawLng.toDouble() : null;

    final rawState = (json['vehicleState'] ?? json['operating_state']) as String?;
    final vehicleState = VehicleState.fromString(rawState);

    DateTime? reportedAt;
    final rawReported = (json['reportedAt'] ?? json['timestamp']) as String?;
    if (rawReported != null) {
      reportedAt = DateTime.tryParse(rawReported);
    }

    final isCurrent = (json['isCurrent'] ?? json['is_current']) as bool? ??
        (json.containsKey('received_at') ? true : false);

    return VehicleLocation(
      vehicleId: rawVehicleId.trim(),
      latitude: latitude,
      longitude: longitude,
      description: json['description'] as String?,
      vehicleState: vehicleState,
      reportedAt: reportedAt,
      isCurrent: isCurrent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'vehicleState': vehicleState.wireValue,
      'reportedAt': reportedAt?.toIso8601String(),
      'isCurrent': isCurrent,
    };
  }

  @override
  List<Object?> get props => [
        vehicleId,
        latitude,
        longitude,
        description,
        vehicleState,
        reportedAt,
        isCurrent,
      ];
}
