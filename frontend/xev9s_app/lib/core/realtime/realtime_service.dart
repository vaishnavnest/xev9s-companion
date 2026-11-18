import 'dart:async';
import '../../features/vehicles/domain/realtime_event.dart';

/// Connection states for realtime telemetry streaming.
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Abstract contract for real-time bi-directional or polled vehicle telemetry.
abstract class RealtimeService {
  /// Stream of inbound domain push events.
  Stream<RealtimeEvent> get events;

  /// Stream of network connection state transitions.
  Stream<RealtimeConnectionState> get connectionState;

  /// Current network connection state.
  RealtimeConnectionState get currentConnectionState;

  /// Signal stream emitted upon successful reconnection or poll interval,
  /// instructing downstream providers to perform a full REST synchronization.
  Stream<void> get onResync;

  /// Initiates connection or polling for [vehicleId].
  Future<void> connect({String? vehicleId});

  /// Disconnects and terminates any pending auto-reconnect timers.
  Future<void> disconnect();

  /// Releases resources, timers, and stream controllers.
  void dispose();
}
