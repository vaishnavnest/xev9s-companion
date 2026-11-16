import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/network/auth_interceptor.dart';
import '../core/providers.dart';
import '../core/storage/token_storage.dart';
import '../features/analytics/presentation/analytics_page.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/charging/presentation/charging_page.dart';
import '../features/controls/presentation/controls_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/location/presentation/location_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/trips/presentation/trips_page.dart';
import '../features/vehicles/presentation/vehicles_page.dart';
import 'app_shell.dart';

/// Helper class converting a Stream into a Listenable for GoRouter refresh.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Creates a GoRouter instance with authentication guard and session-expiry handling.
GoRouter createAppRouter({
  required TokenStorage tokenStorage,
  Stream<AuthEvent>? authEvents,
  String initialLocation = '/home',
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final rootKey = navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    refreshListenable: authEvents != null ? GoRouterRefreshStream(authEvents) : null,
    redirect: (BuildContext context, GoRouterState state) async {
      final token = await tokenStorage.getAccessToken();
      final isLoggedIn = token != null && token.isNotEmpty;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      // If user is unauthenticated, redirect to login unless already on auth route
      if (!isLoggedIn) {
        return isAuthRoute ? null : '/login';
      }

      // If user is already authenticated and attempts to access login/register, redirect to home
      if (isAuthRoute || loc == '/') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthPage(isRegister: false),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const AuthPage(isRegister: true),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesPage(),
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
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/controls',
                builder: (context, state) => const ControlsPage(),
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
  final tokenStorage = ref.watch(tokenStorageProvider);
  final client = ref.watch(apiClientProvider);

  return createAppRouter(
    tokenStorage: tokenStorage,
    authEvents: client.authEvents,
    initialLocation: '/home',
  );
});
