import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';

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
    test('success unwrap returns parsed data', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return TestAdapter.json({
          'success': true,
          'data': {'vehicleId': 'veh_9S0001', 'name': 'My XEV'},
          'meta': {'requestId': 'req_1', 'timestamp': '2026-11-16T10:00:00Z'},
          'error': null,
        });
      });

      final client = ApiClient(dio: dio);
      final result = await client.get<String>(
        '/vehicles/veh_9S0001',
        parse: (json) => (json as Map<String, dynamic>)['name'] as String,
      );

      expect(result, equals('My XEV'));
    });

    test('success=false maps to AppError with right code and details', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return TestAdapter.json(
          {
            'success': false,
            'data': null,
            'meta': {'requestId': 'req_2', 'timestamp': '2026-11-16T10:00:00Z'},
            'error': {
              'code': 'CHARGING_TARGET_NOT_APPLICABLE',
              'message': 'Cannot set target when unplugged',
              'retryable': false,
              'details': [
                {'field': 'targetPercent', 'issue': 'NOT_CONNECTED'},
              ],
            },
          },
          statusCode: 422,
        );
      });

      final client = ApiClient(dio: dio);

      try {
        await client.put<dynamic>(
          '/vehicles/veh_9S0001/charging/target',
          body: {'targetPercent': 90},
          parse: (j) => j,
        );
        fail('Should throw AppError');
      } on AppError catch (e) {
        expect(e.code, equals(ApiErrorCode.chargingTargetNotApplicable));
        expect(e.message, equals('Cannot set target when unplugged'));
        expect(e.retryable, isFalse);
        expect(e.httpStatus, equals(422));
        expect(e.details.length, equals(1));
        expect(e.details.first.field, equals('targetPercent'));
      }
    });

    test('timeout maps to AppError.timeout', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timeout after 15000ms',
        );
      });

      final client = ApiClient(dio: dio);

      try {
        await client.get<dynamic>('/vehicles', parse: (j) => j);
        fail('Should throw AppError.timeout');
      } on AppError catch (e) {
        expect(e.retryable, isTrue);
        expect(e.message, contains('timed out'));
      }
    });

    test('connection error maps to AppError.noConnection', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        );
      });

      final client = ApiClient(dio: dio);

      try {
        await client.get<dynamic>('/vehicles', parse: (j) => j);
        fail('Should throw AppError.noConnection');
      } on AppError catch (e) {
        expect(e.retryable, isTrue);
        expect(e.message, contains('internet connectivity'));
      }
    });

    test('malformed body maps to AppError.malformedResponse', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return ResponseBody.fromString(
          'non-json html error page',
          200,
          headers: {
            'content-type': ['text/html'],
          },
        );
      });

      final client = ApiClient(dio: dio);

      try {
        await client.get<dynamic>('/vehicles', parse: (j) => j);
        fail('Should throw malformed response');
      } on AppError catch (e) {
        expect(e.retryable, isFalse);
        expect(e.message, contains('unexpected response'));
      }
    });

    test('getPaged returns items + pagination', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4010'));
      dio.httpClientAdapter = TestAdapter((options) async {
        return TestAdapter.json({
          'success': true,
          'data': [
            {'tripId': 'trp_1'},
            {'tripId': 'trp_2'},
          ],
          'meta': {
            'requestId': 'req_trips',
            'timestamp': '2026-11-16T10:00:00Z',
            'pagination': {
              'page': 1,
              'pageSize': 20,
              'totalItems': 45,
              'totalPages': 3,
            },
          },
          'error': null,
        });
      });

      final client = ApiClient(dio: dio);
      final paged = await client.getPaged<String>(
        '/vehicles/veh_1/trips',
        parseItem: (json) => (json as Map<String, dynamic>)['tripId'] as String,
      );

      expect(paged.items, equals(['trp_1', 'trp_2']));
      expect(paged.pagination?.page, equals(1));
      expect(paged.pagination?.pageSize, equals(20));
      expect(paged.pagination?.totalItems, equals(45));
      expect(paged.pagination?.totalPages, equals(3));
    });
  });
}
