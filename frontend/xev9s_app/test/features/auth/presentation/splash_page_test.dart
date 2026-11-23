import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/presentation/splash_page.dart';

class FakeAuthController extends AuthController {
  FakeAuthController({required this.initialState});

  final AuthState initialState;
  int retryCount = 0;

  @override
  AuthState build() => initialState;

  @override
  Future<void> checkSession() async {
    retryCount++;
  }
}

void main() {
  group('SplashPage Tests', () {
    testWidgets('renders brand logo with breathing animation and no redundant text labels', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(initialState: const AuthUnknown()),
            ),
          ],
          child: const MaterialApp(
            home: SplashPage(),
          ),
        ),
      );

      // Verify redundant text labels are NOT present (logo badge contains branding)
      expect(find.text('XEV 9S'), findsNothing);
      expect(find.text('Explore the Impossible'), findsNothing);
      expect(find.text('Pure Electric Luxury Architecture'), findsNothing);
      expect(find.text('CONNECTED MOBILITY'), findsNothing);

      // Verify the image widget is present
      expect(find.byType(Image), findsOneWidget);

      // Verify initial frame
      await tester.pump(const Duration(milliseconds: 100));

      // Advance breathing animation smoothly across cycles
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(Image), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders ErrorView when AuthStartupFailed occurs', (tester) async {
      final fakeController = FakeAuthController(
        initialState: AuthStartupFailed(AppError.noConnection()),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => fakeController),
          ],
          child: const MaterialApp(
            home: SplashPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Couldn't load your account"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(fakeController.retryCount, 1);
    });

    testWidgets('XevEmblemVector custom painter renders cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: XevEmblemVector(size: 80),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(XevEmblemVector), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
