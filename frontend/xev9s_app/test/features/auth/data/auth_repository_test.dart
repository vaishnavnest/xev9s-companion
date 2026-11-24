import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/auth/data/auth_repository.dart';

class FakeTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;
  bool cleared = false;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveAccessToken(String token) async => accessToken = token;

  @override
  Future<void> saveRefreshToken(String token) async => refreshToken = token;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
    cleared = true;
  }
}

class FakeApiClient extends ApiClient {
  FakeApiClient({this.handler}) : super(baseUrl: 'http://test.local');

  final Future<dynamic> Function(String path, dynamic body)? handler;

  String? lastPath;
  dynamic lastBody;

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    required T Function(Object? json) parse,
  }) async {
    lastPath = path;
    lastBody = body;
    if (handler != null) {
      final res = await handler!(path, body);
      return parse(res);
    }
    return parse(null);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) parse,
  }) async {
    lastPath = path;
    if (handler != null) {
      final res = await handler!(path, query);
      return parse(res);
    }
    return parse(null);
  }
}

void main() {
  group('AuthRepository', () {
    test('login trims identifier, preserves password, and saves tokens', () async {
      final storage = FakeTokenStorage();
      final client = FakeApiClient(
        handler: (path, body) async {
          expect(path, equals('/auth/login'));
          expect(body['identifier'], equals('owner@example.com'));
          expect(body['password'], equals('  secret123  ')); // preserved untrimmed

          return {
            'accessToken': 'acc_1',
            'refreshToken': 'ref_1',
            'expiresIn': 900,
            'tokenType': 'Bearer',
            'user': {
              'userId': 'u1',
              'name': 'Owner',
              'email': 'owner@example.com',
            },
          };
        },
      );

      final repo = ApiAuthRepository(apiClient: client, tokenStorage: storage);
      final session = await repo.login('  owner@example.com  ', '  secret123  ');

      expect(session.accessToken, equals('acc_1'));
      expect(storage.accessToken, equals('acc_1'));
      expect(storage.refreshToken, equals('ref_1'));
    });

    test('register trims name and email, preserves password, and saves tokens', () async {
      final storage = FakeTokenStorage();
      final client = FakeApiClient(
        handler: (path, body) async {
          expect(path, equals('/auth/register'));
          expect(body['name'], equals('Aarav Sharma'));
          expect(body['email'], equals('aarav@example.com'));
          expect(body['password'], equals('Pass1234'));

          return {
            'accessToken': 'acc_reg',
            'refreshToken': 'ref_reg',
            'expiresIn': 900,
            'tokenType': 'Bearer',
            'user': {
              'userId': 'u2',
              'name': 'Aarav Sharma',
              'email': 'aarav@example.com',
            },
          };
        },
      );

      final repo = ApiAuthRepository(apiClient: client, tokenStorage: storage);
      final session = await repo.register('  Aarav Sharma  ', '  aarav@example.com  ', 'Pass1234');

      expect(session.accessToken, equals('acc_reg'));
      expect(storage.accessToken, equals('acc_reg'));
      expect(storage.refreshToken, equals('ref_reg'));
    });

    test('currentUser calls GET /auth/me and parses UserSummary', () async {
      final storage = FakeTokenStorage();
      final client = FakeApiClient(
        handler: (path, _) async {
          expect(path, equals('/auth/me'));
          return {
            'userId': 'usr_me',
            'name': 'Current User',
            'email': 'me@example.com',
          };
        },
      );

      final repo = ApiAuthRepository(apiClient: client, tokenStorage: storage);
      final user = await repo.currentUser();

      expect(user.userId, equals('usr_me'));
      expect(user.name, equals('Current User'));
      expect(user.email, equals('me@example.com'));
    });

    test('logout calls POST /auth/logout and clears tokens even if call throws', () async {
      final storage = FakeTokenStorage()
        ..accessToken = 'to_clear'
        ..refreshToken = 'ref_clear';

      final client = FakeApiClient(
        handler: (path, body) async {
          throw const AppError(
            code: ApiErrorCode.internalError,
            message: 'Server error',
          );
        },
      );

      final repo = ApiAuthRepository(apiClient: client, tokenStorage: storage);
      await repo.logout();

      expect(storage.cleared, isTrue);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });
  });
}
