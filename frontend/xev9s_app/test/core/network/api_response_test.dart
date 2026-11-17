import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/network/api_response.dart';

void main() {
  group('ApiResponse and Envelope models', () {
    test('Pagination deserializes correctly', () {
      final json = {
        'page': 2,
        'pageSize': 20,
        'totalItems': 105,
        'totalPages': 6,
      };

      final pagination = Pagination.fromJson(json);
      expect(pagination.page, equals(2));
      expect(pagination.pageSize, equals(20));
      expect(pagination.totalItems, equals(105));
      expect(pagination.totalPages, equals(6));
      expect(pagination.toJson(), equals(json));
    });

    test('ApiMeta deserializes with pagination', () {
      final json = {
        'requestId': 'req_123',
        'timestamp': '2026-11-16T10:00:00.000Z',
        'pagination': {
          'page': 1,
          'pageSize': 10,
          'totalItems': 30,
          'totalPages': 3,
        },
      };

      final meta = ApiMeta.fromJson(json);
      expect(meta.requestId, equals('req_123'));
      expect(meta.pagination?.totalItems, equals(30));
    });

    test('ApiResponse deserializes successful data envelope', () {
      final json = {
        'success': true,
        'data': {'vehicleId': 'veh_9S0001', 'name': 'My XEV'},
        'meta': {
          'requestId': 'req_456',
          'timestamp': '2026-11-16T10:00:00.000Z',
        },
        'error': null,
      };

      final response = ApiResponse.fromJson(
        json,
        (data) => (data as Map<String, dynamic>)['vehicleId'] as String,
      );

      expect(response.success, isTrue);
      expect(response.data, equals('veh_9S0001'));
      expect(response.error, isNull);
      expect(response.meta?.requestId, equals('req_456'));
    });

    test('ApiResponse deserializes error envelope', () {
      final json = {
        'success': false,
        'data': null,
        'meta': {
          'requestId': 'req_789',
          'timestamp': '2026-11-16T10:00:00.000Z',
        },
        'error': {
          'code': 'NOT_FOUND',
          'message': 'Vehicle not found',
          'retryable': false,
        },
      };

      final response = ApiResponse.fromJson(
        json,
        (data) => data,
      );

      expect(response.success, isFalse);
      expect(response.data, isNull);
      expect(response.error?['code'], equals('NOT_FOUND'));
    });

    test('PagedResult holds items and optional pagination', () {
      const paged = PagedResult<String>(
        items: ['a', 'b', 'c'],
        pagination: Pagination(page: 1, pageSize: 3, totalItems: 3, totalPages: 1),
      );

      expect(paged.items.length, equals(3));
      expect(paged.pagination?.totalPages, equals(1));
    });
  });
}
