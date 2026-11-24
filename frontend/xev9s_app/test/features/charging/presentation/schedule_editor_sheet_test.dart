import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xev9s_app/features/charging/data/charging_repository.dart';
import 'package:xev9s_app/features/charging/domain/charging_overview.dart';
import 'package:xev9s_app/features/charging/domain/charging_schedule.dart';
import 'package:xev9s_app/features/charging/domain/day_of_week.dart';
import 'package:xev9s_app/features/charging/presentation/widgets/schedule_editor_sheet.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_status.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class MockChargingRepository extends Mock implements ChargingRepository {}

void main() {
  late MockChargingRepository mockRepo;

  setUp(() {
    mockRepo = MockChargingRepository();
  });

  Widget buildSheet({ChargingSchedule? schedule, bool isOffline = false}) {
    return ProviderScope(
      overrides: [
        chargingRepositoryProvider.overrideWithValue(mockRepo),
        selectedVehicleProvider.overrideWith(() => _TestVehicle('veh_9S0001')),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ScheduleEditorSheet(
            initialSchedule: schedule,
            isVehicleOffline: isOffline,
          ),
        ),
      ),
    );
  }

  group('ScheduleEditorSheet Widget Tests', () {
    testWidgets('renders schedule days, enable switch and overnight indicator', (tester) async {
      const schedule = ChargingSchedule(
        enabled: true,
        startTime: ScheduleTime(hour: 22, minute: 0),
        endTime: ScheduleTime(hour: 6, minute: 0),
        daysOfWeek: {DayOfWeek.mon, DayOfWeek.tue, DayOfWeek.wed},
      );

      await tester.pumpWidget(buildSheet(schedule: schedule));
      await tester.pumpAndSettle();

      expect(find.text('Ends the next day'), findsOneWidget);
      expect(find.byKey(const Key('schedule_enable_switch')), findsOneWidget);
      expect(find.byKey(const Key('day_chip_MON')), findsOneWidget);
    });

    testWidgets('shortcuts select Weekdays and Every day', (tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Every day'));
      await tester.pumpAndSettle();

      expect(find.text('22:00 - 06:00, Every day'), findsOneWidget);

      await tester.tap(find.text('Weekdays'));
      await tester.pumpAndSettle();

      expect(find.text('22:00 - 06:00, Mon-Fri'), findsOneWidget);
    });

    testWidgets('deleting schedule shows confirmation dialog', (tester) async {
      const schedule = ChargingSchedule(
        enabled: true,
        startTime: ScheduleTime(hour: 22, minute: 0),
        endTime: ScheduleTime(hour: 6, minute: 0),
        daysOfWeek: {DayOfWeek.mon},
      );

      when(() => mockRepo.deleteSchedule('veh_9S0001')).thenAnswer(
        (_) async => const ChargingOverview(state: ChargingState.notConnected),
      );

      await tester.pumpWidget(buildSheet(schedule: schedule));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schedule_delete_button')));
      await tester.pumpAndSettle();

      expect(find.text('Delete schedule?'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteSchedule('veh_9S0001')).called(1);
    });
  });
}

class _TestVehicle extends SelectedVehicleNotifier {
  _TestVehicle(this.id);
  final String id;
  @override
  String? build() => id;
}
