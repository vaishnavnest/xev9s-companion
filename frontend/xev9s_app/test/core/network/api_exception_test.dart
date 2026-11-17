import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';

void main() {
  group('AppError', () {
    test('creates from API error envelope json', () {
      final errorJson = {
        'code': 'VALIDATION_ERROR',
        'message': 'Invalid input',
        'retryable': false,
        'details': [
          {'field': 'targetPercent', 'issue': 'OUT_OF_RANGE'},
        ],
      };

      final error = AppError.fromApiResponseError(errorJson, httpStatus: 400);

      expect(error.code, equals(ApiErrorCode.validationError));
      expect(error.kind, equals(AppErrorKind.api));
      expect(error.message, equals('Invalid input'));
      expect(error.retryable, isFalse);
      expect(error.httpStatus, equals(400));
      expect(error.details.length, equals(1));
      expect(error.details.first.field, equals('targetPercent'));
      expect(error.details.first.issue, equals('OUT_OF_RANGE'));
    });

    test('provides helpful displayMessage based on error code', () {
      final credsError = AppError(
        code: ApiErrorCode.invalidCredentials,
        message: 'Original backend msg',
      );
      expect(
        credsError.displayMessage,
        equals('Invalid email or password. Please try again.'),
      );

      final expiredError = AppError(
        code: ApiErrorCode.tokenExpired,
        message: 'jwt expired',
      );
      expect(
        expiredError.displayMessage,
        equals('Session expired. Please sign in again.'),
      );

      final offlineError = AppError(
        code: ApiErrorCode.vehicleOffline,
        message: 'offline',
      );
      expect(
        offlineError.displayMessage,
        equals('Vehicle is currently offline. Showing last reported data.'),
      );
    });

    test('network helper factories set appropriate kind and properties', () {
      final noConn = AppError.noConnection();
      expect(noConn.kind, equals(AppErrorKind.noConnection));
      expect(noConn.retryable, isTrue);
      expect(noConn.message, contains('internet connectivity'));

      final timeout = AppError.timeout();
      expect(timeout.kind, equals(AppErrorKind.timeout));
      expect(timeout.retryable, isTrue);
      expect(timeout.message, contains('timed out'));

      final malformed = AppError.malformedResponse();
      expect(malformed.kind, equals(AppErrorKind.malformed));
      expect(malformed.retryable, isFalse);
      expect(malformed.message, contains('unexpected response'));
    });

    test('displayMessage for noConnection and timeout have distinct friendly text', () {
      expect(
        AppError.noConnection().displayMessage,
        equals('No internet connection. Please check your network and try again.'),
      );
      expect(
        AppError.timeout().displayMessage,
        equals('The request timed out. Check your connection and try again.'),
      );
      expect(
        AppError.malformedResponse().displayMessage,
        equals('Received an unexpected response from the server. Please try again.'),
      );
    });

    test('fromApiResponseError sets kind to api', () {
      final error = AppError.fromApiResponseError(
        {'code': 'INTERNAL_ERROR', 'message': 'boom'},
      );
      expect(error.kind, equals(AppErrorKind.api));
    });

    test('AppError.unknown sets kind to api', () {
      final error = AppError.unknown('Something went wrong');
      expect(error.kind, equals(AppErrorKind.api));
      expect(error.code, equals(ApiErrorCode.unknown));
    });

    test('props includes kind for equality', () {
      final a = AppError.noConnection();
      final b = AppError.timeout();
      // Both have code=unknown and retryable=true but different kinds.
      expect(a, isNot(equals(b)));
    });
  });
}
