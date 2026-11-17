import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_session.dart';
import '../domain/user_summary.dart';

/// Abstract contract for authentication and session management.
abstract class AuthRepository {
  /// Authenticates using identifier (email) and password.
  /// Saves access and refresh tokens locally on success.
  Future<AuthSession> login(String identifier, String password);

  /// Registers a new user account.
  /// Saves access and refresh tokens locally on success.
  Future<AuthSession> register(String name, String email, String password);

  /// Fetches current user profile from GET /users/me.
  Future<UserSummary> currentUser();

  /// Best-effort logout with POST /auth/logout.
  /// Always clears local tokens regardless of network outcome.
  Future<void> logout();
}

/// Production implementation of [AuthRepository] backed by [ApiClient] and [TokenStorage].
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required this.apiClient,
    required this.tokenStorage,
  });

  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  @override
  Future<AuthSession> login(String identifier, String password) async {
    // Identifier is trimmed; password must not be trimmed
    final trimmedIdentifier = identifier.trim();

    final session = await apiClient.post<AuthSession>(
      '/auth/login',
      body: {
        'identifier': trimmedIdentifier,
        'password': password,
      },
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for AuthTokens');
        }
        return AuthSession.fromJson(json);
      },
    );

    await tokenStorage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );

    return session;
  }

  @override
  Future<AuthSession> register(String name, String email, String password) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    final session = await apiClient.post<AuthSession>(
      '/auth/register',
      body: {
        'name': trimmedName,
        'email': trimmedEmail,
        'password': password,
      },
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for AuthTokens');
        }
        return AuthSession.fromJson(json);
      },
    );

    await tokenStorage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );

    return session;
  }

  @override
  Future<UserSummary> currentUser() async {
    return apiClient.get<UserSummary>(
      '/users/me',
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for UserProfile');
        }
        return UserSummary.fromJson(json);
      },
    );
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      await apiClient.post<void>(
        '/auth/logout',
        body: refreshToken != null ? {'refreshToken': refreshToken} : null,
        parse: (_) {},
      );
    } catch (_) {
      // Best-effort remote logout; ignore network/HTTP errors
    } finally {
      // Local tokens are ALWAYS cleared
      await tokenStorage.clearTokens();
    }
  }
}

/// Provider for [AuthRepository]. Overridable in tests.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(tokenStorageProvider);
  return ApiAuthRepository(apiClient: client, tokenStorage: storage);
});
