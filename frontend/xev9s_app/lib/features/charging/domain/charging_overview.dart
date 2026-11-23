import 'package:equatable/equatable.dart';
import '../../vehicles/domain/vehicle_status.dart';
import 'charging_schedule.dart';

/// Live charging overview snapshot from GET /vehicles/{id}/charging or charging.updated.
class ChargingOverview extends Equatable {
  const ChargingOverview({
    required this.state,
    this.batteryPercent,
    this.targetPercent,
    this.powerKw,
    this.sessionDurationSeconds,
    this.schedule,
    this.currentSessionId,
  });

  final ChargingState state;
  final double? batteryPercent;
  final int? targetPercent;
  final double? powerKw;
  final int? sessionDurationSeconds;
  final ChargingSchedule? schedule;
  final String? currentSessionId;

  factory ChargingOverview.fromJson(Map<String, dynamic> json) {
    final state = ChargingState.fromString(json['state'] as String?);
    final battery = (json['batteryPercent'] as num?)?.toDouble();
    final target = (json['targetPercent'] as num?)?.toInt();
    final power = (json['powerKw'] as num?)?.toDouble();
    final duration = (json['sessionDurationSeconds'] as num?)?.toInt();

    ChargingSchedule? schedule;
    if (json['schedule'] is Map<String, dynamic>) {
      schedule =
          ChargingSchedule.fromJson(json['schedule'] as Map<String, dynamic>);
    }

    final currentSession = json['currentSessionId'] as String?;

    return ChargingOverview(
      state: state,
      batteryPercent: battery,
      targetPercent: target,
      powerKw: power,
      sessionDurationSeconds: duration,
      schedule: schedule,
      currentSessionId: currentSession,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state.wireValue,
      if (batteryPercent != null) 'batteryPercent': batteryPercent,
      if (targetPercent != null) 'targetPercent': targetPercent,
      if (powerKw != null) 'powerKw': powerKw,
      if (sessionDurationSeconds != null)
        'sessionDurationSeconds': sessionDurationSeconds,
      if (schedule != null) 'schedule': schedule!.toJson(),
      if (currentSessionId != null) 'currentSessionId': currentSessionId,
    };
  }

  ChargingOverview copyWith({
    ChargingState? state,
    double? batteryPercent,
    int? targetPercent,
    double? powerKw,
    int? sessionDurationSeconds,
    ChargingSchedule? schedule,
    String? currentSessionId,
    bool clearCurrentSessionId = false,
  }) {
    return ChargingOverview(
      state: state ?? this.state,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      targetPercent: targetPercent ?? this.targetPercent,
      powerKw: powerKw ?? this.powerKw,
      sessionDurationSeconds:
          sessionDurationSeconds ?? this.sessionDurationSeconds,
      schedule: schedule ?? this.schedule,
      currentSessionId: clearCurrentSessionId
          ? null
          : (currentSessionId ?? this.currentSessionId),
    );
  }

  @override
  List<Object?> get props => [
        state,
        batteryPercent,
        targetPercent,
        powerKw,
        sessionDurationSeconds,
        schedule,
        currentSessionId,
      ];
}
