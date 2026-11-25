import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/network/api_exception.dart';
import 'package:xev9s_app/core/network/auth_interceptor.dart';
import 'package:xev9s_app/core/network/error_codes.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/data/auth_repository.dart';
import 'package:xev9s_app/features/auth/domain/auth_session.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class FakeTokenStorage implements TokenStorage {
  String? accessToken;
  String? refreshToken;
  bool cleared = false;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveAccessToken(String token) async => accessToken = token;

  @override
  Future<void> saveRefreshToken(String token) async => refreshToken = token;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
    cleared = true;
  }
}

class FakeAuthRepository implements AuthRepository {
  UserSummary? currentUserResult;
  Exception? currentUserError;
  AuthSession? loginResult;
  Exception? loginError;
  AuthSession? registerResult;
  Exception? registerError;
  bool logoutCalled = false;

  @override
  Future<UserSummary> currentUser({String? accessToken}) async {
    if (currentUserError != null) throw currentUserError!;
    return currentUserResult!;
  }

  @override
  Future<AuthSession> login(String identifier, String password) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<AuthSession> register(String name, String email, String password) async {
    if (registerError != null) throw registerError!;
    return registerResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testUser = UserSummary(
    userId: 'usr_001',
    name: 'Aarav Sharma',
    email: 'aarav@example.com',
  );

  const testSession = AuthSession(
    accessToken: 'acc_1',
    refreshToken: 'ref_1',
    expiresIn: 900,
    user: testUser,
  );

  group('AuthController', () {
    test('startup with no token transitions to unauthenticated', () async {
      final tokenStorage = FakeTokenStorage();
      final authRepo = FakeAuthRepository();

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(authControllerProvider), equals(const AuthUnknown()));

      await container.read(authControllerProvider.notifier).checkSession();

      expect(container.read(authControllerProvider), equals(const AuthUnauthenticated()));
    });

    test('startup with valid token transitions to authenticated', () async {
      final tokenStorage = FakeTokenStorage()..accessToken = 'valid_token';
      final authRepo = FakeAuthRepository()..currentUserResult = testUser;

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).checkSession();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, equals(testUser));
    });

    test('startup with expired token clears tokens and transitions to unauthenticated(sessionExpired)', () async {
      final tokenStorage = FakeTokenStorage()..accessToken = 'expired_token';
      final authRepo = FakeAuthRepository()
        ..currentUserError = const AppError(
          code: ApiErrorCode.tokenExpired,
          message: 'jwt expired',
        );

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).checkSession();

      final state = container.read(authControllerProvider);
      expect(state, equals(const AuthUnauthenticated(UnauthenticatedReason.sessionExpired)));
      expect(tokenStorage.cleared, isTrue);
    });

    test('startup with network failure transitions to startupFailed and NOT unauthenticated', () async {
      final tokenStorage = FakeTokenStorage()..accessToken = 'valid_token';
      final authRepo = FakeAuthRepository()
        ..currentUserError = AppError.noConnection();

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).checkSession();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthStartupFailed>());
      expect(tokenStorage.cleared, isFalse); // Did not log out
    });

    test('login success updates state to authenticated', () async {
      final tokenStorage = FakeTokenStorage();
      final authRepo = FakeAuthRepository()..loginResult = testSession;

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).login('aarav@example.com', 'Pass1234');

      final state = container.read(authControllerProvider);
      expect(state, equals(const AuthAuthenticated(testUser)));
    });

    test('login failure rethrows AppError', () async {
      final tokenStorage = FakeTokenStorage();
      final authRepo = FakeAuthRepository()
        ..loginError = const AppError(
          code: ApiErrorCode.invalidCredentials,
          message: 'Invalid email or password',
        );

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(authControllerProvider.notifier).login('bad@example.com', 'wrong'),
        throwsA(isA<AppError>()),
      );
    });

    test('register success updates state to authenticated', () async {
      final tokenStorage = FakeTokenStorage();
      final authRepo = FakeAuthRepository()..registerResult = testSession;

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).register('Aarav', 'a@a.com', 'Pass1234');

      final state = container.read(authControllerProvider);
      expect(state, equals(const AuthAuthenticated(testUser)));
    });

    test('logout clears selected vehicle and sets state to unauthenticated', () async {
      final tokenStorage = FakeTokenStorage()..accessToken = 'token';
      final authRepo = FakeAuthRepository();

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(selectedVehicleProvider.notifier).select('veh_123');
      expect(container.read(selectedVehicleProvider), equals('veh_123'));

      await container.read(authControllerProvider.notifier).logout();

      expect(authRepo.logoutCalled, isTrue);
      expect(container.read(selectedVehicleProvider), isNull);
      expect(container.read(authControllerProvider), equals(const AuthUnauthenticated()));
    });

    test('sessionExpired event transitions state to unauthenticated(sessionExpired)', () async {
      final tokenStorage = FakeTokenStorage()..accessToken = 'token';
      final authRepo = FakeAuthRepository()..currentUserResult = testUser;
      final authEventsController = StreamController<AuthEvent>.broadcast();

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(authRepo),
          sessionExpiredProvider.overrideWith((ref) => authEventsController.stream),
        ],
      );
      addTearDown(() {
        container.dispose();
        authEventsController.close();
      });

      // Keep providers active in unit test
      container.listen(authControllerProvider, (_, _) {});
      container.listen(sessionExpiredProvider, (_, _) {});

      await container.read(selectedVehicleProvider.notifier).select('veh_123');

      authEventsController.add(AuthEvent.unauthenticated);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(authControllerProvider);
      expect(state, equals(const AuthUnauthenticated(UnauthenticatedReason.sessionExpired)));
      expect(container.read(selectedVehicleProvider), isNull);
    });
  });
}
