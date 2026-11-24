import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/analytics/presentation/analytics_page.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/charging/presentation/charging_page.dart';
import '../features/charging/presentation/charging_sessions_page.dart';
import '../features/charging/presentation/charging_session_detail_page.dart';
import '../features/controls/presentation/controls_history_page.dart';
import '../features/controls/presentation/controls_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/location/presentation/location_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/trips/presentation/trips_page.dart';
import '../features/vehicles/presentation/add_vehicle_page.dart';
import '../features/vehicles/presentation/vehicles_page.dart';
import '../features/vehicles/selected_vehicle_provider.dart';
import 'app_shell.dart';

/// Notifier signaling GoRouter to re-evaluate route redirection.
class RouterRefreshNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}

/// Provider managing GoRouter refresh events from auth and vehicle selection changes.
final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, _) => notifier.trigger());
  ref.listen(selectedVehicleProvider, (_, _) => notifier.trigger());
  return notifier;
});

/// Creates a GoRouter instance wired to the application auth lifecycle.
GoRouter createAppRouter({
  required AuthState Function() getAuthState,
  required String? Function() getSelectedVehicleId,
  Listenable? refreshListenable,
  String initialLocation = '/splash',
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final rootKey = navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = getAuthState();
      final selectedVehicleId = getSelectedVehicleId();
      final loc = state.matchedLocation;

      // 1. Unknown or startup failure -> route to /splash
      if (authState is AuthUnknown || authState is AuthStartupFailed) {
        return loc == '/splash' ? null : '/splash';
      }

      // 2. Unauthenticated -> allow /login and /register, otherwise force /login
      if (authState is AuthUnauthenticated) {
        final isAuthRoute = loc == '/login' || loc == '/register';
        return isAuthRoute ? null : '/login';
      }

      // 3. Authenticated
      if (authState is AuthAuthenticated) {
        final hasVehicle = selectedVehicleId != null && selectedVehicleId.isNotEmpty;
        final isOnAuthOrSplash =
            loc == '/login' || loc == '/register' || loc == '/splash' || loc == '/';

        if (isOnAuthOrSplash) {
          return hasVehicle ? '/home' : '/vehicles';
        }

        // If authenticated without a selected vehicle, force /vehicles
        // (except when already on /vehicles, /vehicles/add, or /profile)
        if (!hasVehicle) {
          final isAllowedWithoutVehicle =
              loc == '/vehicles' || loc == '/vehicles/add' || loc == '/profile';
          if (!isAllowedWithoutVehicle) {
            return '/vehicles';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesPage(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddVehiclePage(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/location',
                builder: (context, state) => const LocationPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/charging',
                builder: (context, state) => const ChargingPage(),
                routes: [
                  GoRoute(
                    path: 'sessions',
                    builder: (context, state) => const ChargingSessionsPage(),
                    routes: [
                      GoRoute(
                        path: ':sessionId',
                        builder: (context, state) {
                          final sessionId =
                              state.pathParameters['sessionId'] ?? '';
                          return ChargingSessionDetailPage(sessionId: sessionId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/controls',
                builder: (context, state) => const ControlsPage(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const ControlsHistoryPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (context, state) => const TripsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Riverpod provider for GoRouter. Overridable in tests.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshProvider);

  return createAppRouter(
    getAuthState: () => ref.read(authControllerProvider),
    getSelectedVehicleId: () => ref.read(selectedVehicleProvider),
    refreshListenable: refreshNotifier,
    initialLocation: '/splash',
  );
});
