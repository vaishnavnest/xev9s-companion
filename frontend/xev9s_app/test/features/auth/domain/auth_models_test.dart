import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/features/auth/domain/auth_session.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';

void main() {
  group('UserSummary', () {
    test('fromJson parses complete valid JSON', () {
      final json = {
        'userId': 'usr_001',
        'name': 'Aarav Sharma',
        'email': 'aarav@example.com',
      };

      final user = UserSummary.fromJson(json);

      expect(user.userId, equals('usr_001'));
      expect(user.name, equals('Aarav Sharma'));
      expect(user.email, equals('aarav@example.com'));
      expect(user.toJson(), equals(json));
    });

    test('fromJson throws FormatException on missing required fields', () {
      expect(
        () => UserSummary.fromJson({'name': 'Test', 'email': 't@example.com'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => UserSummary.fromJson({'userId': 'u1', 'email': 't@example.com'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => UserSummary.fromJson({'userId': 'u1', 'name': 'Test'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AuthSession', () {
    test('fromJson parses complete valid JSON', () {
      final json = {
        'accessToken': 'access_123',
        'refreshToken': 'refresh_456',
        'expiresIn': 900,
        'tokenType': 'Bearer',
        'user': {
          'userId': 'usr_001',
          'name': 'Aarav',
          'email': 'aarav@example.com',
        },
      };

      final session = AuthSession.fromJson(json);

      expect(session.accessToken, equals('access_123'));
      expect(session.refreshToken, equals('refresh_456'));
      expect(session.expiresIn, equals(900));
      expect(session.tokenType, equals('Bearer'));
      expect(session.user.userId, equals('usr_001'));
      expect(session.toJson(), equals(json));
    });

    test('fromJson throws FormatException on missing required tokens or user', () {
      expect(
        () => AuthSession.fromJson({
          'refreshToken': 'ref',
          'expiresIn': 900,
          'user': {'userId': 'u', 'name': 'n', 'email': 'e@e.com'}
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AuthSession.fromJson({
          'accessToken': 'acc',
          'expiresIn': 900,
          'user': {'userId': 'u', 'name': 'n', 'email': 'e@e.com'}
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AuthSession.fromJson({
          'accessToken': 'acc',
          'refreshToken': 'ref',
          'expiresIn': 900,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
