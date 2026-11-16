import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/auth_interceptor.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
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
  group('ApiClient', () {
    test('unwraps successful envelope data', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return TestAdapter.json({
          'success': true,
          'data': {'vehicleId': 'veh_9S0001'},
          'meta': {'requestId': 'req_1', 'timestamp': '2026-11-16T10:00:00Z'},
          'error': null,
        });
      });

      final client = ApiClient(dio: dio);
      final result = await client.get<String>(
        '/vehicles/veh_9S0001',
        parse: (json) => (json as Map<String, dynamic>)['vehicleId'] as String,
      );

      expect(result, equals('veh_9S0001'));
    });

    test('throws AppError when envelope has success: false', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return TestAdapter.json({
          'success': false,
          'data': null,
          'meta': {'requestId': 'req_2', 'timestamp': '2026-11-16T10:00:00Z'},
          'error': {
            'code': 'VEHICLE_OFFLINE',
            'message': 'Vehicle is offline',
            'retryable': true,
          },
        });
      });

      final client = ApiClient(dio: dio);

      expect(
        () => client.get<dynamic>('/vehicles', parse: (j) => j),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', ApiErrorCode.vehicleOffline)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('throws AppError.malformedResponse when response is not an envelope', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return ResponseBody.fromString('plain text not json', 200);
      });

      final client = ApiClient(dio: dio);

      expect(
        () => client.get<dynamic>('/vehicles', parse: (j) => j),
        throwsA(isA<AppError>()),
      );
    });

    test('getPaged extracts items and pagination correctly', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return TestAdapter.json({
          'success': true,
          'data': [
            {'id': '1'},
            {'id': '2'},
          ],
          'meta': {
            'requestId': 'req_3',
            'timestamp': '2026-11-16T10:00:00Z',
            'pagination': {
              'page': 1,
              'pageSize': 2,
              'totalItems': 10,
              'totalPages': 5,
            },
          },
          'error': null,
        });
      });

      final client = ApiClient(dio: dio);
      final paged = await client.getPaged<String>(
        '/trips',
        parseItem: (j) => (j as Map<String, dynamic>)['id'] as String,
      );

      expect(paged.items, equals(['1', '2']));
      expect(paged.pagination?.totalItems, equals(10));
      expect(paged.pagination?.totalPages, equals(5));
    });
  });

  group('AuthInterceptor', () {
    test('adds Authorization header for non-exempt endpoints', () async {
      final storage = FakeTokenStorage()..accessToken = 'test_access_token';
      String? sentAuthHeader;

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        sentAuthHeader = options.headers['Authorization'] as String?;
        return TestAdapter.json({
          'success': true,
          'data': {'status': 'ok'},
          'meta': {'requestId': 'req_1', 'timestamp': '2026-11-16T10:00:00Z'},
          'error': null,
        });
      });

      final client = ApiClient(dio: dio, tokenStorage: storage);
      await client.get<dynamic>('/vehicles', parse: (j) => j);

      expect(sentAuthHeader, equals('Bearer test_access_token'));
    });

    test('does not add Authorization header for exempt endpoints', () async {
      final storage = FakeTokenStorage()..accessToken = 'test_access_token';
      String? sentAuthHeader;

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        sentAuthHeader = options.headers['Authorization'] as String?;
        return TestAdapter.json({
          'success': true,
          'data': {'status': 'ok'},
          'meta': {'requestId': 'req_1', 'timestamp': '2026-11-16T10:00:00Z'},
          'error': null,
        });
      });

      final client = ApiClient(dio: dio, tokenStorage: storage);
      await client.post<dynamic>(
        '/auth/login',
        body: {'identifier': 'user', 'password': 'pwd'},
        parse: (j) => j,
      );

      expect(sentAuthHeader, isNull);
    });

    test('clears tokens and emits unauthenticated when 401 occurs with UNAUTHENTICATED', () async {
      final storage = FakeTokenStorage()..accessToken = 'bad_token';
      AuthEvent? emittedEvent;

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return TestAdapter.json(
          {
            'success': false,
            'data': null,
            'meta': {'requestId': 'req_4', 'timestamp': '2026-11-16T10:00:00Z'},
            'error': {
              'code': 'UNAUTHENTICATED',
              'message': 'Token invalid',
              'retryable': false,
            },
          },
          statusCode: 401,
        );
      });

      final client = ApiClient(dio: dio, tokenStorage: storage);
      client.authEvents?.listen((event) {
        emittedEvent = event;
      });

      try {
        await client.get<dynamic>('/vehicles', parse: (j) => j);
      } catch (_) {}

      // Allow microtask queue to process stream event
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(storage.cleared, isTrue);
      expect(emittedEvent, equals(AuthEvent.unauthenticated));
    });
  });
}
