import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/constants/app_constants.dart';
import 'package:xev9s_app/core/utils/validators.dart';
import 'package:xev9s_app/features/charging/domain/day_of_week.dart';

void main() {
  group('Validators.chargingTarget', () {
    test('rejects null values', () {
      expect(Validators.chargingTarget(null), isNotNull);
    });

    test('rejects targets strictly below minimum (19%)', () {
      expect(
        Validators.chargingTarget(19),
        'Target must be between ${AppConstants.chargingTargetMin}% and ${AppConstants.chargingTargetMax}%.',
      );
    });

    test('accepts edge minimum (20%)', () {
      expect(Validators.chargingTarget(20), isNull);
    });

    test('accepts mid-range target (80%)', () {
      expect(Validators.chargingTarget(80), isNull);
    });

    test('accepts edge maximum (100%)', () {
      expect(Validators.chargingTarget(100), isNull);
    });

    test('rejects targets strictly above maximum (101%)', () {
      expect(
        Validators.chargingTarget(101),
        'Target must be between ${AppConstants.chargingTargetMin}% and ${AppConstants.chargingTargetMax}%.',
      );
    });
  });

  group('Validators.scheduleTimes', () {
    test('requires both start and end times', () {
      expect(Validators.scheduleTimes(null, '06:00'), isNotNull);
      expect(Validators.scheduleTimes('22:00', null), isNotNull);
      expect(Validators.scheduleTimes('', '06:00'), isNotNull);
      expect(Validators.scheduleTimes('22:00', ''), isNotNull);
    });

    test('rejects identical start and end times', () {
      expect(
        Validators.scheduleTimes('22:00', '22:00'),
        'Start time and end time cannot be the same.',
      );
    });

    test('accepts daytime charging window', () {
      expect(Validators.scheduleTimes('10:00', '16:00'), isNull);
    });

    test('accepts overnight charging window (22:00 to 06:00)', () {
      expect(Validators.scheduleTimes('22:00', '06:00'), isNull);
    });
  });

  group('Validators.scheduleDays', () {
    test('requires at least one day when schedule is enabled', () {
      expect(
        Validators.scheduleDays(<DayOfWeek>{}, true),
        'Please select at least one day for the schedule.',
      );
      expect(
        Validators.scheduleDays(null, true),
        'Please select at least one day for the schedule.',
      );
    });

    test('accepts non-empty days when schedule is enabled', () {
      expect(
        Validators.scheduleDays({DayOfWeek.mon, DayOfWeek.tue}, true),
        isNull,
      );
    });

    test('allows empty days when schedule is disabled', () {
      expect(Validators.scheduleDays(<DayOfWeek>{}, false), isNull);
      expect(Validators.scheduleDays(null, false), isNull);
    });
  });
}
