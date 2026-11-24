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

  static DayOfWeek fromApi(String? value) {
    if (value == null || value.trim().isEmpty) return DayOfWeek.unknown;
    final normalized = value.trim().toUpperCase();
    for (final day in DayOfWeek.values) {
      if (day.wireValue == normalized) return day;
    }
    return DayOfWeek.unknown;
  }
}
