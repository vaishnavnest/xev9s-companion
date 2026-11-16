import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/auth_interceptor.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
  bool cleared = false;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveAccessToken(String token) async {
    accessToken = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    refreshToken = token;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
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

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(
    Map<String, dynamic> body, {
    int statusCode = 200,
    Map<String, List<String>>? headers,
  }) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        'content-type': ['application/json'],
        ...?headers,
      },
    );
  }
}

void main() {
  group('AuthInterceptor', () {
    test('attaches Bearer header for regular endpoints', () async {
      final storage = FakeTokenStorage(accessToken: 'token_123');
      String? recordedAuth;

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        recordedAuth = options.headers['Authorization'] as String?;
        return TestAdapter.json({'success': true, 'data': {}});
      });

      dio.interceptors.add(AuthInterceptor(tokenStorage: storage, dio: dio));

      await dio.get<dynamic>('/vehicles');
      expect(recordedAuth, equals('Bearer token_123'));
    });

    test('skips attaching Bearer header for /auth/login, /auth/register, /auth/refresh', () async {
      final storage = FakeTokenStorage(accessToken: 'token_123');
      final recordedHeaders = <String, String?>{};

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        recordedHeaders[options.path] = options.headers['Authorization'] as String?;
        return TestAdapter.json({'success': true, 'data': {}});
      });

      dio.interceptors.add(AuthInterceptor(tokenStorage: storage, dio: dio));

      await dio.post<dynamic>('/auth/login');
      await dio.post<dynamic>('/auth/register');
      await dio.post<dynamic>('/auth/refresh');

      expect(recordedHeaders['/auth/login'], isNull);
      expect(recordedHeaders['/auth/register'], isNull);
      expect(recordedHeaders['/auth/refresh'], isNull);
    });

    test('with 3 concurrent 401 TOKEN_EXPIRED responses only ONE refresh call happens and all 3 requests retry with new token', () async {
      final storage = FakeTokenStorage(
        accessToken: 'expired_token',
        refreshToken: 'valid_refresh',
      );

      int refreshCallsCount = 0;
      final retriedHeaders = <String>[];

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        if (options.path == '/auth/refresh') {
          refreshCallsCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return TestAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'refreshed_access_token',
              'refreshToken': 'refreshed_refresh_token',
              'tokenType': 'Bearer',
              'expiresIn': 900,
              'user': {'userId': 'usr_1', 'name': 'Test', 'email': 't@example.com'},
            },
          });
        }

        final auth = options.headers['Authorization'] as String?;
        if (auth == 'Bearer refreshed_access_token') {
          retriedHeaders.add(auth!);
          return TestAdapter.json({'success': true, 'data': {'retriedPath': options.path}});
        }

        return TestAdapter.json(
          {
            'success': false,
            'data': null,
            'error': {
              'code': 'TOKEN_EXPIRED',
              'message': 'Token has expired',
              'retryable': true,
            },
          },
          statusCode: 401,
        );
      });

      dio.interceptors.add(AuthInterceptor(tokenStorage: storage, dio: dio));

      final responses = await Future.wait([
        dio.get<Map<String, dynamic>>('/vehicles/1'),
        dio.get<Map<String, dynamic>>('/vehicles/2'),
        dio.get<Map<String, dynamic>>('/vehicles/3'),
      ]);

      expect(refreshCallsCount, equals(1));
      expect(responses.length, equals(3));
      for (final resp in responses) {
        expect(resp.data?['success'], isTrue);
      }
      expect(retriedHeaders.length, equals(3));
      expect(await storage.getAccessToken(), equals('refreshed_access_token'));
    });

    test('a retried request that gets 401 again fails (no loop)', () async {
      final storage = FakeTokenStorage(
        accessToken: 'expired_token',
        refreshToken: 'valid_refresh',
      );

      int refreshCallsCount = 0;
      int requestAttempts = 0;

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        if (options.path == '/auth/refresh') {
          refreshCallsCount++;
          return TestAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'new_token_still_rejected',
              'refreshToken': 'new_refresh',
            },
          });
        }

        requestAttempts++;
        return TestAdapter.json(
          {
            'success': false,
            'error': {
              'code': 'TOKEN_EXPIRED',
              'message': 'Always expired',
              'retryable': false,
            },
          },
          statusCode: 401,
        );
      });

      dio.interceptors.add(AuthInterceptor(tokenStorage: storage, dio: dio));

      await expectLater(
        dio.get<dynamic>('/vehicles'),
        throwsA(isA<DioException>()),
      );

      // Exactly 1 initial request + 1 retry = 2 attempts total, no infinite loop
      expect(requestAttempts, equals(2));
      expect(refreshCallsCount, equals(1));
      expect(storage.cleared, isTrue);
    });

    test('refresh failure clears tokens and emits unauthenticated event', () async {
      final storage = FakeTokenStorage(
        accessToken: 'expired_token',
        refreshToken: 'invalid_refresh',
      );

      AuthEvent? receivedEvent;

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        if (options.path == '/auth/refresh') {
          return TestAdapter.json(
            {
              'success': false,
              'error': {'code': 'UNAUTHENTICATED', 'message': 'Refresh token expired'},
            },
            statusCode: 401,
          );
        }

        return TestAdapter.json(
          {
            'success': false,
            'error': {'code': 'TOKEN_EXPIRED', 'message': 'Token expired'},
          },
          statusCode: 401,
        );
      });

      final interceptor = AuthInterceptor(tokenStorage: storage, dio: dio);
      interceptor.authEvents.listen((event) {
        receivedEvent = event;
      });
      dio.interceptors.add(interceptor);

      await expectLater(
        dio.get<dynamic>('/vehicles'),
        throwsA(isA<DioException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(storage.cleared, isTrue);
      expect(receivedEvent, equals(AuthEvent.unauthenticated));
    });
  });
}
