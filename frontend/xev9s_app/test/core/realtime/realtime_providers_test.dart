import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xev9s_app/core/providers.dart';
import 'package:xev9s_app/core/realtime/realtime_providers.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';
import 'package:xev9s_app/core/realtime/web_socket_realtime_service.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/auth/application/auth_controller.dart';
import 'package:xev9s_app/features/auth/domain/user_summary.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';
import 'package:xev9s_app/features/vehicles/selected_vehicle_provider.dart';

class FakeTokenStorage implements TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'test_token';
  @override
  Future<String?> getRefreshToken() async => 'test_refresh_token';
  @override
  Future<void> saveAccessToken(String token) async {}
  @override
  Future<void> saveRefreshToken(String token) async {}
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> clearTokens() async {}
}

class FakeAuthController extends AuthController {
  FakeAuthController(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;

  void setState(AuthState next) => state = next;
}

class MockRealtimeService implements RealtimeService {
  String? connectedVehicleId;
  int connectCount = 0;
  int disconnectCount = 0;

  final _eventsController = StreamController<RealtimeEvent>.broadcast();
  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  final _resyncController = StreamController<void>.broadcast();

  @override
  Stream<RealtimeEvent> get events => _eventsController.stream;

  @override
  Stream<RealtimeConnectionState> get connectionState => _stateController.stream;

  @override
  RealtimeConnectionState get currentConnectionState => RealtimeConnectionState.connected;

  @override
  Stream<void> get onResync => _resyncController.stream;

  @override
  Future<void> connect({String? vehicleId}) async {
    connectCount++;
    connectedVehicleId = vehicleId;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    connectedVehicleId = null;
  }

  @override
  void dispose() {
    _eventsController.close();
    _stateController.close();
    _resyncController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Realtime Providers & Coordinator Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('realtimeServiceProvider defaults to WebSocket mode', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(realtimeServiceProvider);
      expect(service, isA<WebSocketRealtimeService>());
    });

    test('realtimeCoordinator connects when authenticated and vehicle selected, reconnects on switch, disconnects on logout', () async {
      final mockService = MockRealtimeService();
      final fakeAuth = FakeAuthController(const AuthUnauthenticated());

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          realtimeServiceProvider.overrideWithValue(mockService),
          authControllerProvider.overrideWith(() => fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      // Start observing coordinator
      container.read(realtimeCoordinatorProvider);

      expect(mockService.connectCount, 0);
      expect(mockService.disconnectCount, 1); // Initially unauthenticated -> disconnect

      // Select vehicle
      await container.read(selectedVehicleProvider.notifier).select('veh_001');

      // Authenticate
      const user = UserSummary(userId: 'usr_1', name: 'Asha', email: 'asha@example.com');
      fakeAuth.setState(const AuthAuthenticated(user));

      // Force coordinator re-read
      container.read(realtimeCoordinatorProvider);

      expect(mockService.connectedVehicleId, 'veh_001');
      expect(mockService.connectCount, 1);

      // Switch vehicle
      await container.read(selectedVehicleProvider.notifier).select('veh_002');
      container.read(realtimeCoordinatorProvider);

      expect(mockService.connectedVehicleId, 'veh_002');
      expect(mockService.connectCount, 2);

      // Logout
      fakeAuth.setState(const AuthUnauthenticated());
      container.read(realtimeCoordinatorProvider);

      expect(mockService.connectedVehicleId, isNull);
      expect(mockService.disconnectCount, 2);
    });
  });
}
