import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/presentation/register_page.dart';

class MockRegisterAuthController extends AuthController {
  MockRegisterAuthController({this.onRegister});

  final Future<void> Function(String name, String email, String pwd)? onRegister;

  @override
  AuthState build() => const AuthUnauthenticated();

  @override
  Future<void> register(String name, String email, String password) async {
    if (onRegister != null) {
      await onRegister!(name, email, password);
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
        home: RegisterPage(),
      ),
    );
  }

  group('RegisterPage Widget Tests', () {
    testWidgets('displays password rule and shows mismatch error', (tester) async {
      await tester.pumpWidget(buildSubject(MockRegisterAuthController()));

      expect(find.text('Must be at least 8 characters'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('register-name')), 'Aarav');
      await tester.enterText(find.byKey(const Key('register-email')), 'aarav@example.com');
      await tester.enterText(find.byKey(const Key('register-password')), 'Pass1234');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'Pass9999');
      await tester.pump();

      // Submit should be disabled due to mismatch
      expect(tester.widget<FilledButton>(find.byKey(const Key('register-submit'))).onPressed, isNull);

      // Enter matching password
      await tester.enterText(find.byKey(const Key('register-confirm')), 'Pass1234');
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byKey(const Key('register-submit'))).onPressed, isNotNull);
    });

    testWidgets('shows DUPLICATE_EMAIL error under email field', (tester) async {
      final controller = MockRegisterAuthController(
        onRegister: (n, e, p) async {
          throw const AppError(
            code: ApiErrorCode.duplicateEmail,
            message: 'Email in use',
          );
        },
      );

      await tester.pumpWidget(buildSubject(controller));

      await tester.enterText(find.byKey(const Key('register-name')), 'Aarav');
      await tester.enterText(find.byKey(const Key('register-email')), 'existing@example.com');
      await tester.enterText(find.byKey(const Key('register-password')), 'Pass1234');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'Pass1234');
      await tester.pump();

      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();

      expect(find.text('An account with this email already exists.'), findsOneWidget);
    });
  });
}
