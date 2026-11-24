import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_client.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/features/controls/data/command_repository.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late ApiCommandRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = ApiCommandRepository(apiClient: mockApiClient);
  });

  group('ApiCommandRepository', () {
    const vehicleId = 'veh_9S0001';
    final sampleCommand = Command(
      commandId: 'cmd_7731',
      vehicleId: vehicleId,
      commandType: CommandType.lock,
      status: CommandStatus.submitted,
      requestedAt: DateTime.parse('2026-11-24T12:00:00Z'),
    );

    test('submit dispatches POST with Idempotency-Key header and commandType body',
        () async {
      when(
        () => mockApiClient.post<Command>(
          '/vehicles/$vehicleId/commands',
          headers: any(named: 'headers'),
          body: any(named: 'body'),
          parse: any(named: 'parse'),
        ),
      ).thenAnswer((_) async => sampleCommand);

      final result = await repository.submit(
        vehicleId,
        CommandType.lock,
        idempotencyKey: 'test-key-1234',
      );

      expect(result.commandId, 'cmd_7731');

      verify(
        () => mockApiClient.post<Command>(
          '/vehicles/$vehicleId/commands',
          headers: {'Idempotency-Key': 'test-key-1234'},
          body: {'commandType': 'LOCK'},
          parse: any(named: 'parse'),
        ),
      ).called(1);
    });

    test('getCommand fetches from correct vehicle commands endpoint', () async {
      when(
        () => mockApiClient.get<Command>(
          '/vehicles/$vehicleId/commands/cmd_7731',
          parse: any(named: 'parse'),
        ),
      ).thenAnswer((_) async => sampleCommand);

      final result = await repository.getCommand(vehicleId, 'cmd_7731');
      expect(result.commandId, 'cmd_7731');

      verify(
        () => mockApiClient.get<Command>(
          '/vehicles/$vehicleId/commands/cmd_7731',
          parse: any(named: 'parse'),
        ),
      ).called(1);
    });

    test('listCommands sends default sort=-requestedAt and parses PagedResult',
        () async {
      when(
        () => mockApiClient.getPaged<Command>(
          '/vehicles/$vehicleId/commands',
          query: any(named: 'query'),
          parseItem: any(named: 'parseItem'),
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [sampleCommand],
          pagination: const Pagination(
            page: 1,
            pageSize: 20,
            totalItems: 1,
            totalPages: 1,
          ),
        ),
      );

      final result = await repository.listCommands(
        vehicleId,
        status: CommandStatus.succeeded,
        commandType: CommandType.unlock,
      );

      expect(result.items.length, 1);
      expect(result.items.first.commandId, 'cmd_7731');

      verify(
        () => mockApiClient.getPaged<Command>(
          '/vehicles/$vehicleId/commands',
          query: {
            'page': 1,
            'pageSize': 20,
            'sort': '-requestedAt',
            'status': 'SUCCEEDED',
            'commandType': 'UNLOCK',
          },
          parseItem: any(named: 'parseItem'),
        ),
      ).called(1);
    });
  });
}
