import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network/api_client.dart';
import 'network/auth_interceptor.dart';
import 'storage/token_storage.dart';

/// Provider for SharedPreferences instance.
/// Overridden in main() or tests.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

/// Provider for TokenStorage. Overridable in tests.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SecureTokenStorage(prefs: prefs);
});

/// Provider for ApiClient configured with tokenStorageProvider. Overridable in tests.
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(tokenStorage: storage);
});

/// Stream provider exposing the auth events stream (e.g. unauthenticated, tokenRefreshed).
final sessionExpiredProvider = StreamProvider<AuthEvent>((ref) {
  final client = ref.watch(apiClientProvider);
  return client.authEvents ?? const Stream<AuthEvent>.empty();
});
