import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/charging/domain/charging_overview.dart';
import 'package:xev9s_app/features/charging/domain/charging_schedule.dart';
import 'package:xev9s_app/features/charging/domain/charging_session.dart';
import 'package:xev9s_app/features/charging/domain/day_of_week.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

void main() {
  group('DayOfWeek enum', () {
    test('maps to and from API wire format', () {
      expect(DayOfWeek.mon.toApi(), 'MON');
      expect(DayOfWeek.tue.toApi(), 'TUE');
      expect(DayOfWeek.wed.toApi(), 'WED');
      expect(DayOfWeek.thu.toApi(), 'THU');
      expect(DayOfWeek.fri.toApi(), 'FRI');
      expect(DayOfWeek.sat.toApi(), 'SAT');
      expect(DayOfWeek.sun.toApi(), 'SUN');
      expect(DayOfWeek.unknown.toApi(), 'UNKNOWN');

      expect(DayOfWeek.fromApi('MON'), DayOfWeek.mon);
      expect(DayOfWeek.fromApi('mon'), DayOfWeek.mon);
      expect(DayOfWeek.fromApi('FRI'), DayOfWeek.fri);
      expect(DayOfWeek.fromApi('INVALID'), DayOfWeek.unknown);
      expect(DayOfWeek.fromApi(null), DayOfWeek.unknown);
    });
  });

  group('ScheduleTime value object', () {
    test('parses zero-padded and valid 24h strings', () {
      final t1 = ScheduleTime.parse('22:00');
      expect(t1.hour, 22);
      expect(t1.minute, 0);
      expect(t1.toApi(), '22:00');

      final t2 = ScheduleTime.parse('06:05');
      expect(t2.hour, 6);
      expect(t2.minute, 5);
      expect(t2.toApi(), '06:05');
    });

    test('throws FormatException on malformed time strings', () {
      expect(() => ScheduleTime.parse('25:00'), throwsFormatException);
      expect(() => ScheduleTime.parse('12:60'), throwsFormatException);
      expect(() => ScheduleTime.parse('8:30'), throwsFormatException);
      expect(() => ScheduleTime.parse('invalid'), throwsFormatException);
      expect(() => ScheduleTime.parse(''), throwsFormatException);
    });

    test('tryParse safely handles null and invalid strings', () {
      expect(ScheduleTime.tryParse(null), isNull);
      expect(ScheduleTime.tryParse('invalid'), isNull);
      expect(ScheduleTime.tryParse('14:30'), const ScheduleTime(hour: 14, minute: 30));
    });
  });

  group('ChargingSchedule model', () {
    test('fromJson and toJson with zero-padded times and day mapping', () {
      final json = {
        'enabled': true,
        'startTime': '22:00',
        'endTime': '06:00',
        'daysOfWeek': ['MON', 'TUE', 'WED', 'THU', 'FRI'],
      };

      final schedule = ChargingSchedule.fromJson(json);
      expect(schedule.enabled, isTrue);
      expect(schedule.startTime, const ScheduleTime(hour: 22, minute: 0));
      expect(schedule.endTime, const ScheduleTime(hour: 6, minute: 0));
      expect(schedule.daysOfWeek, {
        DayOfWeek.mon,
        DayOfWeek.tue,
        DayOfWeek.wed,
        DayOfWeek.thu,
        DayOfWeek.fri,
      });

      final serialized = schedule.toJson();
      expect(serialized['enabled'], isTrue);
      expect(serialized['startTime'], '22:00');
      expect(serialized['endTime'], '06:00');
      expect(serialized['daysOfWeek'], ['MON', 'TUE', 'WED', 'THU', 'FRI']);
    });

    test('handles empty and null fields gracefully', () {
      final schedule = ChargingSchedule.fromJson({'enabled': false});
      expect(schedule.enabled, isFalse);
      expect(schedule.startTime, isNull);
      expect(schedule.endTime, isNull);
      expect(schedule.daysOfWeek, isEmpty);
    });

    test('throws FormatException if time strings in json are malformed', () {
      expect(
        () => ChargingSchedule.fromJson({'enabled': true, 'startTime': 'invalid'}),
        throwsFormatException,
      );
    });
  });

  group('ChargingOverview model', () {
    test('deserializes complete json payload', () {
      final json = {
        'state': 'CHARGING',
        'batteryPercent': 64.0,
        'targetPercent': 80,
        'powerKw': 11.2,
        'sessionDurationSeconds': 1260,
        'schedule': {
          'enabled': true,
          'startTime': '22:00',
          'endTime': '06:00',
          'daysOfWeek': ['MON', 'FRI'],
        },
        'currentSessionId': 'chs_0042',
      };

      final overview = ChargingOverview.fromJson(json);
      expect(overview.state, ChargingState.charging);
      expect(overview.batteryPercent, 64.0);
      expect(overview.targetPercent, 80);
      expect(overview.powerKw, 11.2);
      expect(overview.sessionDurationSeconds, 1260);
      expect(overview.schedule?.enabled, isTrue);
      expect(overview.currentSessionId, 'chs_0042');

      final serialized = overview.toJson();
      expect(serialized['state'], 'CHARGING');
      expect(serialized['batteryPercent'], 64.0);
      expect(serialized['targetPercent'], 80);
      expect(serialized['powerKw'], 11.2);
    });

    test('handles nulls and unknown charging state', () {
      final overview = ChargingOverview.fromJson({'state': 'SOME_NEW_STATE'});
      expect(overview.state, ChargingState.unknown);
      expect(overview.batteryPercent, isNull);
      expect(overview.targetPercent, isNull);
      expect(overview.powerKw, isNull);
      expect(overview.sessionDurationSeconds, isNull);
      expect(overview.schedule, isNull);
      expect(overview.currentSessionId, isNull);
    });
  });

  group('ChargingSession model', () {
    test('evaluates isActive, isCompleted, isInterrupted correctly', () {
      final active = ChargingSession(
        sessionId: 's1',
        vehicleId: 'v1',
        startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
        endedAt: null,
        status: ChargingState.charging,
      );
      expect(active.isActive, isTrue);
      expect(active.isCompleted, isFalse);
      expect(active.isInterrupted, isFalse);

      final completed = ChargingSession(
        sessionId: 's2',
        vehicleId: 'v1',
        startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
        endedAt: DateTime.parse('2026-11-20T12:00:00Z'),
        status: ChargingState.completed,
      );
      expect(completed.isActive, isFalse);
      expect(completed.isCompleted, isTrue);
      expect(completed.isInterrupted, isFalse);

      final interrupted = ChargingSession(
        sessionId: 's3',
        vehicleId: 'v1',
        startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
        endedAt: DateTime.parse('2026-11-20T10:30:00Z'),
        status: ChargingState.interrupted,
        interruptionReason: 'Connector unlatched',
      );
      expect(interrupted.isActive, isFalse);
      expect(interrupted.isCompleted, isFalse);
      expect(interrupted.isInterrupted, isTrue);
    });

    test('deserializes and serializes session json', () {
      final json = {
        'sessionId': 'chs_101',
        'vehicleId': 'veh_9S0001',
        'startedAt': '2026-11-20T10:00:00.000Z',
        'endedAt': '2026-11-20T11:45:00.000Z',
        'durationSeconds': 6300,
        'startBatteryPercent': 20.0,
        'endBatteryPercent': 80.0,
        'targetPercent': 80,
        'avgPowerKw': 10.8,
        'maxPowerKw': 11.2,
        'status': 'COMPLETED',
      };

      final session = ChargingSession.fromJson(json);
      expect(session.sessionId, 'chs_101');
      expect(session.startBatteryPercent, 20.0);
      expect(session.endBatteryPercent, 80.0);
      expect(session.status, ChargingState.completed);

      final serialized = session.toJson();
      expect(serialized['sessionId'], 'chs_101');
      expect(serialized['status'], 'COMPLETED');
    });
  });
}
