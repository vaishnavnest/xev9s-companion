import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/app/router.dart';
import 'package:xev9s_app/app/widgets/xev_app_bar.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/dashboard/presentation/dashboard_page.dart';
import 'package:xev9s_app/features/notifications/presentation/notifications_page.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/domain/association_status.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';
import 'package:xev9s_app/features/vehicles/presentation/vehicle_switcher_sheet.dart';
import 'package:xev9s_app/shared/widgets/car_theme_toggle_button.dart';
import 'package:xev9s_app/shared/widgets/xev_logo.dart';

class FakeVehiclesController extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  FakeVehiclesController(this._vehicles);
  final List<VehicleSummary> _vehicles;

  @override
  Future<List<VehicleSummary>> build() async => _vehicles;

  @override
  Future<void> refresh() async {}

  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async =>
      _vehicles;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUser = UserSummary(
    userId: 'usr_001',
    name: 'Aarav Sharma',
    email: 'aarav@example.com',
  );

  const testVehicle = VehicleSummary(
    vehicleId: 'veh_001',
    name: "Asha's XEV 9S",
    model: 'XEV 9S AWD Performance',
    identifier: 'VIN-9S-88219',
    associationStatus: AssociationStatus.associated,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('XevAppBar Component Unit Tests', () {
    testWidgets('renders leftmost splash logo, screen title, notification button and rightmost vehicle name on mobile',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool notificationTapped = false;
      bool logoTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(testVehicle),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: XevAppBar(
                currentTitle: 'Dashboard',
                currentIndex: 0,
                isWide: false,
                onNotificationTap: () => notificationTapped = true,
                onLogoTap: () => logoTapped = true,
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Logo on leftmost
      expect(find.byType(XevAppLogo), findsOneWidget);

      // 2. Screen name
      expect(find.text('Dashboard'), findsOneWidget);

      // 3. Theme toggle is moved from mobile AppBar (now in More)
      expect(find.byType(CarThemeToggleButton), findsNothing);

      // 4. Notifications button with badge
      final notificationBtn = find.byTooltip('Notifications');
      expect(notificationBtn, findsOneWidget);
      await tester.tap(notificationBtn);
      expect(notificationTapped, isTrue);

      // 5. Rightmost vehicle button with selected car name
      expect(find.text("Asha's XEV 9S"), findsOneWidget);

      // Tap logo
      await tester.tap(find.byType(XevAppLogo));
      expect(logoTapped, isTrue);
    });

    testWidgets('renders wide layout (Web) with brand text, vertical divider and expanded vehicle name',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(testVehicle),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: XevAppBar(
                currentTitle: 'Charging',
                currentIndex: 2,
                isWide: true,
                onNotificationTap: () {},
                onLogoTap: () {},
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Brand text on wide Web view
      expect(find.text('XEV 9S'), findsOneWidget);
      // Screen title
      expect(find.text('Charging'), findsOneWidget);
      // Sun/moon theme toggle is present in wide Web view
      expect(find.byType(CarThemeToggleButton), findsOneWidget);
      // Vehicle name
      expect(find.text("Asha's XEV 9S"), findsOneWidget);
    });

    testWidgets('falls back to "Select vehicle" when no vehicle is selected',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: XevAppBar(
                currentTitle: 'Controls',
                currentIndex: 3,
                isWide: false,
                onNotificationTap: () {},
              ),
              body: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select vehicle'), findsOneWidget);
    });
  });

  group('AppShell Integration Tests', () {
    testWidgets('notification button in app bar routes directly to /notifications',
        (tester) async {
      final router = createAppRouter(
        getAuthState: () => const AuthAuthenticated(testUser),
        getSelectedVehicleId: () => 'veh_001',
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(testVehicle),
            vehiclesControllerProvider.overrideWith(
              () => FakeVehiclesController([testVehicle]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Dashboard
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);

      // Tap Notification button in AppBar
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      // Routed to Notifications page, title changes to Notifications
      expect(router.state.matchedLocation, equals('/notifications'));
      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(XevAppBar),
          matching: find.text('Notifications'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('More menu on mobile no longer contains Notifications (moved to AppBar)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createAppRouter(
        getAuthState: () => const AuthAuthenticated(testUser),
        getSelectedVehicleId: () => 'veh_001',
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(testVehicle),
            vehiclesControllerProvider.overrideWith(
              () => FakeVehiclesController([testVehicle]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "More" in the bottom navigation bar
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      // "More" bottom sheet contains Driving & Energy, Profile, and Theme Toggle
      expect(find.text('Driving & Energy'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

      // Notification is NOT in the More bottom sheet anymore (it's in the AppBar)
      final notificationsInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Notifications'),
      );
      expect(notificationsInSheet, findsNothing);
    });

    testWidgets('tapping rightmost vehicle button opens vehicle switcher sheet',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createAppRouter(
        getAuthState: () => const AuthAuthenticated(testUser),
        getSelectedVehicleId: () => 'veh_001',
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(testVehicle),
            vehiclesControllerProvider.overrideWith(
              () => FakeVehiclesController([testVehicle]),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the vehicle switcher button in the AppBar
      await tester.tap(find.text("Asha's XEV 9S"));
      await tester.pumpAndSettle();

      // Switcher sheet is displayed
      expect(find.byType(VehicleSwitcherContent), findsOneWidget);
      expect(find.text('Switch Vehicle'), findsOneWidget);
    });
  });
}
