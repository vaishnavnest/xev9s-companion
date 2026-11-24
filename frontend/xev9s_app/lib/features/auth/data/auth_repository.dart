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

    final tokenData = await apiClient.post<Map<String, dynamic>>(
      '/auth/login',
      body: {
        'email': trimmedIdentifier,
        'identifier': trimmedIdentifier,
        'password': password,
      },
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for AuthTokens');
        }
        return json;
      },
    );

    final accessToken = (tokenData['access_token'] ?? tokenData['accessToken']) as String?;
    final refreshToken = (tokenData['refresh_token'] ?? tokenData['refreshToken']) as String?;
    final expiresIn = ((tokenData['expires_in'] ?? tokenData['expiresIn']) as num?)?.toInt() ?? 900;
    final tokenType = (tokenData['token_type'] ?? tokenData['tokenType']) as String? ?? 'Bearer';

    if (accessToken == null || refreshToken == null) {
      throw const FormatException('Missing required tokens in login response');
    }

    await tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    UserSummary user;
    if (tokenData['user'] is Map<String, dynamic>) {
      user = UserSummary.fromJson(tokenData['user'] as Map<String, dynamic>);
    } else {
      user = await currentUser();
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      tokenType: tokenType,
      user: user,
    );
  }

  @override
  Future<AuthSession> register(String name, String email, String password) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    final resp = await apiClient.post<Map<String, dynamic>>(
      '/auth/register',
      body: {
        'full_name': trimmedName,
        'name': trimmedName,
        'email': trimmedEmail,
        'password': password,
        'confirm_password': password,
      },
      parse: (json) {
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON map for AuthTokens');
        }
        return json;
      },
    );

    final accessToken = (resp['access_token'] ?? resp['accessToken']) as String?;
    final refreshToken = (resp['refresh_token'] ?? resp['refreshToken']) as String?;

    if (accessToken != null && refreshToken != null) {
      final expiresIn = ((resp['expires_in'] ?? resp['expiresIn']) as num?)?.toInt() ?? 900;
      final tokenType = (resp['token_type'] ?? resp['tokenType']) as String? ?? 'Bearer';
      await tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      final user = resp['user'] is Map<String, dynamic>
          ? UserSummary.fromJson(resp['user'] as Map<String, dynamic>)
          : await currentUser();

      return AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
        tokenType: tokenType,
        user: user,
      );
    }

    // Backend returns UserResponse without tokens: establish session via login
    return await login(trimmedEmail, password);
  }

  @override
  Future<UserSummary> currentUser() async {
    return apiClient.get<UserSummary>(
      '/auth/me',
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
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await apiClient.post<void>(
          '/auth/logout',
          body: {
            'refresh_token': refreshToken,
            'refreshToken': refreshToken,
          },
          parse: (_) {},
        );
      }
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
