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

    test('network helper factories set appropriate properties', () {
      final noConn = AppError.noConnection();
      expect(noConn.retryable, isTrue);
      expect(noConn.message, contains('internet connectivity'));

      final timeout = AppError.timeout();
      expect(timeout.retryable, isTrue);
      expect(timeout.message, contains('timed out'));

      final malformed = AppError.malformedResponse();
      expect(malformed.retryable, isFalse);
      expect(malformed.message, contains('unexpected response'));
    });
  });
}
