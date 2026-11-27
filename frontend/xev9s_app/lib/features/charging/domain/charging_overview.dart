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
    this.timezone = 'UTC',
    this.stopChargingAtTarget = true,
  });

  final ChargingState state;
  final double? batteryPercent;
  final int? targetPercent;
  final double? powerKw;
  final int? sessionDurationSeconds;
  final ChargingSchedule? schedule;
  final String? currentSessionId;
  final String timezone;
  final bool stopChargingAtTarget;

  factory ChargingOverview.fromJson(Map<String, dynamic> json) {
    final eventMap = json['event'] is Map<String, dynamic>
        ? json['event'] as Map<String, dynamic>
        : null;
    final sessionMap = json['session'] is Map<String, dynamic>
        ? json['session'] as Map<String, dynamic>
        : null;

    final isPreferencesPayload = json.containsKey('target_percentage') ||
        json.containsKey('schedule_enabled');

    final rawState = (json['state'] ??
            sessionMap?['status'] ??
            eventMap?['event_type'] ??
            (isPreferencesPayload ? 'NOT_CONNECTED' : null))
        as String?;
    final state = ChargingState.fromString(rawState);

    final battery = (json['batteryPercent'] ??
            json['battery_percentage'] ??
            eventMap?['battery_percentage'] ??
            sessionMap?['ending_battery_percentage'] ??
            sessionMap?['starting_battery_percentage']) as num?;
    final target = (json['targetPercent'] ??
            json['target_percentage'] ??
            sessionMap?['final_target_percentage'] ??
            sessionMap?['target_percentage']) as num?;
    final power = (json['powerKw'] ??
            json['charging_power_kw'] ??
            eventMap?['charging_power_kw'] ??
            sessionMap?['charging_power_kw']) as num?;
    final duration = (json['sessionDurationSeconds'] ??
            sessionMap?['duration_seconds']) as num?;

    ChargingSchedule? schedule;
    if (json['schedule'] is Map<String, dynamic>) {
      schedule =
          ChargingSchedule.fromJson(json['schedule'] as Map<String, dynamic>);
    } else if (json.containsKey('schedule_enabled')) {
      schedule = ChargingSchedule.fromJson(json);
    }

    final currentSession =
        (json['currentSessionId'] ?? sessionMap?['session_id']) as String?;
    final timezone = (json['timezone'] as String?)?.trim();
    final stopAtTarget = json['stop_charging_at_target'] as bool?;

    return ChargingOverview(
      state: state,
      batteryPercent: battery?.toDouble(),
      targetPercent: target?.round(),
      powerKw: power?.toDouble(),
      sessionDurationSeconds: duration?.toInt(),
      schedule: schedule,
      currentSessionId: currentSession,
      timezone: (timezone != null && timezone.isNotEmpty) ? timezone : 'UTC',
      stopChargingAtTarget: stopAtTarget ?? true,
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
    String? timezone,
    bool? stopChargingAtTarget,
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
      timezone: timezone ?? this.timezone,
      stopChargingAtTarget:
          stopChargingAtTarget ?? this.stopChargingAtTarget,
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
        timezone,
        stopChargingAtTarget,
      ];
}
