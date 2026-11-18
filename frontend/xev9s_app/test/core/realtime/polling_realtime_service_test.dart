import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/realtime/polling_realtime_service.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';

void main() {
  group('PollingRealtimeService Tests', () {
    test('connect sets state to connected and disconnect resets to disconnected', () async {
      final service = PollingRealtimeService(
        pollInterval: const Duration(seconds: 5),
      );
      addTearDown(service.dispose);

      expect(service.currentConnectionState, RealtimeConnectionState.disconnected);

      await service.connect(vehicleId: 'veh_01');
      expect(service.currentConnectionState, RealtimeConnectionState.connected);

      await service.disconnect();
      expect(service.currentConnectionState, RealtimeConnectionState.disconnected);
    });

    test('lifecycle observer handles backgrounding and resuming with resync', () async {
      final service = PollingRealtimeService(
        pollInterval: const Duration(seconds: 10),
      );
      addTearDown(service.dispose);

      await service.connect(vehicleId: 'veh_01');

      // Pause app
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Resume app -> triggers immediate resync signal
      final resyncFuture = service.onResync.first;
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await expectLater(resyncFuture, completes);
    });
  });
}
