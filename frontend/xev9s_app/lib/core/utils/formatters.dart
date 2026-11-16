import 'package:intl/intl.dart';

/// Formatting utilities for display units, battery levels, and timestamps.
/// Contract rule: Every formatter returns "-" for null and NEVER "0" for null.
class Formatters {
  Formatters._();

  static const String nullPlaceholder = '-';

  /// Formats percentage value, e.g. 80.4 -> "80%".
  static String formatPercent(num? value) {
    if (value == null) return nullPlaceholder;
    return '${value.round()}%';
  }

  /// Formats distance in kilometers, e.g. 14.8 -> "14.8 km".
  static String formatKm(num? value) {
    if (value == null) return nullPlaceholder;
    return '${value.toStringAsFixed(1)} km';
  }

  /// Formats speed in km/h, e.g. 64.9 -> "65 km/h".
  static String formatKmh(num? value) {
    if (value == null) return nullPlaceholder;
    return '${value.round()} km/h';
  }

  /// Formats energy in kilowatt-hours, e.g. 24.4 -> "24.4 kWh".
  static String formatKwh(num? value) {
    if (value == null) return nullPlaceholder;
    return '${value.toStringAsFixed(1)} kWh';
  }

  /// Formats power in kilowatts, e.g. 11.2 -> "11.2 kW".
  static String formatKw(num? value) {
    if (value == null) return nullPlaceholder;
    return '${value.toStringAsFixed(1)} kW';
  }

  /// Formats duration in seconds to human readable form, e.g. 2520 -> "42m", 5400 -> "1h 30m".
  static String formatDuration(num? seconds) {
    if (seconds == null) return nullPlaceholder;
    final totalSeconds = seconds.toInt();
    if (totalSeconds < 0) return nullPlaceholder;
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Formats date and time in localized format, e.g. "Nov 16, 2026 3:30 PM".
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return nullPlaceholder;
    return DateFormat('MMM d, yyyy h:mm a').format(dateTime.toLocal());
  }

  /// Formats relative time from a reference clock, e.g. "Just now", "5m ago", "2h ago".
  static String formatRelative(DateTime? dateTime, {DateTime? clock}) {
    if (dateTime == null) return nullPlaceholder;
    final now = clock ?? DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime.toLocal());
    }
  }

  // Backward compatibility aliases
  static String formatDistance(double? km) => formatKm(km);
  static String formatBattery(double? percent) => formatPercent(percent);
  static String formatSpeed(double? speedKmh) => formatKmh(speedKmh);
  static String formatPower(double? powerKw) => formatKw(powerKw);
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return nullPlaceholder;
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }
}
