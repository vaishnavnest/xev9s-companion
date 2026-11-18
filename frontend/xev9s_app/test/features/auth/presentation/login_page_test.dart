import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/presentation/login_page.dart';

class MockAuthController extends AuthController {
  MockAuthController({this.onLogin});

  final Future<void> Function(String id, String pwd)? onLogin;

  @override
  AuthState build() => const AuthUnauthenticated();

  @override
  Future<void> login(String identifier, String password) async {
    if (onLogin != null) {
      await onLogin!(identifier, password);
    }
  }
}

void main() {
  Widget buildSubject(AuthController controller) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(
        home: LoginPage(),
      ),
    );
  }

  group('LoginPage Widget Tests', () {
    testWidgets('submit is disabled until fields are valid', (tester) async {
      await tester.pumpWidget(buildSubject(MockAuthController()));

      final submitFinder = find.byKey(const Key('login-submit'));
      expect(submitFinder, findsOneWidget);
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Enter invalid email
      await tester.enterText(find.byKey(const Key('login-identifier')), 'invalidemail');
      await tester.pump();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      // Enter valid email and password
      await tester.enterText(find.byKey(const Key('login-identifier')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('login-password')), 'secret123');
      await tester.pump();

      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
    });

    testWidgets('password show/hide toggle works', (tester) async {
      await tester.pumpWidget(buildSubject(MockAuthController()));

      final passwordFinder = find.byKey(const Key('login-password'));
      expect(tester.widget<TextField>(find.descendant(of: passwordFinder, matching: find.byType(TextField))).obscureText, isTrue);

      // Tap toggle icon
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();

      expect(tester.widget<TextField>(find.descendant(of: passwordFinder, matching: find.byType(TextField))).obscureText, isFalse);
    });

    testWidgets('shows INVALID_CREDENTIALS error and clears password on failure', (tester) async {
      final controller = MockAuthController(
        onLogin: (id, pwd) async {
          throw const AppError(
            code: ApiErrorCode.invalidCredentials,
            message: 'Wrong password',
          );
        },
      );

      await tester.pumpWidget(buildSubject(controller));

      await tester.enterText(find.byKey(const Key('login-identifier')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('login-password')), 'wrongpass');
      await tester.pump();

      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      // Identifier retained, password cleared
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('wrongpass'), findsNothing);
    });

    testWidgets('shows session expired message when applicable', (tester) async {
      final container = ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _ExpiredAuthController(),
          ),
        ],
        child: const MaterialApp(
          home: LoginPage(),
        ),
      );

      await tester.pumpWidget(container);
      await tester.pumpAndSettle();

      expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
    });
  });
}

class _ExpiredAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated(UnauthenticatedReason.sessionExpired);
}
