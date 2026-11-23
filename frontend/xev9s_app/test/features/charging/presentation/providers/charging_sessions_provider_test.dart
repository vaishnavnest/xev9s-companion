import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/charging/data/charging_repository.dart';
import 'package:xev9s_app/features/charging/domain/charging_session.dart';
import 'package:xev9s_app/features/charging/presentation/providers/charging_sessions_provider.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockChargingRepository extends Mock implements ChargingRepository {}

void main() {
  late MockChargingRepository mockRepository;

  setUp(() {
    mockRepository = MockChargingRepository();
  });

  ChargingSession createSession(String id, {ChargingState status = ChargingState.completed}) {
    return ChargingSession(
      sessionId: id,
      vehicleId: 'veh_9S0001',
      startedAt: DateTime.parse('2026-11-20T10:00:00Z'),
      status: status,
    );
  }

  ProviderContainer createContainer() {
    const authState = AuthAuthenticated(
      UserSummary(
        userId: 'usr_1',
        email: 'test@example.com',
        name: 'Test',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        chargingRepositoryProvider.overrideWithValue(mockRepository),
        authControllerProvider.overrideWith(() => _TestAuthController(authState)),
        selectedVehicleProvider.overrideWith(() => _TestVehicleNotifier('veh_9S0001')),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ChargingSessionsProvider pagination', () {
    test('loads first page of sessions with hasMore true when totalPages > 1', () async {
      final s1 = createSession('s1');
      final s2 = createSession('s2');

      when(
        () => mockRepository.listSessions(
          'veh_9S0001',
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: null,
        ),
      ).thenAnswer(
        (_) async => PagedResult<ChargingSession>(
          items: [s1, s2],
          pagination: const Pagination(page: 1, pageSize: 2, totalItems: 4, totalPages: 2),
        ),
      );

      final container = createContainer();
      final state = await container.read(chargingSessionsProvider.future);

      expect(state.items.length, 2);
      expect(state.page, 1);
      expect(state.hasMore, isTrue);
    });

    test('loadMore appends unique sessions and updates hasMore', () async {
      final s1 = createSession('s1');
      final s2 = createSession('s2');
      final s3 = createSession('s3');

      when(
        () => mockRepository.listSessions(
          'veh_9S0001',
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: null,
        ),
      ).thenAnswer(
        (_) async => PagedResult<ChargingSession>(
          items: [s1, s2],
          pagination: const Pagination(page: 1, pageSize: 2, totalItems: 3, totalPages: 2),
        ),
      );

      when(
        () => mockRepository.listSessions(
          'veh_9S0001',
          page: 2,
          pageSize: any(named: 'pageSize'),
          status: null,
        ),
      ).thenAnswer(
        (_) async => PagedResult<ChargingSession>(
          items: [s2, s3], // s2 duplicate
          pagination: const Pagination(page: 2, pageSize: 2, totalItems: 3, totalPages: 2),
        ),
      );

      final container = createContainer();
      await container.read(chargingSessionsProvider.future);

      // Load more
      await container.read(chargingSessionsProvider.notifier).loadMore();
      final updated = container.read(chargingSessionsProvider).value!;

      expect(updated.items.length, 3); // s1, s2, s3 (de-duplicated)
      expect(updated.page, 2);
      expect(updated.hasMore, isFalse);
    });

    test('failed loadMore preserves existing items and exposes error', () async {
      final s1 = createSession('s1');

      when(
        () => mockRepository.listSessions(
          'veh_9S0001',
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: null,
        ),
      ).thenAnswer(
        (_) async => PagedResult<ChargingSession>(
          items: [s1],
          pagination: const Pagination(page: 1, pageSize: 1, totalItems: 2, totalPages: 2),
        ),
      );

      when(
        () => mockRepository.listSessions(
          'veh_9S0001',
          page: 2,
          pageSize: any(named: 'pageSize'),
          status: null,
        ),
      ).thenThrow(Exception('Network timeout'));

      final container = createContainer();
      await container.read(chargingSessionsProvider.future);

      await container.read(chargingSessionsProvider.notifier).loadMore();
      final state = container.read(chargingSessionsProvider).value!;

      expect(state.items.length, 1);
      expect(state.loadMoreError, isNotNull);
      expect(state.isLoadingMore, isFalse);
    });

    test('filter change resets pagination and re-fetches from page 1', () async {
      final completed = createSession('s_comp', status: ChargingState.completed);

      when(
        () => mockRepository.listSessions(
          'veh_9S0001',
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: null,
        ),
      ).thenAnswer(
        (_) async => PagedResult<ChargingSession>(
          items: [createSession('s_all')],
          pagination: const Pagination(page: 1, pageSize: 1, totalItems: 1, totalPages: 1),
        ),
      );

      when(
        () => mockRepository.listSessions(
          'veh_9S0001',
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: ChargingState.completed,
        ),
      ).thenAnswer(
        (_) async => PagedResult<ChargingSession>(
          items: [completed],
          pagination: const Pagination(page: 1, pageSize: 1, totalItems: 1, totalPages: 1),
        ),
      );

      final container = createContainer();
      await container.read(chargingSessionsProvider.future);

      await container.read(chargingSessionsProvider.notifier).setFilter(ChargingState.completed);
      final filteredState = container.read(chargingSessionsProvider).value!;

      expect(filteredState.items.first.sessionId, 's_comp');
      expect(filteredState.statusFilter, ChargingState.completed);
    });
  });
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.initialState);
  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

class _TestVehicleNotifier extends SelectedVehicleNotifier {
  _TestVehicleNotifier(this.initialId);
  final String? initialId;

  @override
  String? build() => initialId;
}
