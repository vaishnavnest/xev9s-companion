import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/error_codes.dart';

void main() {
  group('ApiErrorCode', () {
    test('parses exact wire values', () {
      expect(
        ApiErrorCode.fromString('VALIDATION_ERROR'),
        equals(ApiErrorCode.validationError),
      );
      expect(
        ApiErrorCode.fromString('INVALID_CREDENTIALS'),
        equals(ApiErrorCode.invalidCredentials),
      );
      expect(
        ApiErrorCode.fromString('TOKEN_EXPIRED'),
        equals(ApiErrorCode.tokenExpired),
      );
      expect(
        ApiErrorCode.fromString('UNAUTHENTICATED'),
        equals(ApiErrorCode.unauthenticated),
      );
      expect(
        ApiErrorCode.fromString('FORBIDDEN'),
        equals(ApiErrorCode.forbidden),
      );
      expect(
        ApiErrorCode.fromString('VEHICLE_ACCESS_DENIED'),
        equals(ApiErrorCode.vehicleAccessDenied),
      );
      expect(
        ApiErrorCode.fromString('NOT_FOUND'),
        equals(ApiErrorCode.notFound),
      );
      expect(
        ApiErrorCode.fromString('VEHICLE_NOT_FOUND'),
        equals(ApiErrorCode.vehicleNotFound),
      );
      expect(
        ApiErrorCode.fromString('VEHICLE_ALREADY_ASSOCIATED'),
        equals(ApiErrorCode.vehicleAlreadyAssociated),
      );
      expect(
        ApiErrorCode.fromString('DUPLICATE_EMAIL'),
        equals(ApiErrorCode.duplicateEmail),
      );
      expect(
        ApiErrorCode.fromString('COMMAND_IN_PROGRESS'),
        equals(ApiErrorCode.commandInProgress),
      );
      expect(
        ApiErrorCode.fromString('REPORT_NOT_READY'),
        equals(ApiErrorCode.reportNotReady),
      );
      expect(
        ApiErrorCode.fromString('VEHICLE_OFFLINE'),
        equals(ApiErrorCode.vehicleOffline),
      );
      expect(
        ApiErrorCode.fromString('INVALID_COMMAND_STATE'),
        equals(ApiErrorCode.invalidCommandState),
      );
      expect(
        ApiErrorCode.fromString('CHARGING_TARGET_NOT_APPLICABLE'),
        equals(ApiErrorCode.chargingTargetNotApplicable),
      );
      expect(
        ApiErrorCode.fromString('RATE_LIMITED'),
        equals(ApiErrorCode.rateLimited),
      );
      expect(
        ApiErrorCode.fromString('INTERNAL_ERROR'),
        equals(ApiErrorCode.internalError),
      );
      expect(
        ApiErrorCode.fromString('SERVICE_UNAVAILABLE'),
        equals(ApiErrorCode.serviceUnavailable),
      );
    });

    test('is case insensitive', () {
      expect(
        ApiErrorCode.fromString('validation_error'),
        equals(ApiErrorCode.validationError),
      );
      expect(
        ApiErrorCode.fromString('token_expired'),
        equals(ApiErrorCode.tokenExpired),
      );
    });

    test('maps unknown or empty strings safely to unknown without throwing', () {
      expect(ApiErrorCode.fromString(null), equals(ApiErrorCode.unknown));
      expect(ApiErrorCode.fromString(''), equals(ApiErrorCode.unknown));
      expect(
        ApiErrorCode.fromString('COMPLETELY_NEW_ERROR_CODE'),
        equals(ApiErrorCode.unknown),
      );
    });
  });
}
