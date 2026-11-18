/// Application configuration sourced from compile-time `--dart-define` flags.
///
/// ## Run commands
///
/// ### Chrome (web):
/// ```
/// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4010
/// ```
///
/// ### Android emulator:
/// ```
/// flutter run -d <emulator-id> --dart-define=API_BASE_URL=http://10.0.2.2:4010
/// ```
///
/// ### Real Android device (use your PC's LAN IP):
/// ```
/// flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.x.x:4010
/// ```
///
/// The mock server (Prism) serves all paths from the root, so the base URL
/// does NOT include `/api/v1`. When pointing at the real backend, include
/// the full path prefix:
/// ```
/// --dart-define=API_BASE_URL=http://localhost:8080/api/v1
/// ```
class AppConfig {
  AppConfig._();

  /// Base URL for REST API calls.
  /// Injected at compile time via `--dart-define=API_BASE_URL=...`.
  /// Default points to the local Prism mock server.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4010',
  );

  /// Base URL for WebSocket connections.
  /// Injected at compile time via `--dart-define=WS_BASE_URL=...`.
  /// Default points to the local mock server (note: Prism does not support
  /// WebSocket, so this is a placeholder for future use).
  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:4010',
  );
}
