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

  /// Simple and permissive email validator:
  /// - trimmed input
  /// - contains no whitespace
  /// - contains exactly one '@'
  /// - '@' is not first or last character
  /// - domain part contains at least one '.' with non-empty parts
  static String? email(String? value) {
    if (value == null) {
      return 'Email is required.';
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }

    if (trimmed.contains(' ')) {
      return 'Please enter a valid email address.';
    }

    final atParts = trimmed.split('@');
    if (atParts.length != 2) {
      return 'Please enter a valid email address.';
    }

    final local = atParts[0];
    final domain = atParts[1];

    if (local.isEmpty || domain.isEmpty) {
      return 'Please enter a valid email address.';
    }

    if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) {
      return 'Please enter a valid email address.';
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
