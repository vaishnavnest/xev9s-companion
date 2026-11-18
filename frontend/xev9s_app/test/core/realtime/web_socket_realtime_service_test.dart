import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xev9s_app/core/realtime/realtime_service.dart';
import 'package:xev9s_app/core/realtime/web_socket_realtime_service.dart';
import 'package:xev9s_app/core/storage/token_storage.dart';
import 'package:xev9s_app/features/vehicles/domain/realtime_event.dart';

class FakeTokenStorage implements TokenStorage {
  String? accessToken = 'mock_jwt_token_123';
  String? refreshToken = 'mock_refresh_token_123';

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<void> saveAccessToken(String token) async => accessToken = token;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveRefreshToken(String token) async => refreshToken = token;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

class FakeWebSocketSink implements WebSocketSink {
  bool isClosed = false;
  int? closeCode;
  String? closeReason;

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future close([int? closeCode, String? closeReason]) async {
    isClosed = true;
    this.closeCode = closeCode;
    this.closeReason = closeReason;
  }

  @override
  Future get done => Future.value();
}

class FakeWebSocketChannel implements WebSocketChannel {
  FakeWebSocketChannel(this.uri);

  final Uri uri;
  final StreamController<dynamic> streamController = StreamController<dynamic>.broadcast();
  final FakeWebSocketSink fakeSink = FakeWebSocketSink();

  @override
  Stream<dynamic> get stream => streamController.stream;

  @override
  WebSocketSink get sink => fakeSink;

  @override
  int? get closeCode => fakeSink.closeCode;

  @override
  String? get closeReason => fakeSink.closeReason;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WebSocketRealtimeService Tests', () {
    late FakeTokenStorage tokenStorage;
    late List<FakeWebSocketChannel> createdChannels;

    setUp(() {
      tokenStorage = FakeTokenStorage();
      createdChannels = [];
    });

    WebSocketRealtimeService createService({String wsBaseUrl = 'ws://localhost:4010'}) {
      return WebSocketRealtimeService(
        tokenStorage: tokenStorage,
        wsBaseUrl: wsBaseUrl,
        channelFactory: (uri) {
          final channel = FakeWebSocketChannel(uri);
          createdChannels.add(channel);
          return channel;
        },
      );
    }

    test('backoff calculation strictly follows 1, 2, 4, 8, 16, 30, 30 seconds', () {
      expect(WebSocketRealtimeService.calculateBackoff(0).inSeconds, 1);
      expect(WebSocketRealtimeService.calculateBackoff(1).inSeconds, 2);
      expect(WebSocketRealtimeService.calculateBackoff(2).inSeconds, 4);
      expect(WebSocketRealtimeService.calculateBackoff(3).inSeconds, 8);
      expect(WebSocketRealtimeService.calculateBackoff(4).inSeconds, 16);
      expect(WebSocketRealtimeService.calculateBackoff(5).inSeconds, 30);
      expect(WebSocketRealtimeService.calculateBackoff(6).inSeconds, 30);
      expect(WebSocketRealtimeService.calculateBackoff(10).inSeconds, 30);
    });

    test('connects with token and vehicleId in query params and emits connected state', () async {
      final service = createService();
      addTearDown(service.dispose);

      final stateFuture = service.connectionState.firstWhere(
        (s) => s == RealtimeConnectionState.connected,
      );

      await service.connect(vehicleId: 'veh_9S0001');

      final state = await stateFuture;
      expect(state, RealtimeConnectionState.connected);
      expect(createdChannels.length, 1);
      expect(createdChannels.first.uri.queryParameters['token'], 'mock_jwt_token_123');
      expect(createdChannels.first.uri.queryParameters['vehicleId'], 'veh_9S0001');
    });

    test('parses incoming JSON message and delivers RealtimeEvent', () async {
      final service = createService();
      addTearDown(service.dispose);

      await service.connect(vehicleId: 'veh_9S0001');
      final channel = createdChannels.first;

      final eventFuture = service.events.first;

      channel.streamController.add(
        '{"event":"vehicle.status","vehicleId":"veh_9S0001","timestamp":"2026-11-18T05:00:00Z","data":{"vehicleId":"veh_9S0001","vehicleState":"PARKED","connectivity":"ONLINE","lastUpdatedAt":"2026-11-18T05:00:00Z"}}',
      );

      final event = await eventFuture;
      expect(event.type, RealtimeEventType.vehicleStatus);
      expect(event.vehicleId, 'veh_9S0001');
    });

    test('disconnect closes channel and cancels active subscriptions', () async {
      final service = createService();

      await service.connect(vehicleId: 'veh_9S0001');
      expect(service.currentConnectionState, RealtimeConnectionState.connected);

      await service.disconnect();

      expect(service.currentConnectionState, RealtimeConnectionState.disconnected);
      expect(createdChannels.first.fakeSink.isClosed, isTrue);

      service.dispose();
    });
  });
}
