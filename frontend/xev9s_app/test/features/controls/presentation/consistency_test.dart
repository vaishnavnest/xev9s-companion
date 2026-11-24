import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide LockState;
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/core/network/api_response.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/features/controls/data/command_repository.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/controls/presentation/controls_page.dart';
import 'package:xev9s_app/features/dashboard/presentation/dashboard_page.dart';
import 'package:xev9s_app/features/vehicles/data/vehicle_status_repository.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockVehicleStatusRepository extends Mock
    implements VehicleStatusRepository {}

class MockCommandRepository extends Mock implements CommandRepository {}

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

  late MockVehicleStatusRepository mockVehicleStatusRepo;
  late MockCommandRepository mockCommandRepo;
  late StreamController<RealtimeEvent> eventsController;
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
    mockVehicleStatusRepo = MockVehicleStatusRepository();
    mockCommandRepo = MockCommandRepository();
    eventsController = StreamController<RealtimeEvent>.broadcast();

    when(() => mockVehicleStatusRepo.getStatus(vehicleId))
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
    eventsController.close();
  });

  testWidgets(
      'Consistency: dashboard and controls display the same lock state after vehicle.status event',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        vehicleStatusRepositoryProvider
            .overrideWithValue(mockVehicleStatusRepo),
        commandRepositoryProvider.overrideWithValue(mockCommandRepo),
        realtimeEventsProvider
            .overrideWith((ref) => eventsController.stream),
        selectedVehicleProvider
            .overrideWith(() => FakeSelectedVehicleNotifier(vehicleId)),
      ],
    );

    // Render ControlsPage
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ControlsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);

    // Render DashboardPage
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);

    // Inbound vehicle.status event unlocking the vehicle
    final updatedTime = now.add(const Duration(seconds: 10));
    eventsController.add(
      RealtimeEvent(
        type: RealtimeEventType.vehicleStatus,
        vehicleId: vehicleId,
        timestamp: updatedTime,
        rawData: {
          'vehicleId': vehicleId,
          'vehicleState': 'PARKED',
          'connectivity': 'ONLINE',
          'lockState': 'UNLOCKED',
          'lastUpdatedAt': updatedTime.toIso8601String(),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify Dashboard displays Unlocked
    expect(find.text('Unlocked'), findsOneWidget);

    // Switch back to ControlsPage and verify it displays Unlocked
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ControlsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unlocked'), findsOneWidget);
  });
}
