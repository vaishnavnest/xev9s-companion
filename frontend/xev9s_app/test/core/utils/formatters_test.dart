import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('null safety (contract rule: always "-" and never "0")', () {
      test('all formatters return "-" when value is null', () {
        expect(Formatters.formatPercent(null), equals('-'));
        expect(Formatters.formatKm(null), equals('-'));
        expect(Formatters.formatKmh(null), equals('-'));
        expect(Formatters.formatKwh(null), equals('-'));
        expect(Formatters.formatKw(null), equals('-'));
        expect(Formatters.formatDuration(null), equals('-'));
        expect(Formatters.formatDateTime(null), equals('-'));
        expect(Formatters.formatRelative(null), equals('-'));
      });
    });

    group('formatPercent', () {
      test('formats normal and rounded percentage', () {
        expect(Formatters.formatPercent(80), equals('80%'));
        expect(Formatters.formatPercent(64.6), equals('65%'));
        expect(Formatters.formatPercent(64.2), equals('64%'));
        expect(Formatters.formatPercent(0), equals('0%'));
      });
    });

    group('formatKm', () {
      test('formats distance with 1 decimal place', () {
        expect(Formatters.formatKm(312.5), equals('312.5 km'));
        expect(Formatters.formatKm(14), equals('14.0 km'));
        expect(Formatters.formatKm(0), equals('0.0 km'));
      });
    });

    group('formatKmh', () {
      test('formats speed rounded to nearest integer', () {
        expect(Formatters.formatKmh(64.8), equals('65 km/h'));
        expect(Formatters.formatKmh(0), equals('0 km/h'));
      });
    });

    group('formatKwh', () {
      test('formats energy with 1 decimal place', () {
        expect(Formatters.formatKwh(24.4), equals('24.4 kWh'));
        expect(Formatters.formatKwh(2.93), equals('2.9 kWh'));
      });
    });

    group('formatKw', () {
      test('formats power with 1 decimal place', () {
        expect(Formatters.formatKw(11.2), equals('11.2 kW'));
        expect(Formatters.formatKw(50), equals('50.0 kW'));
      });
    });

    group('formatDuration', () {
      test('formats minutes and hours', () {
        expect(Formatters.formatDuration(2520), equals('42m'));
        expect(Formatters.formatDuration(5400), equals('1h 30m'));
        expect(Formatters.formatDuration(3600), equals('1h 0m'));
        expect(Formatters.formatDuration(0), equals('0m'));
        expect(Formatters.formatDuration(-10), equals('-'));
      });
    });

    group('formatDateTime and formatRelative', () {
      test('formatDateTime formats correctly', () {
        final dt = DateTime.utc(2026, 11, 16, 9, 30);
        final formatted = Formatters.formatDateTime(dt);
        expect(formatted, isNotEmpty);
        expect(formatted, isNot(equals('-')));
      });

      test('formatRelative formats according to elapsed duration', () {
        final now = DateTime(2026, 11, 16, 12, 0, 0);

        expect(
          Formatters.formatRelative(DateTime(2026, 11, 16, 11, 59, 30), clock: now),
          equals('Just now'),
        );
        expect(
          Formatters.formatRelative(DateTime(2026, 11, 16, 11, 50, 0), clock: now),
          equals('10m ago'),
        );
        expect(
          Formatters.formatRelative(DateTime(2026, 11, 16, 9, 0, 0), clock: now),
          equals('3h ago'),
        );
        expect(
          Formatters.formatRelative(DateTime(2026, 11, 14, 12, 0, 0), clock: now),
          equals('2d ago'),
        );
      });
    });
  });
}
