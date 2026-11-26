import 'package:equatable/equatable.dart';
import '../../vehicles/domain/vehicle_status.dart';
import 'command_status.dart';
import 'command_type.dart';

/// Resulting vehicle state produced by a successful command.
class CommandResultingState extends Equatable {
  const CommandResultingState({
    this.lockState,
    this.preconditioningState,
  });

  final LockState? lockState;
  final PreconditioningState? preconditioningState;

  factory CommandResultingState.fromJson(Map<String, dynamic> json) {
    final rawLock = (json['lockState'] ?? json['lock_state']) as String?;
    final rawPrecon =
        (json['preconditioningState'] ?? json['preconditioning_state']) as String?;
    return CommandResultingState(
      lockState: rawLock != null ? LockState.fromString(rawLock) : null,
      preconditioningState:
          rawPrecon != null ? PreconditioningState.fromString(rawPrecon) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (lockState != null) 'lockState': lockState!.wireValue,
      if (preconditioningState != null)
        'preconditioningState': preconditioningState!.wireValue,
    };
  }

  @override
  List<Object?> get props => [lockState, preconditioningState];
}

/// Domain representation of a remote vehicle command (UC-05).
class Command extends Equatable {
  const Command({
    required this.commandId,
    required this.vehicleId,
    required this.commandType,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.failureReason,
    this.resultingState,
  });

  final String commandId;
  final String vehicleId;
  final CommandType commandType;
  final CommandStatus status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? failureReason;
  final CommandResultingState? resultingState;

  /// Tolerant JSON deserialization supporting both OpenAPI camelCase and
  /// FastAPI backend snake_case payloads.
  /// Throws [FormatException] ONLY if required fields (commandId, vehicleId,
  /// commandType/operation, status, requestedAt) are missing or invalid dates.
  factory Command.fromJson(Map<String, dynamic> json) {
    final rawCommandId = json['commandId'] ?? json['command_id'];
    if (rawCommandId is! String || rawCommandId.trim().isEmpty) {
      throw const FormatException('Missing or invalid commandId');
    }

    final rawVehicleId = json['vehicleId'] ?? json['vehicle_id'];
    if (rawVehicleId is! String || rawVehicleId.trim().isEmpty) {
      throw const FormatException('Missing or invalid vehicleId');
    }

    final rawCommandType = json['commandType'] ?? json['operation'];
    if (rawCommandType == null) {
      throw const FormatException('Missing commandType');
    }
    final commandType = CommandType.fromApi(rawCommandType as String?);

    if (!json.containsKey('status') || json['status'] == null) {
      throw const FormatException('Missing status');
    }
    final status = CommandStatus.fromApi(json['status'] as String?);

    final rawRequestedAt = json['requestedAt'] ?? json['requested_at'];
    if (rawRequestedAt is! String) {
      throw const FormatException('Missing or invalid requestedAt');
    }
    final requestedAt = DateTime.tryParse(rawRequestedAt);
    if (requestedAt == null) {
      throw const FormatException('Invalid requestedAt timestamp');
    }

    DateTime? completedAt;
    final rawCompletedAt = json['completedAt'] ?? json['completed_at'];
    if (rawCompletedAt is String) {
      completedAt = DateTime.tryParse(rawCompletedAt);
    }

    final failureReason =
        (json['failureReason'] ?? json['failure_reason']) as String?;

    CommandResultingState? resultingState;
    final rawResultingState = json['resultingState'] ?? json['resulting_state'];
    if (rawResultingState is Map<String, dynamic>) {
      resultingState = CommandResultingState.fromJson(rawResultingState);
    }

    return Command(
      commandId: rawCommandId,
      vehicleId: rawVehicleId,
      commandType: commandType,
      status: status,
      requestedAt: requestedAt,
      completedAt: completedAt,
      failureReason: failureReason,
      resultingState: resultingState,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'vehicleId': vehicleId,
      'commandType': commandType.toApi(),
      'status': status.toApi(),
      'requestedAt': requestedAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (failureReason != null) 'failureReason': failureReason,
      if (resultingState != null) 'resultingState': resultingState!.toJson(),
    };
  }

  Command copyWith({
    String? commandId,
    String? vehicleId,
    CommandType? commandType,
    CommandStatus? status,
    DateTime? requestedAt,
    DateTime? completedAt,
    String? failureReason,
    CommandResultingState? resultingState,
  }) {
    return Command(
      commandId: commandId ?? this.commandId,
      vehicleId: vehicleId ?? this.vehicleId,
      commandType: commandType ?? this.commandType,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      completedAt: completedAt ?? this.completedAt,
      failureReason: failureReason ?? this.failureReason,
      resultingState: resultingState ?? this.resultingState,
    );
  }

  @override
  List<Object?> get props => [
        commandId,
        vehicleId,
        commandType,
        status,
        requestedAt,
        completedAt,
        failureReason,
        resultingState,
      ];
}
