import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/charging/domain/charging_schedule.dart';
import 'package:xev9s_app/features/charging/domain/day_of_week.dart';
import 'package:xev9s_app/features/charging/presentation/charging_display_helpers.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('ChargingDisplayHelpers.stateLabel', () {
    test('returns exact specification labels for all six states and unknown', () {
      expect(ChargingDisplayHelpers.stateLabel(ChargingState.notConnected), 'Not plugged in');
      expect(ChargingDisplayHelpers.stateLabel(ChargingState.connected), 'Plugged in - not charging');
      expect(ChargingDisplayHelpers.stateLabel(ChargingState.charging), 'Charging');
      expect(ChargingDisplayHelpers.stateLabel(ChargingState.paused), 'Paused');
      expect(ChargingDisplayHelpers.stateLabel(ChargingState.completed), 'Charging complete');
      expect(ChargingDisplayHelpers.stateLabel(ChargingState.interrupted), 'Interrupted');
      expect(ChargingDisplayHelpers.stateLabel(ChargingState.unknown), 'Status unavailable');
    });
  });

  group('ChargingDisplayHelpers formatters', () {
    test('formats battery percentage with null returning "-"', () {
      expect(ChargingDisplayHelpers.formatBattery(null), '-');
      expect(ChargingDisplayHelpers.formatBattery(64.2), '64%');
      expect(ChargingDisplayHelpers.formatBattery(100.0), '100%');
    });

    test('formats power in kW with null returning "-"', () {
      expect(ChargingDisplayHelpers.formatPower(null), '-');
      expect(ChargingDisplayHelpers.formatPower(11.23), '11.2 kW');
      expect(ChargingDisplayHelpers.formatPower(0.0), '0.0 kW');
    });

    test('formats duration in seconds with null returning "-"', () {
      expect(ChargingDisplayHelpers.formatDuration(null), '-');
      expect(ChargingDisplayHelpers.formatDuration(2520), '42m');
      expect(ChargingDisplayHelpers.formatDuration(5400), '1h 30m');
    });

    test('formats battery transition string', () {
      expect(ChargingDisplayHelpers.formatBatteryTransition(null, null), '-');
      expect(ChargingDisplayHelpers.formatBatteryTransition(41.2, 80.0), '41% -> 80%');
      expect(ChargingDisplayHelpers.formatBatteryTransition(null, 80.0), '- -> 80%');
      expect(ChargingDisplayHelpers.formatBatteryTransition(41.0, null), '41% -> -');
    });
  });

  group('ChargingDisplayHelpers.formatScheduleSummary', () {
    test('returns "No schedule set" for null or disabled schedule', () {
      expect(ChargingDisplayHelpers.formatScheduleSummary(null), 'No schedule set');
      expect(
        ChargingDisplayHelpers.formatScheduleSummary(
          const ChargingSchedule(enabled: false),
        ),
        'No schedule set',
      );
    });

    test('formats weekdays schedule', () {
      const schedule = ChargingSchedule(
        enabled: true,
        startTime: ScheduleTime(hour: 22, minute: 0),
        endTime: ScheduleTime(hour: 6, minute: 0),
        daysOfWeek: {
          DayOfWeek.mon,
          DayOfWeek.tue,
          DayOfWeek.wed,
          DayOfWeek.thu,
          DayOfWeek.fri,
        },
      );
      expect(
        ChargingDisplayHelpers.formatScheduleSummary(schedule),
        '22:00 - 06:00, Mon-Fri',
      );
    });

    test('formats every day schedule', () {
      const schedule = ChargingSchedule(
        enabled: true,
        startTime: ScheduleTime(hour: 1, minute: 30),
        endTime: ScheduleTime(hour: 5, minute: 0),
        daysOfWeek: {
          DayOfWeek.mon,
          DayOfWeek.tue,
          DayOfWeek.wed,
          DayOfWeek.thu,
          DayOfWeek.fri,
          DayOfWeek.sat,
          DayOfWeek.sun,
        },
      );
      expect(
        ChargingDisplayHelpers.formatScheduleSummary(schedule),
        '01:30 - 05:00, Every day',
      );
    });

    test('formats weekends schedule', () {
      const schedule = ChargingSchedule(
        enabled: true,
        startTime: ScheduleTime(hour: 20, minute: 0),
        endTime: ScheduleTime(hour: 23, minute: 0),
        daysOfWeek: {DayOfWeek.sat, DayOfWeek.sun},
      );
      expect(
        ChargingDisplayHelpers.formatScheduleSummary(schedule),
        '20:00 - 23:00, Weekends',
      );
    });
  });
}
