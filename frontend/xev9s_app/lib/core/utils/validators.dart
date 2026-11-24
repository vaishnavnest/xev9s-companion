import '../constants/app_constants.dart';

/// Pure validation functions returning null when valid or an error string when invalid.
class Validators {
  Validators._();

  /// Validates that [value] is non-null and not empty after trimming.
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  /// User-friendly email validator:
  /// - trimmed input
  /// - contains no whitespace
  /// - contains exactly one '@'
  /// - contains username before '@' and valid domain with '.' after '@'
  static String? email(String? value) {
    if (value == null) {
      return 'Email is required.';
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }

    if (trimmed.contains(' ')) {
      return 'Email address cannot contain spaces.';
    }

    if (!trimmed.contains('@')) {
      return "Please include an '@' in the email address (e.g., name@example.com).";
    }

    final atParts = trimmed.split('@');
    if (atParts.length > 2) {
      return "Email address can only contain one '@'.";
    }

    final local = atParts[0];
    final domain = atParts[1];

    if (local.isEmpty) {
      return "Please enter a username before the '@' (e.g., name@example.com).";
    }

    if (domain.isEmpty) {
      return "Please enter a domain after the '@' (e.g., example.com).";
    }

    if (!domain.contains('.')) {
      return "Please include a domain extension like '.com' (e.g., name@example.com).";
    }

    if (domain.startsWith('.') || domain.endsWith('.')) {
      return 'Please enter a valid domain (e.g., example.com).';
    }

    final domainParts = domain.split('.');
    if (domainParts.any((part) => part.isEmpty)) {
      return 'Please enter a valid domain (e.g., example.com).';
    }

    return null;
  }

  /// Validates charging target percentage against allowed range.
  static String? chargingTarget(int? value) {
    if (value == null) {
      return 'Charging target is required.';
    }
    if (value < AppConstants.chargingTargetMin ||
        value > AppConstants.chargingTargetMax) {
      return 'Target must be between ${AppConstants.chargingTargetMin}% and ${AppConstants.chargingTargetMax}%.';
    }
    return null;
  }

  /// Validates charging schedule start and end times.
  /// Start and end times are required and must not be identical.
  /// Overnight windows (e.g., 22:00 to 06:00) are valid.
  static String? scheduleTimes(dynamic start, dynamic end) {
    if (start == null || end == null) {
      return 'Start time and end time are required.';
    }
    final startStr = start.toString().trim();
    final endStr = end.toString().trim();
    if (startStr.isEmpty || endStr.isEmpty) {
      return 'Start time and end time are required.';
    }
    if (startStr == endStr) {
      return 'Start time and end time cannot be the same.';
    }
    return null;
  }

  /// Validates charging schedule days selection.
  /// When schedule is enabled, at least one day must be selected.
  static String? scheduleDays(Iterable<dynamic>? days, bool enabled) {
    if (enabled && (days == null || days.isEmpty)) {
      return 'Please select at least one day for the schedule.';
    }
    return null;
  }

  /// Validates that [value] has at least [min] characters.
  /// When [trim] is false (e.g. for passwords), leading/trailing whitespace is preserved.
  static String? minLength(
    String? value,
    int min, {
    String fieldName = 'This field',
    bool trim = true,
  }) {
    if (value == null) {
      return '$fieldName must be at least $min characters.';
    }
    final checked = trim ? value.trim() : value;
    if (checked.length < min) {
      return '$fieldName must be at least $min characters.';
    }
    return null;
  }

  /// Password-specific minimum length validator that does NOT trim whitespace.
  static String? password(String? value, [int min = AppConstants.minPasswordLength]) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < min) {
      return 'Password must be at least $min characters.';
    }
    if (value.length > AppConstants.maxPasswordLength) {
      return 'Password must not exceed ${AppConstants.maxPasswordLength} characters.';
    }
    return null;
  }

  /// Validates that [value] does not exceed [max] characters.
  static String? maxLength(
    String? value,
    int max, {
    String fieldName = 'This field',
    bool trim = true,
  }) {
    if (value == null) return null;
    final checked = trim ? value.trim() : value;
    if (checked.length > max) {
      return '$fieldName must not exceed $max characters.';
    }
    return null;
  }

  /// Validates that [value] matches [other]. Untrimmed to preserve password characters.
  static String? matches(String? value, String? other, String message) {
    if (value != other) {
      return message;
    }
    return null;
  }

  /// Validates that [value] consists solely of alphanumeric characters (a-z, A-Z, 0-9).
  static String? alphanumeric(String? value, [String message = 'Must contain only letters and numbers.']) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    final isAlphanumeric = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed);
    if (!isAlphanumeric) {
      return message;
    }
    return null;
  }

  /// Validates that [value] consists solely of ASCII decimal digits (0-9).
  static String? digitsOnly(String? value, [String message = 'Must contain only digits.']) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    final isDigits = RegExp(r'^\d+$').hasMatch(trimmed);
    if (!isDigits) {
      return message;
    }
    return null;
  }

  /// Validates that [value] has an exact length of [length] after trimming.
  static String? exactLength(
    String? value,
    int length, [
    String? message,
  ]) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.length != length) {
      return message ?? 'Must be exactly $length characters.';
    }
    return null;
  }
}
