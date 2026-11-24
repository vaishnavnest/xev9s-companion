import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Production implementation backed by [FlutterSecureStorage] on mobile (Keystore/Keychain)
/// and [SharedPreferences] / fallback on Web (Local Storage).
///
/// NOTE on Web:
/// On Web platforms, WebCrypto / SubtleCrypto in [FlutterSecureStorage] can fail with
/// DOMException [OperationError] when running on non-HTTPS origins, incognito mode,
/// or specific browser security sandboxes. On Web, [SharedPreferences] (window.localStorage)
/// is used reliably with graceful error recovery.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({
    FlutterSecureStorage? storage,
    this.prefs,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final SharedPreferences? prefs;

  static const _accessTokenKey = 'xev9s_access_token';
  static const _refreshTokenKey = 'xev9s_refresh_token';

  @override
  Future<String?> getAccessToken() async {
    if (kIsWeb && prefs != null) {
      return prefs!.getString(_accessTokenKey);
    }
    try {
      final value = await _storage.read(key: _accessTokenKey);
      if (value != null) return value;
    } catch (_) {
      // Fallback on WebCrypto OperationError or KeyStore corruption
    }
    return prefs?.getString(_accessTokenKey);
  }

  @override
  Future<void> saveAccessToken(String token) async {
    if (kIsWeb && prefs != null) {
      await prefs!.setString(_accessTokenKey, token);
      return;
    }
    try {
      await _storage.write(key: _accessTokenKey, value: token);
    } catch (_) {
      // Fallback if secure storage is unavailable
    }
    await prefs?.setString(_accessTokenKey, token);
  }

  @override
  Future<String?> getRefreshToken() async {
    if (kIsWeb && prefs != null) {
      return prefs!.getString(_refreshTokenKey);
    }
    try {
      final value = await _storage.read(key: _refreshTokenKey);
      if (value != null) return value;
    } catch (_) {
      // Fallback on WebCrypto OperationError or KeyStore corruption
    }
    return prefs?.getString(_refreshTokenKey);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    if (kIsWeb && prefs != null) {
      await prefs!.setString(_refreshTokenKey, token);
      return;
    }
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } catch (_) {
      // Fallback if secure storage is unavailable
    }
    await prefs?.setString(_refreshTokenKey, token);
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
    if (kIsWeb && prefs != null) {
      await Future.wait([
        prefs!.remove(_accessTokenKey),
        prefs!.remove(_refreshTokenKey),
      ]);
      return;
    }
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } catch (_) {
      // Ignore cleanup exceptions
    }
    await Future.wait([
      prefs?.remove(_accessTokenKey) ?? Future.value(),
      prefs?.remove(_refreshTokenKey) ?? Future.value(),
    ]);
  }
}
