import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
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
  final Map<String, ChargingOverview> _cachedOverviews = {};

  @override
  Future<ChargingOverview> getOverview(String vehicleId) async {
    try {
      final overview = await apiClient.get<ChargingOverview>(
        '/vehicles/$vehicleId/charging',
        parse: (json) {
          if (json == null) {
            return const ChargingOverview(state: ChargingState.notConnected);
          }
          if (json is! Map<String, dynamic>) {
            throw const FormatException(
                'Expected JSON map for ChargingOverview');
          }
          return ChargingOverview.fromJson(json);
        },
      );
      _cachedOverviews[vehicleId] = overview;
      return overview;
    } on AppError catch (e) {
      if (e.kind == AppErrorKind.malformed && e.message.contains('Null')) {
        const empty = ChargingOverview(state: ChargingState.notConnected);
        _cachedOverviews[vehicleId] = empty;
        return empty;
      }
      rethrow;
    }
  }

  Map<String, dynamic> _buildPreferencesPayload({
    required int targetPercent,
    required ChargingSchedule? schedule,
    required String timezone,
    required bool stopChargingAtTarget,
  }) {
    final scheduleEnabled = schedule?.enabled ?? false;
    return {
      'target_percentage': targetPercent.toDouble(),
      'schedule_enabled': scheduleEnabled,
      if (scheduleEnabled && schedule?.startTime != null)
        'scheduled_start_time': schedule!.startTime!.toApi(),
      if (scheduleEnabled && schedule?.endTime != null)
        'scheduled_end_time': schedule!.endTime!.toApi(),
      'scheduled_days': scheduleEnabled && schedule != null
          ? schedule.daysOfWeek.map((d) => d.toBackendWeekday()).toList()
          : <String>[],
      'timezone': timezone,
      'stop_charging_at_target': stopChargingAtTarget,
    };
  }

  @override
  Future<ChargingOverview> setTarget(String vehicleId, int targetPercent) async {
    final current = _cachedOverviews[vehicleId];
    final body = _buildPreferencesPayload(
      targetPercent: targetPercent,
      schedule: current?.schedule,
      timezone: current?.timezone ?? 'UTC',
      stopChargingAtTarget: current?.stopChargingAtTarget ?? true,
    );

    final updated = await apiClient.put<ChargingOverview>(
      '/vehicles/$vehicleId/charging/preferences',
      body: body,
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingOverview');
        }
        return ChargingOverview.fromJson(json);
      },
    );
    _cachedOverviews[vehicleId] = updated;
    return updated;
  }

  @override
  Future<ChargingOverview> saveSchedule(
    String vehicleId,
    ChargingSchedule schedule,
  ) async {
    final current = _cachedOverviews[vehicleId];
    final body = _buildPreferencesPayload(
      targetPercent: current?.targetPercent ?? 80,
      schedule: schedule,
      timezone: current?.timezone ?? 'UTC',
      stopChargingAtTarget: current?.stopChargingAtTarget ?? true,
    );

    final updated = await apiClient.put<ChargingOverview>(
      '/vehicles/$vehicleId/charging/preferences',
      body: body,
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingOverview');
        }
        return ChargingOverview.fromJson(json);
      },
    );
    _cachedOverviews[vehicleId] = updated;
    return updated;
  }

  @override
  Future<ChargingOverview> deleteSchedule(String vehicleId) async {
    final current = _cachedOverviews[vehicleId];
    final body = _buildPreferencesPayload(
      targetPercent: current?.targetPercent ?? 80,
      schedule: const ChargingSchedule(enabled: false),
      timezone: current?.timezone ?? 'UTC',
      stopChargingAtTarget: current?.stopChargingAtTarget ?? true,
    );

    final updated = await apiClient.put<ChargingOverview>(
      '/vehicles/$vehicleId/charging/preferences',
      body: body,
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for ChargingOverview');
        }
        return ChargingOverview.fromJson(json);
      },
    );
    _cachedOverviews[vehicleId] = updated;
    return updated;
  }

  String? _mapStatusToQuery(ChargingState status) {
    switch (status) {
      case ChargingState.charging:
        return 'active';
      case ChargingState.paused:
        return 'paused';
      case ChargingState.completed:
        return 'completed';
      case ChargingState.interrupted:
        return 'interrupted';
      case ChargingState.connected:
      case ChargingState.notConnected:
      case ChargingState.unknown:
        return null;
    }
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
    final limit = (pageSize ?? AppConstants.sessionsPageSize).clamp(1, 100);
    final currentPage = (page ?? 1) < 1 ? 1 : (page ?? 1);
    final offset = (currentPage - 1) * limit;

    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'page': currentPage,
      'page_size': limit,
    };

    if (status != null) {
      final mappedStatus = _mapStatusToQuery(status);
      if (mappedStatus != null) {
        query['status'] = mappedStatus;
      }
    }
    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }
    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }
    if (sort != null && sort.isNotEmpty) {
      query['sort'] = sort;
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
