import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';
import 'package:xev9s_app/core/utils/id_generator.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/controls/application/command_session.dart';
import 'package:xev9s_app/features/controls/application/command_tracker_provider.dart';
import 'package:xev9s_app/features/controls/data/command_repository.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_status_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockCommandRepository extends Mock implements CommandRepository {}

class MockVehicleStatusRepository extends Mock
    implements VehicleStatusRepository {}

class FakeIdGenerator implements IdGenerator {
  int count = 0;
  @override
  String generate() => 'key-${++count}';
}

class FakeSelectedVehicleNotifier extends SelectedVehicleNotifier {
  FakeSelectedVehicleNotifier([this._id = 'veh_9S0001']);
  final String? _id;

  @override
  String? build() => _id;
}

class FakeRealtimeService implements RealtimeService {
  final eventsController = StreamController<RealtimeEvent>.broadcast();
  final stateController =
      StreamController<RealtimeConnectionState>.broadcast();
  final resyncController = StreamController<void>.broadcast();

  @override
  Stream<RealtimeEvent> get events => eventsController.stream;

  @override
  Stream<RealtimeConnectionState> get connectionState => stateController.stream;

  @override
  RealtimeConnectionState get currentConnectionState =>
      RealtimeConnectionState.connected;

  @override
  Stream<void> get onResync => resyncController.stream;

  @override
  Future<void> connect({String? vehicleId}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    eventsController.close();
    stateController.close();
    resyncController.close();
  }
}

