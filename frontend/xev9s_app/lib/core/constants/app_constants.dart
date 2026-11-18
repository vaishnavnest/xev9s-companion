/// Application-wide constants. Single source of truth for constraints.
class AppConstants {
  AppConstants._();

  /// Minimum allowed password length.
  static const int minPasswordLength = 8;

  /// Maximum allowed password length.
  static const int maxPasswordLength = 128;

  /// Expected length of the vehicle pairing code (digits).
  static const int pairingCodeLength = 6;

  /// Maximum allowed user full name length.
  static const int maxNameLength = 100;

  /// Threshold percentage below which battery level is considered WARNING.
  static const double lowBatteryWarningPercent = 20.0;
}
