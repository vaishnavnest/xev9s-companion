import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/profile/presentation/profile_page.dart';

class MockProfileAuthController extends Notifier<AuthState>
    implements AuthController {
  MockProfileAuthController(this.initialState);
  final AuthState initialState;
  bool logoutCalled = false;

  @override
  AuthState build() => initialState;

  @override
  Future<void> checkSession() async {}

  @override
  Future<void> login(String identifier, String password) async {}

  @override
  Future<void> register(String name, String email, String password) async {}

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> handleSessionExpired() async {}

  @override
  void consumeSessionExpiredReason() {}
}

void main() {
  const testUser = UserSummary(
    userId: 'usr_001',
    name: 'Aarav Sharma',
    email: 'aarav@example.com',
  );

  group('ProfilePage Widget Tests', () {
    testWidgets('displays user profile details and initiates logout with confirmation', (tester) async {
      final authController = MockProfileAuthController(const AuthAuthenticated(testUser));

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('Login Screen'))),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => authController),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('aarav@example.com'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);

      // Tap logout -> shows confirm dialog
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(find.text('You will need to sign in again.'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(authController.logoutCalled, isFalse);

      // Tap logout again and confirm
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(authController.logoutCalled, isTrue);
      expect(find.text('Login Screen'), findsOneWidget);
    });
  });
}
