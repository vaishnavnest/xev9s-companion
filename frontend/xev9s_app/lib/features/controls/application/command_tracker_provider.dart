import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/realtime/realtime_providers.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/utils/id_generator.dart';
import '../../auth/application/auth_controller.dart';
import '../../vehicles/application/vehicle_status_provider.dart';
import '../../vehicles/domain/realtime_event.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../data/command_repository.dart';
import '../domain/command.dart';
import '../domain/command_status.dart';
import '../domain/command_status_machine.dart';
import '../domain/command_type.dart';
import '../presentation/providers/command_history_provider.dart';
import 'command_session.dart';

/// Single source of truth for remote command execution and tracking (UC-05).
/// Maps vehicleId -> CommandSession so tracking survives tab navigation and
/// vehicle switching without cancellation.
class CommandTrackerNotifier extends Notifier<Map<String, CommandSession>> {
  late CommandRepository _repository;
  late IdGenerator _idGenerator;

  final Map<String, Timer> _trackingTimers = {};
  final Map<String, DateTime> _lastEventTimes = {};
  final Map<String, DateTime> _lastPollTimes = {};
  final Map<String, bool> _isPolling = {};

  @override
  Map<String, CommandSession> build() {
    _repository = ref.watch(commandRepositoryProvider);
    _idGenerator = ref.watch(idGeneratorProvider);

    // Clear and terminate all tracking on user logout
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthUnauthenticated) {
        _disposeAllTimers();
        state = {};
      }
    });

    // Check resume condition when active vehicle changes
    ref.listen(selectedVehicleProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        final currentSession = state[next];
        if (currentSession == null || currentSession.phase == CommandPhase.idle) {
          resume(next);
        }
      }
    });

    // Inbound WebSocket push event listener
    final realtimeService = ref.watch(realtimeServiceProvider);
    final eventsSub = realtimeService.events.listen((event) {
      if (event.type != RealtimeEventType.commandUpdated) return;
      _handleRealtimeCommandUpdate(event);
    });

    // Synthetic or reconnection resync signals
    final resyncSub = realtimeService.onResync.listen((_) {
      _handleResyncSignal();
    });

    ref.onDispose(() {
      eventsSub.cancel();
      resyncSub.cancel();
      _disposeAllTimers();
    });

    // Initial vehicle check
    final initialVehicleId = ref.watch(selectedVehicleProvider);
    if (initialVehicleId != null && initialVehicleId.isNotEmpty) {
      Future.microtask(() => resume(initialVehicleId));
    }

    return {};
  }

  void _disposeAllTimers() {
    for (final timer in _trackingTimers.values) {
      timer.cancel();
    }
    _trackingTimers.clear();
    _lastEventTimes.clear();
    _lastPollTimes.clear();
    _isPolling.clear();
  }

  void _disposeTimer(String vehicleId) {
    _trackingTimers[vehicleId]?.cancel();
    _trackingTimers.remove(vehicleId);
    _lastEventTimes.remove(vehicleId);
    _lastPollTimes.remove(vehicleId);
    _isPolling.remove(vehicleId);
  }

  /// Submits a new user remote command.
  /// Refuses submission if a command is already submitting or actively tracking.
  Future<void> submit(String vehicleId, CommandType type) async {
    final session = state[vehicleId] ?? const CommandSession();
    if (session.phase == CommandPhase.submitting ||
        session.phase == CommandPhase.tracking) {
      // Refuse: a command is already in flight for this vehicle
      return;
    }

    final key = _idGenerator.generate();
    final now = DateTime.now();

    state = {
      ...state,
      vehicleId: session.copyWith(
        phase: CommandPhase.submitting,
        idempotencyKey: key,
        lastAttemptedType: type,
        startedAt: now,
        clearError: true,
        waitingTooLong: false,
        stoppedWaiting: false,
        refreshFailed: false,
      ),
    };

    try {
      final response = await _repository.submit(
        vehicleId,
        type,
        idempotencyKey: key,
      );

      // On 202: command = response, phase = tracking
      state = {
        ...state,
        vehicleId: (state[vehicleId] ?? session).copyWith(
          command: response,
          phase: CommandPhase.tracking,
          startedAt: now,
          clearError: true,
        ),
      };

      _startTracking(vehicleId, response);
    } catch (e) {
      _handleSubmitError(vehicleId, e, key, type);
    }
  }

  void _handleSubmitError(
    String vehicleId,
    Object e,
    String key,
    CommandType type,
  ) {
    final session = state[vehicleId] ?? const CommandSession();

    if (e is AppError) {
      if (e.httpStatus == 409) {
        // 409 COMMAND_IN_PROGRESS: phase = idle, error set; resync latest command
        state = {
          ...state,
          vehicleId: session.copyWith(
            phase: CommandPhase.idle,
            error: e,
          ),
        };
        resume(vehicleId);
        return;
      }

      if (e.kind == AppErrorKind.noConnection || e.kind == AppErrorKind.timeout) {
        // Network error / timeout during POST (outcome unknown):
        // phase = submitUnconfirmed, KEEP the idempotency key.
        state = {
          ...state,
          vehicleId: session.copyWith(
            phase: CommandPhase.submitUnconfirmed,
            idempotencyKey: key,
            lastAttemptedType: type,
            error: e,
          ),
        };
        return;
      }

      // 400, 403, 404, 422, 5xx: phase = idle with server error
      state = {
        ...state,
        vehicleId: session.copyWith(
          phase: CommandPhase.idle,
          error: e,
        ),
      };
      return;
    }

    // Generic fallback network error
    state = {
      ...state,
      vehicleId: session.copyWith(
        phase: CommandPhase.submitUnconfirmed,
        idempotencyKey: key,
        lastAttemptedType: type,
        error: AppError.noConnection(
          "We couldn't confirm that the request was sent.",
        ),
      ),
    };
  }

  /// Re-attempts submission from submitUnconfirmed state using the SAME stored idempotency key.
  Future<void> confirmUnconfirmedRetry(String vehicleId) async {
    final session = state[vehicleId];
    if (session == null || session.phase != CommandPhase.submitUnconfirmed) {
      return;
    }

    final key = session.idempotencyKey ?? _idGenerator.generate();
    final type = session.lastAttemptedType ?? CommandType.unknown;
    final now = DateTime.now();

    state = {
      ...state,
      vehicleId: session.copyWith(
        phase: CommandPhase.submitting,
        startedAt: now,
        clearError: true,
      ),
    };

    try {
      final response = await _repository.submit(
        vehicleId,
        type,
        idempotencyKey: key,
      );

      state = {
        ...state,
        vehicleId: (state[vehicleId] ?? session).copyWith(
          command: response,
          phase: CommandPhase.tracking,
          startedAt: now,
          clearError: true,
        ),
      };

      _startTracking(vehicleId, response);
    } catch (e) {
      _handleSubmitError(vehicleId, e, key, type);
    }
  }

  /// Retries a finished FAILED or TIMED_OUT command with a NEW idempotency key.
  Future<void> retry(String vehicleId) async {
    final session = state[vehicleId];
    if (session == null || session.phase != CommandPhase.finished) return;

    final type = session.command?.commandType ?? session.lastAttemptedType;
    if (type == null || type == CommandType.unknown) return;

    await submit(vehicleId, type);
  }

  /// Dismisses a completed (finished) command session back to idle.
  void dismiss(String vehicleId) {
    final session = state[vehicleId];
    if (session == null) return;
    _disposeTimer(vehicleId);
    state = {
      ...state,
      vehicleId: const CommandSession(),
    };
  }

  /// Attempts to resume tracking a pending command on page build / vehicle change / login.
  Future<void> resume(String vehicleId) async {
    try {
      final paged = await _repository.listCommands(
        vehicleId,
        page: 1,
        pageSize: 5,
      );

      if (paged.items.isEmpty) return;

      final newest = paged.items.first;
      if (!newest.status.isFinal) {
        final age = DateTime.now().difference(newest.requestedAt);
        if (age <= const Duration(minutes: AppConstants.commandResumeWindowMinutes)) {
          state = {
            ...state,
            vehicleId: CommandSession(
              command: newest,
              phase: CommandPhase.tracking,
              startedAt: newest.requestedAt,
              lastAttemptedType: newest.commandType,
            ),
          };
          _startTracking(vehicleId, newest);
        }
      }
    } catch (_) {
      // Ignore background resume failures
    }
  }

  /// Triggers an immediate REST poll for the tracked command.
  Future<void> refreshTrackedCommand(String vehicleId) async {
    final session = state[vehicleId];
    if (session == null ||
        session.phase != CommandPhase.tracking ||
        session.command == null) {
      return;
    }
    await _pollCommand(vehicleId, session.command!.commandId);
  }

  /// Re-attempts refreshing the vehicle status after a failed refresh upon SUCCEEDED command.
  Future<void> retryVehicleStatusRefresh(String vehicleId) async {
    final session = state[vehicleId];
    if (session == null) return;

    try {
      final statusNotifier = ref.read(vehicleStatusProvider.notifier);
      await statusNotifier.refresh();
      final hasRefreshError = statusNotifier.lastRefreshError != null;
      state = {
        ...state,
        vehicleId: session.copyWith(refreshFailed: hasRefreshError),
      };
    } catch (_) {
      state = {
        ...state,
        vehicleId: session.copyWith(refreshFailed: true),
      };
    }
  }

  void _startTracking(String vehicleId, Command initialCommand) {
    _disposeTimer(vehicleId);

    final now = DateTime.now();
    _lastEventTimes[vehicleId] = now;
    _lastPollTimes[vehicleId] = now;
    _isPolling[vehicleId] = false;

    // Periodic timer checking safety polling and client wait limits
    _trackingTimers[vehicleId] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _onTrackingTick(vehicleId, initialCommand.commandId),
    );
  }

  void _onTrackingTick(String vehicleId, String commandId) {
    final session = state[vehicleId];
    if (session == null || session.phase != CommandPhase.tracking) {
      _disposeTimer(vehicleId);
      return;
    }

    final now = DateTime.now();
    final startedAt = session.startedAt ?? session.command?.requestedAt ?? now;
    final elapsedSeconds = now.difference(startedAt).inSeconds;

    // Hard cap of 10 minutes (600s) -> stop tracking
    if (elapsedSeconds >= 600) {
      _disposeTimer(vehicleId);
      state = {
        ...state,
        vehicleId: session.copyWith(
          waitingTooLong: true,
          stoppedWaiting: true,
        ),
      };
      return;
    }

    // After commandClientWaitLimitSeconds (60s) -> set waitingTooLong = true
    if (elapsedSeconds >= AppConstants.commandClientWaitLimitSeconds &&
        !session.waitingTooLong) {
      state = {
        ...state,
        vehicleId: session.copyWith(waitingTooLong: true),
      };
    }

    // Polling checks
    final isPollingMode = AppConfig.realtimeMode == RealtimeMode.polling;
    final connState = ref.read(realtimeConnectionStateProvider).value;
    final isDisconnected = connState != RealtimeConnectionState.connected;

    final lastPoll = _lastPollTimes[vehicleId] ?? now;
    final pollElapsed = now.difference(lastPoll).inSeconds;

    if (isPollingMode || isDisconnected) {
      // Polling mode: GET every commandPollIntervalSeconds
      if (pollElapsed >= AppConstants.commandPollIntervalSeconds) {
        _pollCommand(vehicleId, commandId);
      }
    } else {
      // WebSocket connected: poll only after silence
      final lastEvent = _lastEventTimes[vehicleId] ?? now;
      final silenceElapsed = now.difference(lastEvent).inSeconds;

      if (silenceElapsed >= AppConstants.commandSilenceBeforeSafetyPollSeconds) {
        // Poll every commandPollIntervalSeconds * 2
        final safetyPollInterval = AppConstants.commandPollIntervalSeconds * 2;
        if (pollElapsed >= safetyPollInterval) {
          _pollCommand(vehicleId, commandId);
        }
      }
    }
  }

  Future<void> _pollCommand(String vehicleId, String commandId) async {
    if (_isPolling[vehicleId] == true) return;
    _isPolling[vehicleId] = true;
    _lastPollTimes[vehicleId] = DateTime.now();

    try {
      final incoming = await _repository.getCommand(vehicleId, commandId);
      _applyCommandUpdate(vehicleId, incoming);
    } catch (_) {
      // Transient poll failures are safely swallowed
    } finally {
      _isPolling[vehicleId] = false;
    }
  }

  void _handleRealtimeCommandUpdate(RealtimeEvent event) {
    if (event.rawData == null) return;
    try {
      final map = Map<String, dynamic>.from(event.rawData!);
      if (!map.containsKey('vehicleId') || map['vehicleId'] == null) {
        map['vehicleId'] = event.vehicleId;
      }
      final incoming = Command.fromJson(map);
      _lastEventTimes[incoming.vehicleId] = DateTime.now();
      _applyCommandUpdate(incoming.vehicleId, incoming);
    } catch (_) {
      // Malformed push events safely ignored
    }
  }

  void _handleResyncSignal() {
    for (final entry in state.entries) {
      if (entry.value.phase == CommandPhase.tracking &&
          entry.value.command != null) {
        _pollCommand(entry.key, entry.value.command!.commandId);
      }
    }
  }

  void _applyCommandUpdate(String vehicleId, Command incoming) {
    final session = state[vehicleId];
    if (session == null ||
        session.phase != CommandPhase.tracking ||
        session.command == null) {
      return;
    }

    if (session.command!.commandId != incoming.commandId) {
      // Ignore updates for other commands
      return;
    }

    final updated = CommandStatusMachine.apply(session.command!, incoming);

    if (updated.status.isFinal) {
      _handleFinalStatus(vehicleId, updated);
    } else {
      state = {
        ...state,
        vehicleId: session.copyWith(command: updated),
      };
    }
  }

  Future<void> _handleFinalStatus(String vehicleId, Command finalCommand) async {
    _disposeTimer(vehicleId);

    final session = state[vehicleId] ?? const CommandSession();

    if (finalCommand.status == CommandStatus.succeeded) {
      // Succeeded: update session and force refresh vehicleStatusProvider
      state = {
        ...state,
        vehicleId: session.copyWith(
          phase: CommandPhase.finished,
          command: finalCommand,
          refreshFailed: false,
        ),
      };

      try {
        final statusNotifier = ref.read(vehicleStatusProvider.notifier);
        await statusNotifier.refresh();
        if (statusNotifier.lastRefreshError != null) {
          state = {
            ...state,
            vehicleId: (state[vehicleId] ?? session).copyWith(
              refreshFailed: true,
            ),
          };
        }
      } catch (_) {
        state = {
          ...state,
          vehicleId: (state[vehicleId] ?? session).copyWith(
            refreshFailed: true,
          ),
        };
      }
    } else {
      // FAILED / TIMED_OUT: do not touch vehicle state
      state = {
        ...state,
        vehicleId: session.copyWith(
          phase: CommandPhase.finished,
          command: finalCommand,
          refreshFailed: false,
        ),
      };
    }

    // Refresh history provider whenever a tracked command reaches final status
    try {
      ref.read(commandHistoryProvider.notifier).refresh();
    } catch (_) {}
  }
}

/// Global provider for the remote command tracker.
final commandTrackerProvider =
    NotifierProvider<CommandTrackerNotifier, Map<String, CommandSession>>(
  CommandTrackerNotifier.new,
);
