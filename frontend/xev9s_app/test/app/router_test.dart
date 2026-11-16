import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xev9s_app/app/router.dart';
import 'package:xev9s_app/core/network/auth_interceptor.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.token});

  String? token;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveAccessToken(String token) async {
    this.token = token;
  }

  @override
  Future<void> saveRefreshToken(String token) async {}

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    token = accessToken;
  }

  @override
  Future<void> clearTokens() async {
    token = null;
  }
}

void main() {
  group('Router Authentication Guard', () {
    testWidgets('redirects to /login when no token is present', (tester) async {
      final storage = FakeTokenStorage(token: null);
      final router = createAppRouter(
        tokenStorage: storage,
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/login'));
      expect(find.text('Sign In Page (Placeholder)'), findsOneWidget);
    });

    testWidgets('allows navigation to /home when token is present and redirects away from /login', (tester) async {
      final storage = FakeTokenStorage(token: 'valid_access_token');
      final router = createAppRouter(
        tokenStorage: storage,
        initialLocation: '/login',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/home'));
      expect(find.text('Dashboard Page (Placeholder)'), findsOneWidget);
    });

    testWidgets('redirects to /login when session expired event is emitted', (tester) async {
      final storage = FakeTokenStorage(token: 'valid_access_token');
      final authEventsController = StreamController<AuthEvent>.broadcast();

      final router = createAppRouter(
        tokenStorage: storage,
        authEvents: authEventsController.stream,
        initialLocation: '/home',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/home'));

      // Session expires: clear token and emit unauthenticated
      await storage.clearTokens();
      authEventsController.add(AuthEvent.unauthenticated);

      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, equals('/login'));
      expect(find.text('Sign In Page (Placeholder)'), findsOneWidget);

      await authEventsController.close();
    });
  });
}
