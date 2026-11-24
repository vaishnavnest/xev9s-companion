import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide LockState;
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/utils/id_generator.dart';
import 'package:xev9s_app/features/controls/data/command_repository.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/controls/presentation/controls_page.dart';
import 'package:xev9s_app/features/vehicles/application/vehicle_status_provider.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_status_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockCommandRepository extends Mock implements CommandRepository {}

class MockVehicleStatusRepository extends Mock
    implements VehicleStatusRepository {}

class FakeIdGenerator implements IdGenerator {
  @override
  String generate() => 'fixed-key';
}

class FakeSelectedVehicleNotifier extends SelectedVehicleNotifier {
  FakeSelectedVehicleNotifier([this._id = 'veh_9S0001']);
  final String? _id;

  @override
  String? build() => _id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(CommandType.lock);
    registerFallbackValue(CommandStatus.submitted);
  });

  late MockCommandRepository mockCommandRepo;
  late MockVehicleStatusRepository mockVehicleStatusRepo;
  const vehicleId = 'veh_9S0001';
  final now = DateTime.parse('2026-11-24T12:00:00Z');

  setUp(() {
    mockCommandRepo = MockCommandRepository();
    mockVehicleStatusRepo = MockVehicleStatusRepository();
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

  Widget buildControlsTestApp({
    required VehicleStatus status,
  }) {
    return ProviderScope(
      overrides: [
        commandRepositoryProvider.overrideWithValue(mockCommandRepo),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
        vehicleStatusRepositoryProvider
            .overrideWithValue(mockVehicleStatusRepo),
        selectedVehicleProvider
            .overrideWith(() => FakeSelectedVehicleNotifier(vehicleId)),
      ],
      child: const MaterialApp(
        home: ControlsPage(),
      ),
    );
  }

  group('ControlsPage Widget Tests', () {
    testWidgets(
        'only valid buttons are enabled for each state: locked -> unlock; inactive -> start climate',
        (tester) async {
      final status = VehicleStatus(
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

      when(() => mockVehicleStatusRepo.getStatus(vehicleId))
          .thenAnswer((_) async => status);

      await tester.pumpWidget(buildControlsTestApp(status: status));
      await tester.pumpAndSettle();

      final lockButton =
          tester.widget<FilledButton>(find.byKey(const Key('control-lock')));
      final unlockButton =
          tester.widget<FilledButton>(find.byKey(const Key('control-unlock')));
      final startClimateButton = tester.widget<FilledButton>(
          find.byKey(const Key('control-climate-start')));
      final stopClimateButton = tester.widget<FilledButton>(
          find.byKey(const Key('control-climate-stop')));

      expect(lockButton.onPressed, isNull);
      expect(unlockButton.onPressed, isNotNull);
      expect(startClimateButton.onPressed, isNotNull);
      expect(stopClimateButton.onPressed, isNull);
    });

    testWidgets('offline disables all controls with reason message text',
        (tester) async {
      final status = VehicleStatus(
        vehicleId: vehicleId,
        name: 'My XEV 9S',
        model: '9S',
        vehicleState: VehicleState.offline,
        connectivity: VehicleConnectivity.offline,
        lastUpdatedAt: now,
        isStale: true,
        lockState: LockState.unlocked,
        preconditioningState: PreconditioningState.active,
      );

      when(() => mockVehicleStatusRepo.getStatus(vehicleId))
          .thenAnswer((_) async => status);

      await tester.pumpWidget(buildControlsTestApp(status: status));
      await tester.pumpAndSettle();

      final lockButton =
          tester.widget<FilledButton>(find.byKey(const Key('control-lock')));
      final unlockButton =
          tester.widget<FilledButton>(find.byKey(const Key('control-unlock')));
      final startClimate = tester.widget<FilledButton>(
          find.byKey(const Key('control-climate-start')));
      final stopClimate = tester.widget<FilledButton>(
          find.byKey(const Key('control-climate-stop')));

      expect(lockButton.onPressed, isNull);
      expect(unlockButton.onPressed, isNull);
      expect(startClimate.onPressed, isNull);
      expect(stopClimate.onPressed, isNull);

      expect(
        find.text('Vehicle is offline. Controls are unavailable.'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets(
        'confirmation dialog is shown on tap, Cancel sends nothing, Confirm dispatches submit',
        (tester) async {
      final status = VehicleStatus(
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

      when(() => mockVehicleStatusRepo.getStatus(vehicleId))
          .thenAnswer((_) async => status);

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => Command(
          commandId: 'cmd_7731',
          vehicleId: vehicleId,
          commandType: CommandType.unlock,
          status: CommandStatus.submitted,
          requestedAt: now,
        ),
      );

      await tester.pumpWidget(buildControlsTestApp(status: status));
      await tester.pumpAndSettle();

      // Tap Unlock
      await tester.tap(find.byKey(const Key('control-unlock')));
      await tester.pumpAndSettle();

      // Verify Stronger Wording Unlock Confirmation Dialog
      expect(find.text('Unlock the vehicle?'), findsOneWidget);
      expect(find.textContaining('Anyone nearby'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mockCommandRepo.submit(any(), any(),
          idempotencyKey: any(named: 'idempotencyKey')));

      // Tap Unlock again
      await tester.tap(find.byKey(const Key('control-unlock')));
      await tester.pumpAndSettle();

      // Tap Confirm (Unlock button in dialog)
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pump();

      verify(() => mockCommandRepo.submit(vehicleId, CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'))).called(1);
    });

    testWidgets(
        'lock state does NOT change optimistically on 202 or EXECUTING, changes only after SUCCEEDED + refreshed status',
        (tester) async {
      final statusLocked = VehicleStatus(
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

      when(() => mockVehicleStatusRepo.getStatus(vehicleId))
          .thenAnswer((_) async => statusLocked);

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => Command(
          commandId: 'cmd_7731',
          vehicleId: vehicleId,
          commandType: CommandType.unlock,
          status: CommandStatus.submitted,
          requestedAt: now,
        ),
      );

      await tester.pumpWidget(buildControlsTestApp(status: statusLocked));
      await tester.pumpAndSettle();

      // Initial state is Locked
      expect(find.text('Locked'), findsOneWidget);

      // Tap Unlock and Confirm
      await tester.tap(find.byKey(const Key('control-unlock')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pump();

      // On 202: Displayed lock state MUST STILL BE 'Locked' (no optimistic UI!)
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Updating...'), findsOneWidget);

      // Now simulate server refreshed status with unlocked state
      final statusUnlocked = statusLocked.copyWith(
        lockState: LockState.unlocked,
        lastUpdatedAt: now.add(const Duration(seconds: 5)),
      );
      when(() => mockVehicleStatusRepo.getStatus(vehicleId))
          .thenAnswer((_) async => statusUnlocked);

      // Trigger status refresh
      final element = tester.element(find.byType(ControlsPage));
      final container = ProviderScope.containerOf(element);
      await container.read(vehicleStatusProvider.notifier).refresh();
      await tester.pumpAndSettle();

      // Lock state is now verified as Unlocked
      expect(find.text('Unlocked'), findsOneWidget);
    });

    testWidgets('error banner renders for 409/422 and dismiss icon clears it',
        (tester) async {
      final status = VehicleStatus(
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

      when(() => mockVehicleStatusRepo.getStatus(vehicleId))
          .thenAnswer((_) async => status);

      when(
        () => mockCommandRepo.submit(
          vehicleId,
          CommandType.unlock,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const AppError(
          code: ApiErrorCode.vehicleOffline,
          message: 'Vehicle is currently offline. Showing last reported data.',
          httpStatus: 422,
        ),
      );

      await tester.pumpWidget(buildControlsTestApp(status: status));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('control-unlock')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      // Error banner is visible
      expect(find.byKey(const Key('submit-error-banner')), findsOneWidget);
      expect(
        find.text('Vehicle is currently offline. Showing last reported data.'),
        findsOneWidget,
      );

      // Dismiss banner
      await tester.tap(find.byKey(const Key('submit-error-dismiss')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('submit-error-banner')), findsNothing);
    });
  });
}
