import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers.dart';
import '../../vehicles/domain/vehicle_status.dart';
import '../domain/charging_overview.dart';
import '../domain/charging_schedule.dart';
import '../domain/charging_session.dart';

/// Abstract contract for vehicle charging operations (UC-04).
abstract class ChargingRepository {
  /// Fetches the live charging overview for [vehicleId].
  Future<ChargingOverview> getOverview(String vehicleId);

  /// Sets the charging target percentage for [vehicleId].
  Future<ChargingOverview> setTarget(String vehicleId, int targetPercent);

  /// Saves or updates the recurring charging schedule for [vehicleId].
  Future<ChargingOverview> saveSchedule(
      String vehicleId, ChargingSchedule schedule);

  /// Deletes/clears the recurring charging schedule for [vehicleId].
  Future<ChargingOverview> deleteSchedule(String vehicleId);

  /// Retrieves a paginated list of charging sessions for [vehicleId].
  Future<PagedResult<ChargingSession>> listSessions(
    String vehicleId, {
    int? page,
    int? pageSize,
    ChargingState? status,
    DateTime? from,
    DateTime? to,
    String? sort,
  });

  /// Fetches details of a specific charging session.
  Future<ChargingSession> getSession(String vehicleId, String sessionId);
}

/// Production implementation of [ChargingRepository] backed by [ApiClient].
class ApiChargingRepository implements ChargingRepository {
  ApiChargingRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<ChargingOverview> getOverview(String vehicleId) async {
    return apiClient.get<ChargingOverview>(
      '/vehicles/$vehicleId/charging',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingOverview');
        }
        return ChargingOverview.fromJson(json);
      },
    );
  }

  @override
  Future<ChargingOverview> setTarget(String vehicleId, int targetPercent) async {
    return apiClient.put<ChargingOverview>(
      '/vehicles/$vehicleId/charging/target',
      body: {'targetPercent': targetPercent},
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingOverview');
        }
        return ChargingOverview.fromJson(json);
      },
    );
  }

  @override
  Future<ChargingOverview> saveSchedule(
    String vehicleId,
    ChargingSchedule schedule,
  ) async {
    return apiClient.put<ChargingOverview>(
      '/vehicles/$vehicleId/charging/schedule',
      body: schedule.toJson(),
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingOverview');
        }
        return ChargingOverview.fromJson(json);
      },
    );
  }

  @override
  Future<ChargingOverview> deleteSchedule(String vehicleId) async {
    return apiClient.delete<ChargingOverview>(
      '/vehicles/$vehicleId/charging/schedule',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingOverview');
        }
        return ChargingOverview.fromJson(json);
      },
    );
  }

  @override
  Future<PagedResult<ChargingSession>> listSessions(
    String vehicleId, {
    int? page,
    int? pageSize,
    ChargingState? status,
    DateTime? from,
    DateTime? to,
    String? sort,
  }) async {
    final query = <String, dynamic>{
      'page': page ?? 1,
      'pageSize': pageSize ?? AppConstants.sessionsPageSize,
      'sort': sort ?? '-startedAt',
    };

    if (status != null && status != ChargingState.unknown) {
      query['status'] = status.wireValue;
    }
    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }
    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }

    return apiClient.getPaged<ChargingSession>(
      '/vehicles/$vehicleId/charging/sessions',
      query: query,
      parseItem: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingSession');
        }
        return ChargingSession.fromJson(json);
      },
    );
  }

  @override
  Future<ChargingSession> getSession(String vehicleId, String sessionId) async {
    return apiClient.get<ChargingSession>(
      '/vehicles/$vehicleId/charging/sessions/$sessionId',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingSession');
        }
        return ChargingSession.fromJson(json);
      },
    );
  }
}

/// Provider for [ChargingRepository]. Overridable in tests.
final chargingRepositoryProvider = Provider<ChargingRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiChargingRepository(apiClient: apiClient);
});