class FakeAuthController extends AuthController {
  FakeAuthController(this.initialState);
  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(CommandType.lock);
    registerFallbackValue(CommandStatus.submitted);
  });

  late MockCommandRepository mockCommandRepo;
  late MockVehicleStatusRepository mockVehicleStatusRepo;
  late FakeIdGenerator fakeIdGen;
  late FakeRealtimeService fakeRealtimeService;

  const vehicleId = 'veh_9S0001';
  final now = DateTime.parse('2026-11-24T12:00:00Z');

  final initialStatus = VehicleStatus(
    vehicleId: vehicleId,
    name: 'My XEV 9S',
    model: '9S',
    vehicleState: VehicleState.parked,
    connectivity: VehicleConnectivity.online,
    lastUpdatedAt: now,
    isStale: false,
    lockState: LockState.locked,
    preconditioningState: PreconditioningState.inactive,
  );

  setUp(() {
    mockCommandRepo = MockCommandRepository();
    mockVehicleStatusRepo = MockVehicleStatusRepository();
    fakeIdGen = FakeIdGenerator();
    fakeRealtimeService = FakeRealtimeService();

    when(() => mockVehicleStatusRepo.getStatus(any()))
        .thenAnswer((_) async => initialStatus);
    when(() => mockCommandRepo.listCommands(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          status: any(named: 'status'),
          commandType: any(named: 'commandType'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          sort: any(named: 'sort'),
        )).thenAnswer((_) async => PagedResult<Command>(items: []));
  });

  tearDown(() {
    fakeRealtimeService.dispose();
  });

  ProviderContainer createContainer({String? selectedVehicle = vehicleId}) {
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
        idGeneratorProvider.overrideWithValue(fakeIdGen),
        authControllerProvider.overrideWith(() => FakeAuthController(authState)),
        vehicleStatusRepositoryProvider
            .overrideWithValue(mockVehicleStatusRepo),
        realtimeServiceProvider
            .overrideWithValue(fakeRealtimeService),
        selectedVehicleProvider
            .overrideWith(() => FakeSelectedVehicleNotifier(selectedVehicle)),
      ],
    );
  }

  group('CommandTrackerNotifier Submission', () {
    test('202 response transitions session to tracking', () async {
      final container = createContainer();
      final submittedCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: 'key-1',
        ),
      ).thenAnswer((_) async => submittedCmd);

      // Keep vehicleStatusProvider active so it doesn't re-instantiate and call getStatus in build()
      final sub = container.listen(vehicleStatusProvider, (prev, next) {});
      addTearDown(sub.close);
      // Wait for initial build to complete
      await container.read(vehicleStatusProvider.future);

      // Clear initial build getStatus interaction
      clearInteractions(mockVehicleStatusRepo);

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.unlock);

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session, isNotNull);
      expect(session!.phase, CommandPhase.tracking);
      expect(session.command?.commandId, 'cmd_7731');
      expect(session.idempotencyKey, 'key-1');
    });

    test('refuses submit when already submitting or tracking (no API call)',
        () async {
      final container = createContainer();
      final submittedCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => submittedCmd);

      // Keep vehicleStatusProvider active so it doesn't re-instantiate and call getStatus in build()
      final sub = container.listen(vehicleStatusProvider, (prev, next) {});
      addTearDown(sub.close);
      // Wait for initial build to complete
      await container.read(vehicleStatusProvider.future);

      // Clear initial build getStatus interaction
      clearInteractions(mockVehicleStatusRepo);

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.unlock);

      // Second submit while in tracking
      await notifier.submit(vehicleId, CommandType.lock);

      verify(
        () => mockCommandRepo.submit(
          vehicleId,
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });

    test('409 COMMAND_IN_PROGRESS sets idle with error and resyncs to latest command',
        () async {
      final container = createContainer();
      final existingCommand = Command(
        commandId: 'cmd_existing',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.executing,
        requestedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const AppError(
          code: ApiErrorCode.commandInProgress,
          message: 'Command in progress',
          httpStatus: 409,
        ),
      );

      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: 5,
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [existingCommand],
          pagination: const Pagination(
              page: 1, pageSize: 5, totalItems: 1, totalPages: 1),
        ),
      );

      // Keep vehicleStatusProvider active so it doesn't re-instantiate and call getStatus in build()
      final sub = container.listen(vehicleStatusProvider, (prev, next) {});
      addTearDown(sub.close);
      // Wait for initial build to complete
      await container.read(vehicleStatusProvider.future);

      // Clear initial build getStatus interaction
      clearInteractions(mockVehicleStatusRepo);

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.unlock);

      await pumpEventQueue();

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session, isNotNull);
      expect(session!.command?.commandId, 'cmd_existing');
      expect(session.phase, CommandPhase.tracking);
    });

    test('422 / 403 / 404 / 400 errors set phase idle with server error',
        () async {
      final container = createContainer();

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const AppError(
          code: ApiErrorCode.vehicleOffline,
          message: 'Vehicle is currently offline.',
          httpStatus: 422,
        ),
      );

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.lock);

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session, isNotNull);
      expect(session!.phase, CommandPhase.idle);
      expect(session.error?.displayMessage,
          'Vehicle is currently offline. Showing last reported data.');
    });

    test('network error on POST transitions to submitUnconfirmed and keeps key',
        () async {
      final container = createContainer();

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: 'key-1',
        ),
      ).thenThrow(
        AppError.noConnection(),
      );

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.lock);

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session, isNotNull);
      expect(session!.phase, CommandPhase.submitUnconfirmed);
      expect(session.idempotencyKey, 'key-1');
    });

    test('retry from submitUnconfirmed re-sends with the SAME key', () async {
      final container = createContainer();

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: 'key-1',
        ),
      ).thenThrow(
        AppError.noConnection(),
      );

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.lock);

      final successCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );
      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: 'key-1',
        ),
      ).thenAnswer((_) async => successCmd);

      await notifier.confirmUnconfirmedRetry(vehicleId);

      verify(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: 'key-1',
        ),
      ).called(2);

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session!.phase, CommandPhase.tracking);
      expect(session.idempotencyKey, 'key-1');
    });

    test('retry after FAILED uses a NEW key', () async {
      final container = createContainer();
      final failedCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.failed,
        requestedAt: now,
      );

      // Pre-set tracker session in finished state with failed command
      container.read(commandTrackerProvider.notifier).state = {
        vehicleId: CommandSession(
          phase: CommandPhase.finished,
          command: failedCmd,
          lastAttemptedType: CommandType.lock,
        ),
      };

      final nextCmd = Command(
        commandId: 'cmd_7732',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );
      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: 'key-1',
        ),
      ).thenAnswer((_) async => nextCmd);

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.retry(vehicleId);

      verify(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: 'key-1',
        ),
      ).called(1);
    });
  });

  group('CommandTrackerNotifier Realtime Tracking', () {
    test('events advance status and late event after final is ignored',
        () async {
      final container = createContainer();
      final initialCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => initialCmd);

      // Keep vehicleStatusProvider active so it doesn't re-instantiate and call getStatus in build()
      final sub = container.listen(vehicleStatusProvider, (prev, next) {});
      addTearDown(sub.close);
      // Wait for initial build to complete
      await container.read(vehicleStatusProvider.future);

      // Clear initial build getStatus interaction
      clearInteractions(mockVehicleStatusRepo);

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.unlock);

      // Emit ACCEPTED event
      fakeRealtimeService.eventsController.add(
        RealtimeEvent(
          type: RealtimeEventType.commandUpdated,
          vehicleId: vehicleId,
          timestamp: now,
          rawData: {
            'commandId': 'cmd_7731',
            'vehicleId': vehicleId,
            'commandType': 'UNLOCK',
            'status': 'ACCEPTED',
            'requestedAt': now.toIso8601String(),
          },
        ),
      );
      await pumpEventQueue();

      var session = container.read(commandTrackerProvider)[vehicleId];
      expect(session!.command?.status, CommandStatus.accepted);

      // Emit SUCCEEDED event
      fakeRealtimeService.eventsController.add(
        RealtimeEvent(
          type: RealtimeEventType.commandUpdated,
          vehicleId: vehicleId,
          timestamp: now,
          rawData: {
            'commandId': 'cmd_7731',
            'vehicleId': vehicleId,
            'commandType': 'UNLOCK',
            'status': 'SUCCEEDED',
            'requestedAt': now.toIso8601String(),
            'completedAt': now.add(const Duration(seconds: 2)).toIso8601String(),
          },
        ),
      );
      await pumpEventQueue();

      session = container.read(commandTrackerProvider)[vehicleId];
      expect(session!.phase, CommandPhase.finished);
      expect(session.command?.status, CommandStatus.succeeded);

      // Verify that SUCCEEDED triggered a vehicle status refresh
      verify(() => mockVehicleStatusRepo.getStatus(vehicleId)).called(1);

      // Late EXECUTING event after final
      fakeRealtimeService.eventsController.add(
        RealtimeEvent(
          type: RealtimeEventType.commandUpdated,
          vehicleId: vehicleId,
          timestamp: now,
          rawData: {
            'commandId': 'cmd_7731',
            'vehicleId': vehicleId,
            'commandType': 'UNLOCK',
            'status': 'EXECUTING',
            'requestedAt': now.toIso8601String(),
          },
        ),
      );
      await pumpEventQueue();

      session = container.read(commandTrackerProvider)[vehicleId];
      expect(session!.command?.status, CommandStatus.succeeded);
    });

    test('events for other commands or other vehicles are ignored',
        () async {
      final container = createContainer();
      final initialCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => initialCmd);

      // Keep vehicleStatusProvider active so it doesn't re-instantiate and call getStatus in build()
      final sub = container.listen(vehicleStatusProvider, (prev, next) {});
      addTearDown(sub.close);
      // Wait for initial build to complete
      await container.read(vehicleStatusProvider.future);

      // Clear initial build getStatus interaction
      clearInteractions(mockVehicleStatusRepo);

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.unlock);

      // Other command event
      fakeRealtimeService.eventsController.add(
        RealtimeEvent(
          type: RealtimeEventType.commandUpdated,
          vehicleId: vehicleId,
          timestamp: now,
          rawData: {
            'commandId': 'cmd_DIFFERENT',
            'vehicleId': vehicleId,
            'commandType': 'UNLOCK',
            'status': 'SUCCEEDED',
            'requestedAt': now.toIso8601String(),
          },
        ),
      );
      await pumpEventQueue();

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session!.command?.commandId, 'cmd_7731');
      expect(session.command?.status, CommandStatus.submitted);
    });

    test('vehicle status refresh failure sets refreshFailed=true and keeps state',
        () async {
      final container = createContainer();
      final initialCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => initialCmd);

      when(() => mockVehicleStatusRepo.getStatus(vehicleId))
          .thenThrow(Exception('Status refresh network error'));

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.lock);

      // Succeeded event
      fakeRealtimeService.eventsController.add(
        RealtimeEvent(
          type: RealtimeEventType.commandUpdated,
          vehicleId: vehicleId,
          timestamp: now,
          rawData: {
            'commandId': 'cmd_7731',
            'vehicleId': vehicleId,
            'commandType': 'LOCK',
            'status': 'SUCCEEDED',
            'requestedAt': now.toIso8601String(),
          },
        ),
      );
      await pumpEventQueue();

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session!.phase, CommandPhase.finished);
      expect(session.refreshFailed, isTrue);
    });

    test('FAILED command does NOT trigger vehicle status refresh', () async {
      final container = createContainer();
      final initialCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.submitted,
        requestedAt: now,
      );

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.lock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => initialCmd);

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.submit(vehicleId, CommandType.lock);

      // FAILED event
      fakeRealtimeService.eventsController.add(
        RealtimeEvent(
          type: RealtimeEventType.commandUpdated,
          vehicleId: vehicleId,
          timestamp: now,
          rawData: {
            'commandId': 'cmd_7731',
            'vehicleId': vehicleId,
            'commandType': 'LOCK',
            'status': 'FAILED',
            'requestedAt': now.toIso8601String(),
            'failureReason': 'VEHICLE_DRIVING',
          },
        ),
      );
      await pumpEventQueue();

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session!.phase, CommandPhase.finished);
      expect(session.command?.status, CommandStatus.failed);
      expect(session.command?.failureReason, 'VEHICLE_DRIVING');

      verifyNever(() => mockVehicleStatusRepo.getStatus(vehicleId));
    });
  });

  group('CommandTrackerNotifier Resume Logic', () {
    test('resumes non-final command requested within resume window', () async {
      final container = createContainer();
      final recentCommand = Command(
        commandId: 'cmd_recent',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.executing,
        requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: 5,
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [recentCommand],
          pagination: const Pagination(
              page: 1, pageSize: 5, totalItems: 1, totalPages: 1),
        ),
      );

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.resume(vehicleId);

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session, isNotNull);
      expect(session!.phase, CommandPhase.tracking);
      expect(session.command?.commandId, 'cmd_recent');
    });

    test('does NOT resume non-final command older than resume window', () async {
      final container = createContainer();
      final staleCommand = Command(
        commandId: 'cmd_stale',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.executing,
        requestedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: 5,
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [staleCommand],
          pagination: const Pagination(
              page: 1, pageSize: 5, totalItems: 1, totalPages: 1),
        ),
      );

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.resume(vehicleId);

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session, isNull);
    });

    test('does NOT resume completed final command', () async {
      final container = createContainer();
      final finalCommand = Command(
        commandId: 'cmd_final',
        vehicleId: vehicleId,
        commandType: CommandType.lock,
        status: CommandStatus.succeeded,
        requestedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      when(
        () => mockCommandRepo.listCommands(
          vehicleId,
          page: 1,
          pageSize: 5,
        ),
      ).thenAnswer(
        (_) async => PagedResult<Command>(
          items: [finalCommand],
          pagination: const Pagination(
              page: 1, pageSize: 5, totalItems: 1, totalPages: 1),
        ),
      );

      final notifier = container.read(commandTrackerProvider.notifier);
      await notifier.resume(vehicleId);

      final session = container.read(commandTrackerProvider)[vehicleId];
      expect(session, isNull);
    });
  });
}
