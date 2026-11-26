/// Error codes defined in the XEV 9S Companion OpenAPI contract.
enum ApiErrorCode {
  validationError('VALIDATION_ERROR'),
  invalidCredentials('INVALID_CREDENTIALS'),
  tokenExpired('TOKEN_EXPIRED'),
  unauthenticated('UNAUTHENTICATED'),
  forbidden('FORBIDDEN'),
  vehicleAccessDenied('VEHICLE_ACCESS_DENIED'),
  notFound('NOT_FOUND'),
  vehicleNotFound('VEHICLE_NOT_FOUND'),
  vehicleAlreadyAssociated('VEHICLE_ALREADY_ASSOCIATED'),
  duplicateEmail('DUPLICATE_EMAIL'),
  commandInProgress('COMMAND_IN_PROGRESS'),
  reportNotReady('REPORT_NOT_READY'),
  scenarioAlreadyRunning('SCENARIO_ALREADY_RUNNING'),
  vehicleOffline('VEHICLE_OFFLINE'),
  invalidCommandState('INVALID_COMMAND_STATE'),
  chargingTargetNotApplicable('CHARGING_TARGET_NOT_APPLICABLE'),
  rateLimited('RATE_LIMITED'),
  internalError('INTERNAL_ERROR'),
  serviceUnavailable('SERVICE_UNAVAILABLE'),
  unknown('UNKNOWN');

  const ApiErrorCode(this.wireValue);

  final String wireValue;

  /// Safe parser: converts raw string to [ApiErrorCode], returning [unknown] if unrecognized.
  static ApiErrorCode fromString(String? value) {
    if (value == null || value.isEmpty) {
      return ApiErrorCode.unknown;
    }
    for (final code in ApiErrorCode.values) {
      if (code.wireValue.equalsIgnoreCase(value)) {
        return code;
      }
    }
    return ApiErrorCode.unknown;
  }

  /// Maps an HTTP status code to an appropriate [ApiErrorCode] fallback.
  /// If [message] is provided, checks for common error details (e.g. incorrect credentials).
  static ApiErrorCode fromHttpStatus(int? status, [String? message]) {
    if (status == 401) {
      if (message != null &&
          (message.toLowerCase().contains('incorrect') ||
              message.toLowerCase().contains('invalid credential') ||
              message.toLowerCase().contains('password'))) {
        return ApiErrorCode.invalidCredentials;
      }
      return ApiErrorCode.unauthenticated;
    }
    if (status == 409) {
      final lower = message?.toLowerCase() ?? '';
      if (lower.contains('offline') || lower.contains('telemetry')) {
        return ApiErrorCode.vehicleOffline;
      }
      if (lower.contains('command') || lower.contains('progress')) {
        return ApiErrorCode.commandInProgress;
      }
      return ApiErrorCode.duplicateEmail;
    }
    return switch (status) {
      400 => ApiErrorCode.validationError,
      403 => ApiErrorCode.forbidden,
      404 => ApiErrorCode.notFound,
      422 => ApiErrorCode.validationError,
      503 => ApiErrorCode.serviceUnavailable,
      _ => ApiErrorCode.unknown,
    };
  }
}

extension _StringCaseExtension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}
