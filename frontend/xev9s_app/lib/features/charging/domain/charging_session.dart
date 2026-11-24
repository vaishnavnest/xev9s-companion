import 'package:equatable/equatable.dart';
import '../../vehicles/domain/vehicle_status.dart';

/// Historical or active EV charging session record.
class ChargingSession extends Equatable {
  const ChargingSession({
    required this.sessionId,
    required this.vehicleId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.startBatteryPercent,
    this.endBatteryPercent,
    this.targetPercent,
    this.avgPowerKw,
    this.maxPowerKw,
    required this.status,
    this.interruptionReason,
  });

  final String sessionId;
  final String vehicleId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final double? startBatteryPercent;
  final double? endBatteryPercent;
  final int? targetPercent;
  final double? avgPowerKw;
  final double? maxPowerKw;
  final ChargingState status;
  final String? interruptionReason;

  /// Whether session is actively in progress.
  bool get isActive =>
      (status == ChargingState.charging ||
          status == ChargingState.paused ||
          status == ChargingState.connected) &&
      endedAt == null;

  /// Whether session reached full/completed state.
  bool get isCompleted => status == ChargingState.completed;

  /// Whether session was prematurely interrupted.
  bool get isInterrupted => status == ChargingState.interrupted;

  factory ChargingSession.fromJson(Map<String, dynamic> json) {
    final sessionId = json['sessionId'] as String? ?? '';
    final vehicleId = json['vehicleId'] as String? ?? '';

    DateTime startedAt;
    final startStr = json['startedAt'] as String?;
    if (startStr != null) {
      startedAt = DateTime.tryParse(startStr) ?? DateTime.now();
    } else {
      startedAt = DateTime.now();
    }

    DateTime? endedAt;
    final endStr = json['endedAt'] as String?;
    if (endStr != null) {
      endedAt = DateTime.tryParse(endStr);
    }

    final duration = (json['durationSeconds'] as num?)?.toInt();
    final startBattery = (json['startBatteryPercent'] as num?)?.toDouble();
    final endBattery = (json['endBatteryPercent'] as num?)?.toDouble();
    final target = (json['targetPercent'] as num?)?.toInt();
    final avgPower = (json['avgPowerKw'] as num?)?.toDouble();
    final maxPower = (json['maxPowerKw'] as num?)?.toDouble();
    final status = ChargingState.fromString(json['status'] as String?);
    final interruptionReason = json['interruptionReason'] as String?;

    return ChargingSession(
      sessionId: sessionId,
      vehicleId: vehicleId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: duration,
      startBatteryPercent: startBattery,
      endBatteryPercent: endBattery,
      targetPercent: target,
      avgPowerKw: avgPower,
      maxPowerKw: maxPower,
      status: status,
      interruptionReason: interruptionReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'vehicleId': vehicleId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (startBatteryPercent != null)
        'startBatteryPercent': startBatteryPercent,
      if (endBatteryPercent != null) 'endBatteryPercent': endBatteryPercent,
      if (targetPercent != null) 'targetPercent': targetPercent,
      if (avgPowerKw != null) 'avgPowerKw': avgPowerKw,
      if (maxPowerKw != null) 'maxPowerKw': maxPowerKw,
      'status': status.wireValue,
      if (interruptionReason != null) 'interruptionReason': interruptionReason,
    };
  }

  @override
  List<Object?> get props => [
        sessionId,
        vehicleId,
        startedAt,
        endedAt,
        durationSeconds,
        startBatteryPercent,
        endBatteryPercent,
        targetPercent,
        avgPowerKw,
        maxPowerKw,
        status,
        interruptionReason,
      ];
}
