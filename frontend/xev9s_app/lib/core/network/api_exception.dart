import 'package:equatable/equatable.dart';
import 'api_response.dart';
import 'error_codes.dart';

/// Discriminator that lets the UI distinguish the category of error without
/// inspecting the raw [ApiErrorCode] or error message string.
enum AppErrorKind {
  /// A structured error returned by the server (success=false with an error payload).
  api,

  /// No network connection was available.
  noConnection,

  /// The request timed out before the server responded.
  timeout,

  /// The server returned a response that did not match the expected envelope.
  malformed,
}

/// Normalized domain exception thrown across the networking layer.
class AppError extends Equatable implements Exception {
  const AppError({
    required this.code,
    required this.message,
    this.kind = AppErrorKind.api,
    this.details = const [],
    this.retryable = false,
    this.httpStatus,
  });

  final ApiErrorCode code;
  final String message;

  /// High-level kind, useful for UI branching without inspecting [code].
  final AppErrorKind kind;

  final List<ApiErrorDetail> details;
  final bool retryable;
  final int? httpStatus;

  /// Extracts structured field validation issues as a field -> message map
  /// for easy attachment to form input fields.
  Map<String, String> get fieldErrors {
    final map = <String, String>{};
    for (final detail in details) {
      if (detail.field.isNotEmpty) {
        map[detail.field] = detail.issue;
      }
    }
    return map;
  }

  /// User-friendly message tailored for UI display.
  /// Never surfaces raw exception strings, stack traces, or raw error codes.
  String get displayMessage {
    // Network-layer kinds get distinct friendly messages regardless of code.
    switch (kind) {
      case AppErrorKind.noConnection:
        return "Can't reach the server. Check your connection and try again.";
      case AppErrorKind.timeout:
        return 'The server took too long to respond. Please try again.';
      case AppErrorKind.malformed:
        return 'Received an unexpected response from the server. Please try again.';
      case AppErrorKind.api:
        break;
    }

    switch (code) {
      case ApiErrorCode.invalidCredentials:
        return 'Incorrect email or password.';
      case ApiErrorCode.duplicateEmail:
        return 'An account with this email already exists.';
      case ApiErrorCode.vehicleNotFound:
        return "We couldn't find a vehicle with that identifier.";
      case ApiErrorCode.vehicleAlreadyAssociated:
        return 'This vehicle is already linked to an account.';
      case ApiErrorCode.validationError:
        if (message.isNotEmpty && message != 'VALIDATION_ERROR') {
          return message;
        }
        return 'Please check the highlighted fields.';
      case ApiErrorCode.rateLimited:
        return 'Too many attempts. Please wait a moment and try again.';
      case ApiErrorCode.tokenExpired:
      case ApiErrorCode.unauthenticated:
        return 'Your session has expired. Please sign in again.';
      case ApiErrorCode.forbidden:
      case ApiErrorCode.vehicleAccessDenied:
        return 'You do not have permission to access this vehicle or resource.';
      case ApiErrorCode.vehicleOffline:
        return 'Vehicle is currently offline. Showing last reported data.';
      case ApiErrorCode.commandInProgress:
        return 'Another command is currently in progress. Please wait.';
      case ApiErrorCode.chargingTargetNotApplicable:
        return 'Unable to update charging target in current state.';
      case ApiErrorCode.notFound:
        return 'Requested vehicle or resource was not found.';
      case ApiErrorCode.internalError:
      case ApiErrorCode.serviceUnavailable:
        return 'Something went wrong on our side. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
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
      kind: AppErrorKind.api,
      message: message,
      details: details,
      retryable: retryable,
      httpStatus: httpStatus,
    );
  }

  factory AppError.unknown(String message,
      {int? httpStatus, bool retryable = false}) {
    return AppError(
      code: ApiErrorCode.unknown,
      kind: AppErrorKind.api,
      message: message,
      httpStatus: httpStatus,
      retryable: retryable,
    );
  }

  factory AppError.noConnection([String? message]) {
    return AppError(
      code: ApiErrorCode.unknown,
      kind: AppErrorKind.noConnection,
      message: message ??
          'No network connection. Please check your internet connectivity.',
      retryable: true,
    );
  }

  factory AppError.timeout([String? message]) {
    return AppError(
      code: ApiErrorCode.unknown,
      kind: AppErrorKind.timeout,
      message:
          message ?? 'Request timed out. Please check your connection and try again.',
      retryable: true,
    );
  }

  factory AppError.malformedResponse([String? message]) {
    return AppError(
      code: ApiErrorCode.unknown,
      kind: AppErrorKind.malformed,
      message: message != null
          ? 'Received an unexpected response from the server: $message'
          : 'Received an unexpected response from the server.',
      retryable: false,
    );
  }

  @override
  String toString() =>
      'AppError(kind: $kind, code: ${code.wireValue}, httpStatus: $httpStatus, message: $message, retryable: $retryable)';

  @override
  List<Object?> get props => [code, kind, message, details, retryable, httpStatus];
}
