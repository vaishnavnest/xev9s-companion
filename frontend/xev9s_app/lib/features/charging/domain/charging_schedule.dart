import 'package:equatable/equatable.dart';
import 'day_of_week.dart';

/// Pure value object representing hour and minute without Flutter UI dependencies.
class ScheduleTime extends Equatable {
  const ScheduleTime({
    required this.hour,
    required this.minute,
  })  : assert(hour >= 0 && hour <= 23, 'Hour must be between 0 and 23'),
        assert(minute >= 0 && minute <= 59, 'Minute must be between 0 and 59');

  final int hour;
  final int minute;

  /// Parses a 24-hour time string in "HH:mm" format.
  /// Throws [FormatException] if string does not strictly match "HH:mm".
  factory ScheduleTime.parse(String value) {
    final trimmed = value.trim();
    final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    final match = regex.firstMatch(trimmed);
    if (match == null) {
      throw FormatException('Invalid time string, expected HH:mm: $value');
    }
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    return ScheduleTime(hour: h, minute: m);
  }

  /// Parses a 24-hour time string or returns null on format error.
  static ScheduleTime? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return ScheduleTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Formats time as zero-padded "HH:mm".
  String toApi() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  String toString() => toApi();

  @override
  List<Object?> get props => [hour, minute];
}

/// Recurring scheduled charging window settings.
class ChargingSchedule extends Equatable {
  const ChargingSchedule({
    required this.enabled,
    this.startTime,
    this.endTime,
    this.daysOfWeek = const <DayOfWeek>{},
  });

  final bool enabled;
  final ScheduleTime? startTime;
  final ScheduleTime? endTime;
  final Set<DayOfWeek> daysOfWeek;

  factory ChargingSchedule.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'] as bool? ?? false;
    final startStr = json['startTime'] as String?;
    final endStr = json['endTime'] as String?;

    final ScheduleTime? start =
        startStr != null ? ScheduleTime.parse(startStr) : null;
    final ScheduleTime? end =
        endStr != null ? ScheduleTime.parse(endStr) : null;

    final daysList = json['daysOfWeek'] as List<dynamic>?;
    final Set<DayOfWeek> days;
    if (daysList != null) {
      days = daysList
          .map((item) => DayOfWeek.fromApi(item?.toString()))
          .where((d) => d != DayOfWeek.unknown)
          .toSet();
    } else {
      days = const <DayOfWeek>{};
    }

    return ChargingSchedule(
      enabled: enabled,
      startTime: start,
      endTime: end,
      daysOfWeek: days,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      if (startTime != null) 'startTime': startTime!.toApi(),
      if (endTime != null) 'endTime': endTime!.toApi(),
      'daysOfWeek': daysOfWeek.map((d) => d.toApi()).toList(),
    };
  }

  ChargingSchedule copyWith({
    bool? enabled,
    ScheduleTime? startTime,
    ScheduleTime? endTime,
    Set<DayOfWeek>? daysOfWeek,
  }) {
    return ChargingSchedule(
      enabled: enabled ?? this.enabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }

  @override
  List<Object?> get props => [enabled, startTime, endTime, daysOfWeek];
}
