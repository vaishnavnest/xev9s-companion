import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/error_codes.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../../vehicles/application/vehicles_controller.dart';
import '../../vehicles/selected_vehicle_provider.dart';
import '../data/auth_repository.dart';
import '../domain/user_summary.dart';

/// Reason why the user is unauthenticated.
enum UnauthenticatedReason {
  none,
  sessionExpired,
}

/// Sealed state representation for user authentication lifecycle.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state while the app checks for existing session tokens and profile.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// User is actively authenticated with a valid profile.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserSummary user;

  @override
  List<Object?> get props => [user];
}

/// User is not signed in.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated([this.reason = UnauthenticatedReason.none]);
  final UnauthenticatedReason reason;

  @override
  List<Object?> get props => [reason];
}

/// Startup check failed due to network / transient server error.
/// User is NOT logged out. UI shows retry.
class AuthStartupFailed extends AuthState {
  const AuthStartupFailed(this.error);
  final AppError error;

  @override
  List<Object?> get props => [error];
}

/// Controller managing global authentication state and user session.
class AuthController extends Notifier<AuthState> {
  late final AuthRepository _authRepository;
  late final TokenStorage _tokenStorage;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    _tokenStorage = ref.watch(tokenStorageProvider);

    // Listen to session expiry events emitted by AuthInterceptor
    ref.listen(sessionExpiredProvider, (previous, next) {
      next.whenData((event) {
        if (event == AuthEvent.unauthenticated) {
          handleSessionExpired();
        }
      });
    });

    // Asynchronously perform startup check
    Future.microtask(() => checkSession());

    return const AuthUnknown();
  }

  /// Verifies stored session by calling GET /users/me.
  Future<void> checkSession() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      final user = await _authRepository.currentUser();
      state = AuthAuthenticated(user);
    } on AppError catch (e) {
      if (e.code == ApiErrorCode.tokenExpired ||
          e.code == ApiErrorCode.unauthenticated) {
        await _tokenStorage.clearTokens();
        await ref.read(selectedVehicleProvider.notifier).clear();
        state = const AuthUnauthenticated(UnauthenticatedReason.sessionExpired);
      } else {
        // Network error, timeout, or 5xx: DO NOT log out.
        state = AuthStartupFailed(e);
      }
    } catch (e) {
      state = AuthStartupFailed(AppError.unknown(e.toString()));
    }
  }

  /// Logs in with email/identifier and password.
  Future<void> login(String identifier, String password) async {
    try {
      final session = await _authRepository.login(identifier, password);
      state = AuthAuthenticated(session.user);
    } on AppError {
      rethrow;
    }
  }

  /// Registers a new user account.
  Future<void> register(String name, String email, String password) async {
    try {
      final session = await _authRepository.register(name, email, password);
      state = AuthAuthenticated(session.user);
    } on AppError {
      rethrow;
    }
  }

  /// Logs out user, clears tokens, clears vehicle selection, and invalidates vehicle data.
  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } finally {
      await ref.read(selectedVehicleProvider.notifier).clear();
      ref.invalidate(vehiclesControllerProvider);
      state = const AuthUnauthenticated(UnauthenticatedReason.none);
    }
  }

  /// Handles forced session expiry (e.g. from 401 refresh failure).
  Future<void> handleSessionExpired() async {
    await _tokenStorage.clearTokens();
    await ref.read(selectedVehicleProvider.notifier).clear();
    ref.invalidate(vehiclesControllerProvider);
    state = const AuthUnauthenticated(UnauthenticatedReason.sessionExpired);
  }

  /// Clears one-time session-expired reason once presented to user.
  void consumeSessionExpiredReason() {
    if (state is AuthUnauthenticated &&
        (state as AuthUnauthenticated).reason ==
            UnauthenticatedReason.sessionExpired) {
      state = const AuthUnauthenticated(UnauthenticatedReason.none);
    }
  }
}

/// Provider for [AuthController].
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
