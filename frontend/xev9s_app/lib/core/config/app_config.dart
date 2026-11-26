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
/// The mock server (Prism) and the FastAPI backend both serve routes from the
/// root (without `/api/v1`). For the local FastAPI backend:
/// ```
/// --dart-define=API_BASE_URL=http://localhost:8000
/// --dart-define=WS_BASE_URL=ws://localhost:8000
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
  /// Default points to the local mock WebSocket server on port 4011.
  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:4011',
  );

  /// Raw realtime communication mode: 'ws' (WebSocket) or 'polling'.
  /// Injected via `--dart-define=REALTIME_MODE=...`.
  static const String rawRealtimeMode = String.fromEnvironment(
    'REALTIME_MODE',
    defaultValue: 'ws',
  );

  /// Validated realtime mode (defaults to WebSocket for any unrecognized value).
  static RealtimeMode get realtimeMode {
    if (rawRealtimeMode.trim().toLowerCase() == 'polling') {
      return RealtimeMode.polling;
    }
    return RealtimeMode.ws;
  }

  /// Interval in seconds for fallback polling mode.
  /// Injected via `--dart-define=POLL_INTERVAL_SECONDS=...`.
  static const int pollIntervalSeconds = int.fromEnvironment(
    'POLL_INTERVAL_SECONDS',
    defaultValue: 10,
  );

  /// OpenStreetMap tile URL template.
  /// Injected via `--dart-define=MAP_TILE_URL=...`.
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// User-Agent package name identifier for OpenStreetMap tile requests.
  static const String mapUserAgentPackageName = 'com.xev9s.companion';
}

/// Operational modes for vehicle status and telemetry synchronization.
enum RealtimeMode {
  ws,
  polling,
}
