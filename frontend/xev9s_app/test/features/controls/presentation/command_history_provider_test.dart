import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/controls/data/command_repository.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/controls/presentation/providers/command_history_provider.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockCommandRepository extends Mock implements CommandRepository {}

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

void main() {
  late MockCommandRepository mockCommandRepo;
  const vehicleId = 'veh_9S0001';
  final t0 = DateTime.parse('2026-11-24T12:00:00Z');

  setUp(() {
    mockCommandRepo = MockCommandRepository();
  });

  ProviderContainer createContainer() {
    const authState = AuthAuthenticated(
      UserSummary(
        userId: 'usr_1',
        email: 'test@example.com',
        name: 'Test Driver',
      ),
    );

    return ProviderContainer(
      overrides: [
        commandRepositoryProvider.overrideWithValue(mockCommandRepo),
        authControllerProvider.overrideWith(() => _TestAuthController(authState)),
        selectedVehicleProvider.overrideWith(() => _TestVehicleNotifier(vehicleId)),
      ],
    );
  }

  group('CommandHistoryNotifier Pagination & Filtering', () {
    final cmd1 = Command(
      commandId: 'cmd_1',
      vehicleId: vehicleId,
      commandType: CommandType.lock,
      status: CommandStatus.succeeded,
      requestedAt: t0,
    );

    final cmd2 = Command(
      commandId: 'cmd_2',
      vehicleId: vehicleId,
      commandType: CommandType.unlock,
      status: CommandStatus.failed,
      requestedAt: t0.subtract(const Duration(hours: 1)),
    );

    test('initial build loads first page and computes hasMore', () async {
      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          commandType: any(named: 'commandType'),
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [cmd1],
          pagination: const Pagination(
            page: 1,
            pageSize: 20,
            totalItems: 2,
            totalPages: 2,
          ),
        ),
      );

      final container = createContainer();
      final state = await container.read(commandHistoryProvider.future);

      expect(state.items.length, 1);
      expect(state.items.first.commandId, 'cmd_1');
      expect(state.hasMore, isTrue);
      expect(state.page, 1);
    });

    test('loadMore appends unique items and deduplicates duplicates',
        () async {
      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          commandType: any(named: 'commandType'),
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [cmd1],
          pagination: const Pagination(
            page: 1,
            pageSize: 20,
            totalItems: 2,
            totalPages: 2,
          ),
        ),
      );

      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 2,
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          commandType: any(named: 'commandType'),
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [cmd1, cmd2],
          pagination: const Pagination(
            page: 2,
            pageSize: 20,
            totalItems: 2,
            totalPages: 2,
          ),
        ),
      );

      final container = createContainer();
      await container.read(commandHistoryProvider.future);

      final notifier = container.read(commandHistoryProvider.notifier);
      await notifier.loadMore();

      final state = container.read(commandHistoryProvider).value!;
      expect(state.items.length, 2);
      expect(state.items[0].commandId, 'cmd_1');
      expect(state.items[1].commandId, 'cmd_2');
      expect(state.hasMore, isFalse);
    });

    test('loadMore failure retains existing items and sets loadMoreError',
        () async {
      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          commandType: any(named: 'commandType'),
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [cmd1],
          pagination: const Pagination(
            page: 1,
            pageSize: 20,
            totalItems: 2,
            totalPages: 2,
          ),
        ),
      );

      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 2,
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          commandType: any(named: 'commandType'),
        ),
      ).thenThrow(Exception('Page 2 timeout'));

      final container = createContainer();
      await container.read(commandHistoryProvider.future);

      final notifier = container.read(commandHistoryProvider.notifier);
      await notifier.loadMore();

      final state = container.read(commandHistoryProvider).value!;
      expect(state.items.length, 1);
      expect(state.loadMoreError, isNotNull);
    });

    test('setStatusFilter and setTypeFilter re-fetch from page 1', () async {
      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          commandType: any(named: 'commandType'),
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [cmd1],
          pagination: const Pagination(
            page: 1,
            pageSize: 20,
            totalItems: 1,
            totalPages: 1,
          ),
        ),
      );

      final container = createContainer();
      await container.read(commandHistoryProvider.future);

      final notifier = container.read(commandHistoryProvider.notifier);
      await notifier.setStatusFilter(CommandStatus.succeeded);

      verify(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: CommandStatus.succeeded,
          commandType: null,
        ),
      ).called(1);

      await notifier.setTypeFilter(CommandType.lock);
      verify(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: any(named: 'pageSize'),
          status: CommandStatus.succeeded,
          commandType: CommandType.lock,
        ),
      ).called(1);
    });
  });
}
