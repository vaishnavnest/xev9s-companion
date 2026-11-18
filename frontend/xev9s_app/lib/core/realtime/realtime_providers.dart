import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/vehicles/domain/realtime_event.dart';
import '../../features/vehicles/selected_vehicle_provider.dart';
import '../config/app_config.dart';
import '../providers.dart';
import 'polling_realtime_service.dart';
import 'realtime_service.dart';
import 'web_socket_realtime_service.dart';

/// Provider for the active [RealtimeService] implementation based on configuration.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final mode = AppConfig.realtimeMode;
  final tokenStorage = ref.watch(tokenStorageProvider);
  final apiClient = ref.watch(apiClientProvider);

  final RealtimeService service;
  if (mode == RealtimeMode.polling) {
    service = PollingRealtimeService(
      pollInterval: Duration(seconds: AppConfig.pollIntervalSeconds),
    );
  } else {
    service = WebSocketRealtimeService(
      tokenStorage: tokenStorage,
      apiClient: apiClient,
    );
  }

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream of incoming push events from the connected vehicle platform.
final realtimeEventsProvider = StreamProvider<RealtimeEvent>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.events;
});

/// Stream of realtime connection states (e.g. connected, reconnecting, disconnected).
final realtimeConnectionStateProvider =
    StreamProvider<RealtimeConnectionState>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.connectionState;
});

/// Stream emitting signals whenever downstream providers must re-sync via REST.
final realtimeResyncProvider = StreamProvider<void>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  return service.onResync;
});

/// Coordinator that automatically manages the lifecycle of the realtime connection:
/// connects when authenticated and a vehicle is selected, reconnects on vehicle switch,
/// and disconnects on logout.
final realtimeCoordinatorProvider = Provider<void>((ref) {
  final authState = ref.watch(authControllerProvider);
  final selectedVehicleId = ref.watch(selectedVehicleProvider);
  final service = ref.watch(realtimeServiceProvider);

  if (authState is AuthAuthenticated &&
      selectedVehicleId != null &&
      selectedVehicleId.isNotEmpty) {
    service.connect(vehicleId: selectedVehicleId);
  } else {
    service.disconnect();
  }
});
