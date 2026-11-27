import 'package:equatable/equatable.dart';
import 'vehicle_status.dart';

/// Event names recognized over the WebSocket realtime stream.
enum RealtimeEventType {
  vehicleStatus('vehicle.status'),
  vehicleLocation('vehicle.location'),
  chargingUpdated('charging.updated'),
  commandUpdated('command.updated'),
  tripCompleted('trip.completed'),
  notificationCreated('notification.created'),
  connectivityChanged('connectivity.changed'),
  unknown('unknown');

  const RealtimeEventType(this.wireValue);
  final String wireValue;

  static RealtimeEventType fromString(String? value) {
    if (value == null || value.trim().isEmpty) return RealtimeEventType.unknown;
    final normalized = value.trim();
    if (normalized == 'command_updated') {
      return RealtimeEventType.commandUpdated;
    }
    if (normalized == 'charging_update') {
      return RealtimeEventType.chargingUpdated;
    }
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
    final eventMap = json['event'] is Map<String, dynamic>
        ? json['event'] as Map<String, dynamic>
        : null;
    final sessionMap = json['session'] is Map<String, dynamic>
        ? json['session'] as Map<String, dynamic>
        : null;

    final rawState = (json['state'] ??
            sessionMap?['status'] ??
            eventMap?['event_type'] ??
            json['charging_status'])
        as String?;
    final power = (json['powerKw'] ??
            json['charging_power_kw'] ??
            eventMap?['charging_power_kw'] ??
            sessionMap?['charging_power_kw']) as num?;
    final battery = (json['batteryPercent'] ??
            json['battery_percentage'] ??
            eventMap?['battery_percentage'] ??
            sessionMap?['ending_battery_percentage'] ??
            sessionMap?['starting_battery_percentage']) as num?;

    return ChargingOverviewLite(
      state: rawState != null
          ? ChargingState.fromString(rawState)
          : ChargingState.unknown,
      powerKw: power?.toDouble(),
      batteryPercent: battery?.toDouble(),
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
    final rawEvent = json['event'] is String
        ? json['event'] as String
        : (json['type'] as String?);
    final type = RealtimeEventType.fromString(rawEvent);
    final vehicleId = (json['vehicleId'] ?? json['vehicle_id']) as String? ?? '';

    final eventObj = json['event'] is Map<String, dynamic>
        ? json['event'] as Map<String, dynamic>
        : null;

    DateTime parsedTime;
    final rawTimestamp = (json['timestamp'] ??
            eventObj?['timestamp'] ??
            json['completed_at'] ??
            json['requested_at'])
        as String?;
    if (rawTimestamp != null) {
      parsedTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    Map<String, dynamic>? rawData;
    if (json['data'] is Map<String, dynamic>) {
      rawData = json['data'] as Map<String, dynamic>;
    } else if (type == RealtimeEventType.chargingUpdated &&
        (eventObj != null || json['session'] is Map<String, dynamic>)) {
      rawData = json;
    } else if (type == RealtimeEventType.commandUpdated &&
        (json.containsKey('command_id') || json.containsKey('commandId'))) {
      rawData = json;
    }

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
        map['vehicleId'] = vehicleId.isNotEmpty ? vehicleId : (map['vehicle_id'] ?? '');
      }
      if (!map.containsKey('lastUpdatedAt') || map['lastUpdatedAt'] == null) {
        map['lastUpdatedAt'] = map['timestamp'] ?? timestamp.toUtc().toIso8601String();
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
