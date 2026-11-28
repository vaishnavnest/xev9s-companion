/// Days of the week for recurring schedules.
enum DayOfWeek {
  mon('MON', 'Mon'),
  tue('TUE', 'Tue'),
  wed('WED', 'Wed'),
  thu('THU', 'Thu'),
  fri('FRI', 'Fri'),
  sat('SAT', 'Sat'),
  sun('SUN', 'Sun'),
  unknown('UNKNOWN', 'Unknown');

  const DayOfWeek(this.wireValue, this.shortName);

  final String wireValue;
  final String shortName;

  String toApi() => wireValue;

  /// Lowercase full weekday name expected by the FastAPI backend `Weekday` enum.
  String toBackendWeekday() {
    switch (this) {
      case DayOfWeek.mon:
        return 'monday';
      case DayOfWeek.tue:
        return 'tuesday';
      case DayOfWeek.wed:
        return 'wednesday';
      case DayOfWeek.thu:
        return 'thursday';
      case DayOfWeek.fri:
        return 'friday';
      case DayOfWeek.sat:
        return 'saturday';
      case DayOfWeek.sun:
        return 'sunday';
      case DayOfWeek.unknown:
        return 'unknown';
    }
  }

  static DayOfWeek fromApi(String? value) {
    if (value == null || value.trim().isEmpty) return DayOfWeek.unknown;
    final normalized = value.trim().toUpperCase();
    for (final day in DayOfWeek.values) {
      if (day.wireValue == normalized ||
          day.toBackendWeekday().toUpperCase() == normalized) {
        return day;
      }
    }
    return DayOfWeek.unknown;
  }
}
