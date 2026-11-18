import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/app/router.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/auth/presentation/login_page.dart';
import 'package:xev9s_app/features/auth/presentation/register_page.dart';
import 'package:xev9s_app/features/auth/presentation/splash_page.dart';
import 'package:xev9s_app/features/vehicles/application/vehicles_controller.dart';
import 'package:xev9s_app/features/vehicles/domain/vehicle_summary.dart';

void main() {
  const testUser = UserSummary(
    userId: 'usr_001',
    name: 'Aarav Sharma',
    email: 'aarav@example.com',
  );

  group('Router Authentication Guard', () {
    testWidgets('unknown auth state redirects to /splash', (tester) async {
      final router = createAppRouter(
        getAuthState: () => const AuthUnknown(),
        getSelectedVehicleId: () => null,
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(router.state.matchedLocation, equals('/splash'));
      expect(find.byType(SplashPage), findsOneWidget);
    });

    testWidgets('startupFailed auth state renders /splash with error view', (tester) async {
      final failedState = AuthStartupFailed(AppError.noConnection());
      final router = createAppRouter(
        getAuthState: () => failedState,
        getSelectedVehicleId: () => null,
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => FakeAuthController(initialState: failedState)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/splash'));
      expect(find.text("Couldn't load your account"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('unauthenticated state redirects to /login and allows /register', (tester) async {
      final router = createAppRouter(
        getAuthState: () => const AuthUnauthenticated(),
        getSelectedVehicleId: () => null,
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/login'));
      expect(find.byType(LoginPage), findsOneWidget);

      // Navigate to /register
      router.go('/register');
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/register'));
      expect(find.byType(RegisterPage), findsOneWidget);
    });

    testWidgets('authenticated with selected vehicle routes to /home from auth route', (tester) async {
      final router = createAppRouter(
        getAuthState: () => const AuthAuthenticated(testUser),
        getSelectedVehicleId: () => 'veh_001',
        initialLocation: '/login',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(null),
            vehiclesControllerProvider.overrideWith(() => FakeVehiclesController()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/home'));
      expect(find.text('Dashboard Page (Placeholder)'), findsOneWidget);
    });

    testWidgets('authenticated without selected vehicle routes to /vehicles', (tester) async {
      final router = createAppRouter(
        getAuthState: () => const AuthAuthenticated(testUser),
        getSelectedVehicleId: () => null,
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehiclesControllerProvider.overrideWith(() => FakeVehiclesController()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/vehicles'));
    });

    testWidgets('refreshListenable triggers redirect when auth state transitions to unauthenticated', (tester) async {
      AuthState currentAuthState = const AuthAuthenticated(testUser);
      final refreshNotifier = RouterRefreshNotifier();

      final router = createAppRouter(
        getAuthState: () => currentAuthState,
        getSelectedVehicleId: () => 'veh_001',
        refreshListenable: refreshNotifier,
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentVehicleProvider.overrideWithValue(null),
            vehiclesControllerProvider.overrideWith(() => FakeVehiclesController()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/home'));

      // Transition to session expired
      currentAuthState = const AuthUnauthenticated(UnauthenticatedReason.sessionExpired);
      refreshNotifier.trigger();

      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/login'));
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}

class FakeAuthController extends Notifier<AuthState> implements AuthController {
  FakeAuthController({this.initialState = const AuthUnknown()});

  final AuthState initialState;

  @override
  AuthState build() => initialState;

  @override
  Future<void> checkSession() async {}

  @override
  Future<void> login(String identifier, String password) async {}

  @override
  Future<void> register(String name, String email, String password) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> handleSessionExpired() async {}

  @override
  void consumeSessionExpiredReason() {}
}

class FakeVehiclesController extends AsyncNotifier<List<VehicleSummary>>
    implements VehiclesController {
  @override
  Future<List<VehicleSummary>> build() async => [];

  @override
  Future<void> refresh() async {}

  @override
  Future<List<VehicleSummary>> associate({
    required String identifier,
    required String pairingCode,
    String? name,
  }) async =>
      [];
}
