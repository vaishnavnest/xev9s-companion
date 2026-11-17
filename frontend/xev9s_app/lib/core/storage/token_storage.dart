import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract interface for storing authentication tokens securely.
/// Allows unit and widget tests to inject in-memory fakes.
abstract class TokenStorage {
  Future<String?> getAccessToken();
  Future<void> saveAccessToken(String token);

  Future<String?> getRefreshToken();
  Future<void> saveRefreshToken(String token);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clearTokens();
}

/// Production implementation backed by [FlutterSecureStorage].
///
/// NOTE on Web:
/// On Web platforms, [FlutterSecureStorage] defaults to browser LocalStorage / IndexedDB,
/// which lacks hardware-backed cryptographic enclave protection available on mobile
/// (e.g. Android Keystore / iOS Keychain). Ensure HTTPS is strictly enforced in production.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'xev9s_access_token';
  static const _refreshTokenKey = 'xev9s_refresh_token';

  @override
  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
    ]);
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
