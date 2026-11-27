import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/app/router.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/theme/app_theme.dart';
import 'package:xev9s_app/core/theme/theme_provider.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/auth/presentation/help_support_page.dart';
import 'package:xev9s_app/features/auth/presentation/legal_document_page.dart';
import 'package:xev9s_app/features/auth/presentation/login_page.dart';
import 'package:xev9s_app/features/auth/presentation/register_page.dart';
import 'package:xev9s_app/features/auth/presentation/splash_page.dart';
import 'package:xev9s_app/features/dashboard/presentation/dashboard_page.dart';
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

    testWidgets('unauthenticated state allows /help, /terms, and /privacy via UI navigation', (tester) async {
      final router = createAppRouter(
        getAuthState: () => const AuthUnauthenticated(),
        getSelectedVehicleId: () => null,
        initialLocation: '/login',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Tap help icon on LoginPage -> routes to /help
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/help'));
      expect(find.byType(HelpSupportPage), findsOneWidget);

      // Navigate to /register and tap Terms of Service -> routes to /terms
      router.go('/register');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/terms'));
      expect(find.byType(TermsOfServicePage), findsOneWidget);

      // Pop back to /register and tap Privacy Policy -> routes to /privacy
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/privacy'));
      expect(find.byType(PrivacyPolicyPage), findsOneWidget);
    });

    testWidgets('help and legal pages adapt automatically to app light and dark themes', (tester) async {
      final router = createAppRouter(
        getAuthState: () => const AuthUnauthenticated(),
        getSelectedVehicleId: () => null,
        initialLocation: '/help',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeModeProvider);
              return MaterialApp.router(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HelpSupportPage), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsNothing);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsNothing);
      expect(
        Theme.of(tester.element(find.byType(HelpSupportPage))).brightness,
        Brightness.light,
      );

      await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(HelpSupportPage))).brightness,
        Brightness.dark,
      );

      router.go('/terms');
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServicePage), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(TermsOfServicePage))).brightness,
        Brightness.dark,
      );

      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(LoginPage))).brightness,
        Brightness.dark,
      );

      router.go('/register');
      await tester.pumpAndSettle();
      expect(find.byType(RegisterPage), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(RegisterPage))).brightness,
        Brightness.dark,
      );
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
      expect(find.byType(DashboardPage), findsOneWidget);
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
  void reset() {}
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
