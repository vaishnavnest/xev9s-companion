import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers.dart';
import '../domain/command.dart';
import '../domain/command_status.dart';
import '../domain/command_type.dart';

/// Contract for vehicle remote command execution and history retrieval (UC-05).
abstract class CommandRepository {
  /// Submits a new remote command with a client-generated [idempotencyKey].
  Future<Command> submit(
    String vehicleId,
    CommandType type, {
    required String idempotencyKey,
  });

  /// Retrieves the current execution status of a specific command.
  Future<Command> getCommand(String vehicleId, String commandId);

  /// Retrieves a paginated list of commands sorted descending by default (-requestedAt).
  Future<PagedResult<Command>> listCommands(
    String vehicleId, {
    int? page,
    int? pageSize,
    CommandStatus? status,
    CommandType? commandType,
    DateTime? from,
    DateTime? to,
    String? sort,
  });
}

/// Production implementation of [CommandRepository] using [ApiClient].
class ApiCommandRepository implements CommandRepository {
  ApiCommandRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<Command> submit(
    String vehicleId,
    CommandType type, {
    required String idempotencyKey,
  }) async {
    return apiClient.post<Command>(
      '/vehicles/$vehicleId/commands',
      headers: {
        'Idempotency-Key': idempotencyKey,
      },
      body: {
        'commandType': type.toApi(),
      },
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for Command');
        }
        return Command.fromJson(json);
      },
    );
  }

  @override
  Future<Command> getCommand(String vehicleId, String commandId) async {
    return apiClient.get<Command>(
      '/vehicles/$vehicleId/commands/$commandId',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for Command');
        }
        return Command.fromJson(json);
      },
    );
  }

  @override
  Future<PagedResult<Command>> listCommands(
    String vehicleId, {
    int? page,
    int? pageSize,
    CommandStatus? status,
    CommandType? commandType,
    DateTime? from,
    DateTime? to,
    String? sort,
  }) async {
    final query = <String, dynamic>{
      'page': page ?? 1,
      'pageSize': pageSize ?? AppConstants.commandsPageSize,
      'sort': sort ?? '-requestedAt',
    };

    if (status != null && status != CommandStatus.unknown) {
      query['status'] = status.toApi();
    }
    if (commandType != null && commandType != CommandType.unknown) {
      query['commandType'] = commandType.toApi();
    }
    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }
    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }

    return apiClient.getPaged<Command>(
      '/vehicles/$vehicleId/commands',
      query: query,
      parseItem: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for Command');
        }
        return Command.fromJson(json);
      },
    );
  }
}

/// Provider exposing the [CommandRepository] implementation.
final commandRepositoryProvider = Provider<CommandRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiCommandRepository(apiClient: client);
});
