import 'package:equatable/equatable.dart';
import 'vehicle_status.dart';

/// Event names recognized over the WebSocket realtime stream.
enum RealtimeEventType {
  vehicleStatus('vehicle.status'),
  vehicleLocation('vehicle.location'),
  chargingUpdated('charging.updated'),
  commandUpdated('command.updated'),
  notificationCreated('notification.created'),
  connectivityChanged('connectivity.changed'),
  unknown('unknown');

  const RealtimeEventType(this.wireValue);
  final String wireValue;

  static RealtimeEventType fromString(String? value) {
    if (value == null || value.trim().isEmpty) return RealtimeEventType.unknown;
    final normalized = value.trim();
    for (final type in RealtimeEventType.values) {
      if (type.wireValue == normalized) return type;
    }
    return RealtimeEventType.unknown;
  }
}

/// Lightweight snapshot of a charging.updated event payload.
class ChargingOverviewLite extends Equatable {
  const ChargingOverviewLite({
    this.state = ChargingState.unknown,
    this.powerKw,
    this.batteryPercent,
  });

  final ChargingState state;
  final double? powerKw;
  final double? batteryPercent;

  factory ChargingOverviewLite.fromJson(Map<String, dynamic> json) {
    return ChargingOverviewLite(
      state: json['state'] != null
          ? ChargingState.fromString(json['state'] as String?)
          : ChargingState.unknown,
      powerKw: (json['powerKw'] as num?)?.toDouble(),
      batteryPercent: (json['batteryPercent'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [state, powerKw, batteryPercent];
}

/// Lightweight snapshot of a connectivity.changed event payload.
class ConnectivityStatusLite extends Equatable {
  const ConnectivityStatusLite({
    this.status = ConnectivityStatus.unknown,
    this.lastCommunicationAt,
  });

  final ConnectivityStatus status;
  final DateTime? lastCommunicationAt;

  factory ConnectivityStatusLite.fromJson(Map<String, dynamic> json) {
    DateTime? lastComm;
    final rawTime = json['lastCommunicationAt'] as String?;
    if (rawTime != null) {
      lastComm = DateTime.tryParse(rawTime);
    }

    return ConnectivityStatusLite(
      status: json['status'] != null
          ? ConnectivityStatus.fromString(json['status'] as String?)
          : ConnectivityStatus.unknown,
      lastCommunicationAt: lastComm,
    );
  }

  @override
  List<Object?> get props => [status, lastCommunicationAt];
}

/// Inbound push event from the connected vehicle platform realtime service.
class RealtimeEvent extends Equatable {
  const RealtimeEvent({
    required this.type,
    required this.vehicleId,
    required this.timestamp,
    this.rawData,
  });

  final RealtimeEventType type;
  final String vehicleId;
  final DateTime timestamp;
  final Map<String, dynamic>? rawData;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final rawEvent = json['event'] as String?;
    final type = RealtimeEventType.fromString(rawEvent);
    final vehicleId = json['vehicleId'] as String? ?? '';

    DateTime parsedTime;
    final rawTimestamp = json['timestamp'] as String?;
    if (rawTimestamp != null) {
      parsedTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    final rawData = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : null;

    return RealtimeEvent(
      type: type,
      vehicleId: vehicleId,
      timestamp: parsedTime,
      rawData: rawData,
    );
  }

  /// Safely parses the event payload into a [VehicleStatus], or returns null if malformed.
  VehicleStatus? asVehicleStatus() {
    if (rawData == null) return null;
    try {
      final map = Map<String, dynamic>.from(rawData!);
      if (!map.containsKey('vehicleId') || map['vehicleId'] == null) {
        map['vehicleId'] = vehicleId;
      }
      if (!map.containsKey('lastUpdatedAt') || map['lastUpdatedAt'] == null) {
        map['lastUpdatedAt'] = timestamp.toUtc().toIso8601String();
      }
      return VehicleStatus.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Safely parses the event payload into [ChargingOverviewLite], or returns null on failure.
  ChargingOverviewLite? asChargingOverview() {
    if (rawData == null) return null;
    try {
      return ChargingOverviewLite.fromJson(rawData!);
    } catch (_) {
      return null;
    }
  }

  /// Safely parses the event payload into [ConnectivityStatusLite], or returns null on failure.
  ConnectivityStatusLite? asConnectivity() {
    if (rawData == null) return null;
    try {
      return ConnectivityStatusLite.fromJson(rawData!);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [type, vehicleId, timestamp, rawData];
}
