import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/app/global_command_result_listener.dart';
import 'package:xev9s_app/app/router.dart';
import 'package:xev9s_app/features/controls/application/command_session.dart';
import 'package:xev9s_app/features/controls/application/command_tracker_provider.dart';
import 'package:xev9s_app/features/controls/domain/command.dart';
import 'package:xev9s_app/features/controls/domain/command_status.dart';
import 'package:xev9s_app/features/controls/domain/command_type.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';

class _TestVehiclesController extends VehiclesController {
  _TestVehiclesController(this._vehicles);
  final List<VehicleSummary> _vehicles;

  @override
  FutureOr<List<VehicleSummary>> build() => _vehicles;
}

void main() {
  const vehicleId = 'veh_9S0001';
  final now = DateTime.parse('2026-11-24T12:00:00Z');

  const dummyVehicle = VehicleSummary(
    vehicleId: vehicleId,
    name: 'My Falcon 9S',
    model: '9S',
    identifier: 'VIN1234567890',
    associationStatus: AssociationStatus.associated,
  );

  group('GlobalCommandResultListener Widget Tests', () {
    testWidgets(
        'shows snackbar with vehicle name when command succeeds while on /home',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(
              body: Text('Home Page'),
            ),
          ),
          GoRoute(
            path: '/controls',
            builder: (context, state) => const Scaffold(
              body: Text('Controls Page'),
            ),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          routerProvider.overrideWithValue(router),
          vehiclesControllerProvider
              .overrideWith(() => _TestVehiclesController([dummyVehicle])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => GlobalCommandResultListener(
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Page'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // Trigger SUCCEEDED command update
      final succeededCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.succeeded,
        requestedAt: now,
        completedAt: now.add(const Duration(seconds: 3)),
      );

      container.read(commandTrackerProvider.notifier).state = {
        vehicleId: CommandSession(
          phase: CommandPhase.finished,
          command: succeededCmd,
        ),
      };
      await tester.pumpAndSettle();

      // Snackbar is shown with View action
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Unlock succeeded for My Falcon 9S'),
        findsOneWidget,
      );
      expect(find.text('View'), findsOneWidget);

      // Second state change with the same command does NOT show duplicate snackbar
      container.read(commandTrackerProvider.notifier).state = {
        vehicleId: CommandSession(
          phase: CommandPhase.finished,
          command: succeededCmd,
        ),
      };
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('does NOT show snackbar when user is currently on /controls',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/controls',
        routes: [
          GoRoute(
            path: '/controls',
            builder: (context, state) => const Scaffold(
              body: Text('Controls Page'),
            ),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          routerProvider.overrideWithValue(router),
          vehiclesControllerProvider
              .overrideWith(() => _TestVehiclesController([dummyVehicle])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => GlobalCommandResultListener(
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final succeededCmd = Command(
        commandId: 'cmd_7731',
        vehicleId: vehicleId,
        commandType: CommandType.unlock,
        status: CommandStatus.succeeded,
        requestedAt: now,
      );

      container.read(commandTrackerProvider.notifier).state = {
        vehicleId: CommandSession(
          phase: CommandPhase.finished,
          command: succeededCmd,
        ),
      };
      await tester.pumpAndSettle();

      // On /controls, NO snackbar should be displayed
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
