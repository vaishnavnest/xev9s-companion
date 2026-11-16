import 'package:intl/intl.dart';

/// Formatting utilities for display units, battery levels, and timestamps.
class Formatters {
  Formatters._();

  static String formatDistance(double? km) {
    if (km == null) return '--';
    return '${km.toStringAsFixed(1)} km';
  }

  static String formatBattery(double? percent) {
    if (percent == null) return '--';
    return '${percent.round()}%';
  }

  static String formatSpeed(double? speedKmh) {
    if (speedKmh == null) return '--';
    return '${speedKmh.round()} km/h';
  }

  static String formatPower(double? powerKw) {
    if (powerKw == null) return '--';
    return '${powerKw.toStringAsFixed(1)} kW';
  }

  static String formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('MMM d, yyyy h:mm a').format(dateTime.toLocal());
  }

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }
}
