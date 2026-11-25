import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers.dart';
import '../domain/trip.dart';
import '../domain/trip_detail.dart';
import '../domain/trip_status.dart';

/// Abstract contract for vehicle trip history and route operations (UC-06).
abstract class TripRepository {
  /// Fetches a paginated list of trips for [vehicleId].
  Future<PagedResult<Trip>> listTrips(
    String vehicleId, {
    int? page,
    int? pageSize,
    String? sort,
    TripStatus? status,
    String? from,
    String? to,
  });

  /// Fetches full trip details including battery range and GPS route.
  Future<TripDetail> getTrip(String vehicleId, String tripId);
}

/// Production implementation of [TripRepository] backed by [ApiClient].
class ApiTripRepository implements TripRepository {
  ApiTripRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<PagedResult<Trip>> listTrips(
    String vehicleId, {
    int? page,
    int? pageSize,
    String? sort,
    TripStatus? status,
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{
      'page': page ?? 1,
      'pageSize': pageSize ?? AppConstants.tripsPageSize,
      'sort': sort ?? '-startedAt',
    };

    final wireStatus = status?.toApi();
    if (wireStatus != null) {
      query['status'] = wireStatus;
    }
    if (from != null && from.isNotEmpty) {
      query['from'] = from;
    }
    if (to != null && to.isNotEmpty) {
      query['to'] = to;
    }

    return apiClient.get<PagedResult<Trip>>(
      '/vehicles/$vehicleId/trips',
      query: query,
      parse: (json) {
        List<dynamic> rawItems;
        Pagination? pagination;

        if (json is List) {
          rawItems = json;
        } else if (json is Map<String, dynamic>) {
          final listField = json['trips'] ?? json['items'] ?? json['data'];
          if (listField is! List) {
            throw const FormatException(
              'Expected trips/items list in paginated trip response',
            );
          }
          rawItems = listField;
          final rawPagination = json['pagination'];
          if (rawPagination is Map<String, dynamic>) {
            pagination = _parsePagination(rawPagination);
          }
        } else {
          throw FormatException(
            'Expected JSON map or list for trips, got ${json.runtimeType}',
          );
        }

        final items = rawItems
            .map((item) {
              if (item is! Map<String, dynamic>) {
                throw const FormatException('Expected JSON map for Trip');
              }
              return Trip.fromJson(item);
            })
            .toList(growable: false);

        return PagedResult<Trip>(items: items, pagination: pagination);
      },
    );
  }

  @override
  Future<TripDetail> getTrip(String vehicleId, String tripId) async {
    return apiClient.get<TripDetail>(
      '/vehicles/$vehicleId/trips/$tripId',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for TripDetail');
        }
        return TripDetail.fromJson(json);
      },
    );
  }

  static Pagination _parsePagination(Map<String, dynamic> json) {
    return Pagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: ((json['page_size'] ?? json['pageSize']) as num?)?.toInt() ??
          AppConstants.tripsPageSize,
      totalItems:
          ((json['total_items'] ?? json['totalItems']) as num?)?.toInt() ?? 0,
      totalPages:
          ((json['total_pages'] ?? json['totalPages']) as num?)?.toInt() ?? 1,
    );
  }
}

/// Provider for [TripRepository]. Overridable in tests.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiTripRepository(apiClient: apiClient);
});
