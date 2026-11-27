import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/features/charging/data/charging_repository.dart';
import 'package:xev9s_app/features/charging/domain/charging_overview.dart';
import 'package:xev9s_app/features/charging/domain/charging_schedule.dart';
import 'package:xev9s_app/features/charging/domain/charging_session.dart';
import 'package:xev9s_app/features/charging/domain/day_of_week.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late ApiChargingRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = ApiChargingRepository(apiClient: mockApiClient);
  });

  group('ApiChargingRepository', () {
    test('getOverview calls GET /vehicles/{id}/charging', () async {
      const overview = ChargingOverview(
        state: ChargingState.charging,
        batteryPercent: 64.0,
      );

      when(
        () => mockApiClient.get<ChargingOverview>(
          '/vehicles/veh_9S0001/charging',
          parse: any(named: 'parse'),
        ),
      ).thenAnswer((_) async => overview);

      final result = await repository.getOverview('veh_9S0001');
      expect(result.state, ChargingState.charging);
      expect(result.batteryPercent, 64.0);
    });

    test('setTarget calls PUT /vehicles/{id}/charging/preferences', () async {
      const overview = ChargingOverview(
        state: ChargingState.notConnected,
        targetPercent: 85,
      );

      when(
        () => mockApiClient.put<ChargingOverview>(
          '/vehicles/veh_9S0001/charging/preferences',
          body: any(named: 'body'),
          parse: any(named: 'parse'),
        ),
      ).thenAnswer((_) async => overview);

      final result = await repository.setTarget('veh_9S0001', 85);
      expect(result.targetPercent, 85);
    });

    test('saveSchedule calls PUT /vehicles/{id}/charging/preferences', () async {
      const schedule = ChargingSchedule(
        enabled: true,
        startTime: ScheduleTime(hour: 22, minute: 0),
        endTime: ScheduleTime(hour: 6, minute: 0),
        daysOfWeek: {DayOfWeek.mon, DayOfWeek.fri},
      );
      const overview = ChargingOverview(
        state: ChargingState.notConnected,
        schedule: schedule,
      );

      when(
        () => mockApiClient.put<ChargingOverview>(
          '/vehicles/veh_9S0001/charging/preferences',
          body: any(named: 'body'),
          parse: any(named: 'parse'),
        ),
      ).thenAnswer((_) async => overview);

      final result = await repository.saveSchedule('veh_9S0001', schedule);
      expect(result.schedule?.enabled, isTrue);
    });

    test('deleteSchedule calls PUT /vehicles/{id}/charging/preferences', () async {
      const overview = ChargingOverview(
        state: ChargingState.notConnected,
        schedule: null,
      );

      when(
        () => mockApiClient.put<ChargingOverview>(
          '/vehicles/veh_9S0001/charging/preferences',
          body: any(named: 'body'),
          parse: any(named: 'parse'),
        ),
      ).thenAnswer((_) async => overview);

      final result = await repository.deleteSchedule('veh_9S0001');
      expect(result.schedule, isNull);
    });

    test('listSessions passes pagination, status, from, to, and sort query parameters', () async {
      final session = ChargingSession(
        sessionId: 'chs_1',
        vehicleId: 'veh_9S0001',
        startedAt: DateTime.now(),
        status: ChargingState.completed,
      );
      final from = DateTime.utc(2026, 11, 1);
      final to = DateTime.utc(2026, 11, 30);

      when(
        () => mockApiClient.getPaged<ChargingSession>(
          '/vehicles/veh_9S0001/charging/sessions',
          query: {
            'limit': 10,
            'offset': 10,
            'page': 2,
            'page_size': 10,
            'status': 'active',
            'from': from.toIso8601String(),
            'to': to.toIso8601String(),
            'sort': '-started_at',
          },
          parseItem: any(named: 'parseItem'),
        ),
      ).thenAnswer(
        (_) async => PagedResult<ChargingSession>(
          items: [session],
          pagination: const Pagination(
            page: 2,
            pageSize: 10,
            totalItems: 11,
            totalPages: 2,
          ),
        ),
      );

      final result = await repository.listSessions(
        'veh_9S0001',
        page: 2,
        pageSize: 10,
        status: ChargingState.charging,
        from: from,
        to: to,
        sort: '-started_at',
      );
      expect(result.items.length, 1);
      expect(result.items.first.sessionId, 'chs_1');
      expect(result.pagination?.totalPages, 2);
    });

    test('getSession fetches single session directly from /sessions/{sessionId}', () async {
      final session = ChargingSession(
        sessionId: 'chs_42',
        vehicleId: 'veh_9S0001',
        startedAt: DateTime.now(),
        status: ChargingState.charging,
      );

      when(
        () => mockApiClient.get<ChargingSession>(
          '/vehicles/veh_9S0001/charging/sessions/chs_42',
          parse: any(named: 'parse'),
        ),
      ).thenAnswer((_) async => session);

      final result = await repository.getSession('veh_9S0001', 'chs_42');
      expect(result.sessionId, 'chs_42');
      verify(
        () => mockApiClient.get<ChargingSession>(
          '/vehicles/veh_9S0001/charging/sessions/chs_42',
          parse: any(named: 'parse'),
        ),
      ).called(1);
    });
  });
}
