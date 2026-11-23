import '../../../core/utils/formatters.dart';
import '../../vehicles/domain/vehicle_status.dart';
import '../domain/charging_schedule.dart';
import '../domain/day_of_week.dart';

/// Pure presentation helper functions for charging status, schedules, and sessions.
class ChargingDisplayHelpers {
  ChargingDisplayHelpers._();

  /// User-friendly label for EV charging state per UC-04 spec.
  static String stateLabel(ChargingState state) {
    switch (state) {
      case ChargingState.notConnected:
        return 'Not plugged in';
      case ChargingState.connected:
        return 'Plugged in - not charging';
      case ChargingState.charging:
        return 'Charging';
      case ChargingState.paused:
        return 'Paused';
      case ChargingState.completed:
        return 'Charging complete';
      case ChargingState.interrupted:
        return 'Interrupted';
      case ChargingState.unknown:
        return 'Status unavailable';
    }
  }

  /// Formats battery percentage with null returning "-".
  static String formatBattery(double? percent) {
    return Formatters.formatPercent(percent);
  }

  /// Formats power in kilowatts with null returning "-".
  static String formatPower(double? kw) {
    return Formatters.formatKw(kw);
  }

  /// Formats duration seconds into readable string (e.g. "1h 25m", "42m").
  /// Returns "-" when seconds is null.
  static String formatDuration(int? seconds) {
    return Formatters.formatDuration(seconds);
  }

  /// Formats start and end battery transition (e.g., "41% -> 80%").
  /// Returns "-" when both are null.
  static String formatBatteryTransition(double? start, double? end) {
    if (start == null && end == null) return '-';
    final s = start != null ? '${start.round()}%' : '-';
    final e = end != null ? '${end.round()}%' : '-';
    return '$s -> $e';
  }

  /// Human-readable schedule summary text.
  /// Examples: "22:00 - 06:00, Mon-Fri", "22:00 - 06:00, Every day", "No schedule set".
  static String formatScheduleSummary(ChargingSchedule? schedule) {
    if (schedule == null || !schedule.enabled) {
      return 'No schedule set';
    }

    final startStr = schedule.startTime?.toApi() ?? '--:--';
    final endStr = schedule.endTime?.toApi() ?? '--:--';
    final timeStr = '$startStr - $endStr';

    final days = schedule.daysOfWeek;
    if (days.isEmpty) {
      return timeStr;
    }

    final allDays = {
      DayOfWeek.mon,
      DayOfWeek.tue,
      DayOfWeek.wed,
      DayOfWeek.thu,
      DayOfWeek.fri,
      DayOfWeek.sat,
      DayOfWeek.sun,
    };

    final weekdays = {
      DayOfWeek.mon,
      DayOfWeek.tue,
      DayOfWeek.wed,
      DayOfWeek.thu,
      DayOfWeek.fri,
    };

    final weekends = {
      DayOfWeek.sat,
      DayOfWeek.sun,
    };

    String daysStr;
    if (days.containsAll(allDays) && days.length == 7) {
      daysStr = 'Every day';
    } else if (days.containsAll(weekdays) && days.length == 5) {
      daysStr = 'Mon-Fri';
    } else if (days.containsAll(weekends) && days.length == 2) {
      daysStr = 'Weekends';
    } else {
      final ordered = [
        DayOfWeek.mon,
        DayOfWeek.tue,
        DayOfWeek.wed,
        DayOfWeek.thu,
        DayOfWeek.fri,
        DayOfWeek.sat,
        DayOfWeek.sun,
      ].where(days.contains).map((d) => d.shortName).toList();
      daysStr = ordered.join(', ');
    }

    return '$timeStr, $daysStr';
  }
}
