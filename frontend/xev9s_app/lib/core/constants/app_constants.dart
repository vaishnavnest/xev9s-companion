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

  /// Minimum charging target percentage (UC-04).
  static const int chargingTargetMin = 20;

  /// Maximum charging target percentage (UC-04).
  static const int chargingTargetMax = 100;

  /// Slider step size for charging target selection.
  static const int chargingTargetStep = 5;

  /// Default page size for charging sessions history pagination.
  static const int sessionsPageSize = 20;

  /// Polling interval for remote commands when using polling realtime mode or fallback (UC-05).
  static const int commandPollIntervalSeconds = 2;

  /// Silence duration on websocket stream before falling back to safety polling (UC-05).
  static const int commandSilenceBeforeSafetyPollSeconds = 8;

  /// Time after which UI indicates a command is taking longer than expected (UC-05).
  static const int commandClientWaitLimitSeconds = 60;

  /// Window within which an active command is resumed on page build / vehicle change (UC-05).
  static const int commandResumeWindowMinutes = 5;

  /// Default page size for remote commands history pagination (UC-05).
  static const int commandsPageSize = 20;
}
