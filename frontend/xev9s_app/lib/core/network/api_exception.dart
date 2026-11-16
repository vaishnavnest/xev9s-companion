import 'package:equatable/equatable.dart';
import 'api_response.dart';
import 'error_codes.dart';

/// Normalized domain exception thrown across the networking layer.
class AppError extends Equatable implements Exception {
  const AppError({
    required this.code,
    required this.message,
    this.details = const [],
    this.retryable = false,
    this.httpStatus,
  });

  final ApiErrorCode code;
  final String message;
  final List<ApiErrorDetail> details;
  final bool retryable;
  final int? httpStatus;

  /// User-friendly message tailored for UI display.
  String get displayMessage {
    switch (code) {
      case ApiErrorCode.invalidCredentials:
        return 'Invalid email or password. Please try again.';
      case ApiErrorCode.tokenExpired:
      case ApiErrorCode.unauthenticated:
        return 'Session expired. Please sign in again.';
      case ApiErrorCode.forbidden:
      case ApiErrorCode.vehicleAccessDenied:
        return 'You do not have permission to access this vehicle or resource.';
      case ApiErrorCode.vehicleOffline:
        return 'Vehicle is currently offline. Showing last reported data.';
      case ApiErrorCode.vehicleNotFound:
      case ApiErrorCode.notFound:
        return 'Requested vehicle or resource was not found.';
      case ApiErrorCode.commandInProgress:
        return 'Another command is currently in progress. Please wait.';
      case ApiErrorCode.chargingTargetNotApplicable:
        return 'Unable to update charging target in current state.';
      case ApiErrorCode.rateLimited:
        return 'Too many requests. Please wait a moment before trying again.';
      case ApiErrorCode.serviceUnavailable:
        return 'Service is temporarily unavailable. Please try again later.';
      case ApiErrorCode.internalError:
        return 'Server error occurred. Please try again later.';
      default:
        if (message.isNotEmpty) return message;
        return 'An unexpected error occurred. Please try again.';
    }
  }

  factory AppError.fromApiResponseError(
    Map<String, dynamic> errorJson, {
    int? httpStatus,
  }) {
    final codeStr = errorJson['code'] as String?;
    final message = errorJson['message'] as String? ?? 'An error occurred';
    final retryable = errorJson['retryable'] as bool? ?? false;
    final rawDetails = errorJson['details'] as List<dynamic>? ?? [];

    final details = rawDetails
        .whereType<Map<String, dynamic>>()
        .map((d) => ApiErrorDetail.fromJson(d))
        .toList();

    return AppError(
      code: ApiErrorCode.fromString(codeStr),
      message: message,
      details: details,
      retryable: retryable,
      httpStatus: httpStatus,
    );
  }

  factory AppError.unknown(String message, {int? httpStatus, bool retryable = false}) {
    return AppError(
      code: ApiErrorCode.unknown,
      message: message,
      httpStatus: httpStatus,
      retryable: retryable,
    );
  }

  factory AppError.noConnection([String? message]) {
    return AppError(
      code: ApiErrorCode.unknown,
      message: message ?? 'No network connection. Please check your internet connectivity.',
      retryable: true,
    );
  }

  factory AppError.timeout([String? message]) {
    return AppError(
      code: ApiErrorCode.unknown,
      message: message ?? 'Request timed out. Please check your connection and try again.',
      retryable: true,
    );
  }

  factory AppError.malformedResponse([String? message]) {
    return AppError(
      code: ApiErrorCode.unknown,
      message: message ?? 'Received an unexpected response from the server.',
      retryable: false,
    );
  }

  @override
  String toString() =>
      'AppError(code: ${code.wireValue}, httpStatus: $httpStatus, message: $message, retryable: $retryable)';

  @override
  List<Object?> get props => [code, message, details, retryable, httpStatus];
}
