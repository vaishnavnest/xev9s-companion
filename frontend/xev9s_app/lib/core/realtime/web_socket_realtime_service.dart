import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../features/vehicles/domain/realtime_event.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../storage/token_storage.dart';
import 'realtime_service.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

/// Production implementation of [RealtimeService] over WebSocket protocol.
class WebSocketRealtimeService implements RealtimeService {
  WebSocketRealtimeService({
    required this.tokenStorage,
    this.apiClient,
    String? wsBaseUrl,
    WebSocketChannelFactory? channelFactory,
    Random? random,
  })  : _wsBaseUrl = wsBaseUrl ?? AppConfig.wsBaseUrl,
        _channelFactory = channelFactory ?? WebSocketChannel.connect,
        _random = random ?? Random();

  final TokenStorage tokenStorage;
  final ApiClient? apiClient;
  final String _wsBaseUrl;
  final WebSocketChannelFactory _channelFactory;
  final Random _random;

  final _eventsController = StreamController<RealtimeEvent>.broadcast();
  final _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();
  final _resyncController = StreamController<void>.broadcast();

  RealtimeConnectionState _currentState = RealtimeConnectionState.disconnected;
  String? _currentVehicleId;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isExplicitlyDisconnected = true;
  bool _isReconnecting = false;

  @override
  Stream<RealtimeEvent> get events => _eventsController.stream;

  @override
  Stream<RealtimeConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  RealtimeConnectionState get currentConnectionState => _currentState;

  @override
  Stream<void> get onResync => _resyncController.stream;

  /// Pure backoff calculation producing: 1, 2, 4, 8, 16, 30, 30... seconds.
  /// Jitter adds up to 250 milliseconds when enabled.
  static Duration calculateBackoff(
    int attempt, {
    bool withJitter = false,
    Random? random,
  }) {
    const sequence = [1, 2, 4, 8, 16, 30];
    final baseSeconds = attempt < sequence.length ? sequence[attempt] : 30;
    var duration = Duration(seconds: baseSeconds);
    if (withJitter) {
      final r = random ?? Random();
      final jitterMs = r.nextInt(250);
      duration += Duration(milliseconds: jitterMs);
    }
    return duration;
  }

  void _setState(RealtimeConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(newState);
      }
    }
  }

  @override
  Future<void> connect({String? vehicleId}) async {
    _isExplicitlyDisconnected = false;
    _currentVehicleId = vehicleId;
    _reconnectTimer?.cancel();

    // If channel is already active, close cleanly before reconnecting for new vehicle.
    await _closeChannel();

    _setState(
      _reconnectAttempts > 0
          ? RealtimeConnectionState.reconnecting
          : RealtimeConnectionState.connecting,
    );

    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      _setState(RealtimeConnectionState.disconnected);
      return;
    }

    try {
      // Note: Passing the access token as a query parameter (?token=...) is a known tradeoff
      // for standard browser WebSocket connections, as the browser WebSocket API does not allow
      // custom HTTP headers. Backends should avoid logging query parameters in access logs.
      final base = _wsBaseUrl.endsWith('/')
          ? _wsBaseUrl.substring(0, _wsBaseUrl.length - 1)
          : _wsBaseUrl;
      final uri = Uri.parse('$base/ws').replace(
        queryParameters: {
          'token': token,
          if (_currentVehicleId != null && _currentVehicleId!.isNotEmpty)
            'vehicleId': _currentVehicleId!,
        },
      );

      final channel = _channelFactory(uri);
      _channel = channel;

      _channelSubscription = channel.stream.listen(
        _onMessageReceived,
        onError: _onChannelError,
        onDone: _onChannelDone,
        cancelOnError: true,
      );

      // Await socket handshake completion so connection errors (refusal, DNS, bad host)
      // are handled cleanly in the try/catch block rather than surfacing as unhandled exceptions
      await channel.ready;

      // Successfully connected
      final wasReconnecting = _isReconnecting || _reconnectAttempts > 0;
      _reconnectAttempts = 0;
      _isReconnecting = false;
      _setState(RealtimeConnectionState.connected);

      // On every successful RE-connect emit synthetic resync signal
      if (wasReconnecting && !_resyncController.isClosed) {
        _resyncController.add(null);
      }
    } catch (_) {
      _handleDisconnectAndScheduleRetry();
    }
  }

  void _onMessageReceived(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final event = RealtimeEvent.fromJson(decoded);
        if (!_eventsController.isClosed) {
          _eventsController.add(event);
        }
      }
    } catch (_) {
      // Tolerant parsing: ignore malformed or unparseable messages without crashing
    }
  }

  void _onChannelError(dynamic error) {
    _handleDisconnectAndScheduleRetry();
  }

  void _onChannelDone() {
    final closeCode = _channel?.closeCode;
    final closeReason = _channel?.closeReason;

    // Check if close indicates token expiration/unauthorized
    final isAuthFailure = closeCode == 4001 ||
        closeCode == 401 ||
        (closeReason != null && closeReason.toLowerCase().contains('token'));

    if (isAuthFailure) {
      _handleTokenExpiryAndRetry();
    } else {
      _handleDisconnectAndScheduleRetry();
    }
  }

  Future<void> _handleTokenExpiryAndRetry() async {
    if (_isExplicitlyDisconnected) return;

    // Attempt token refresh via REST call
    if (apiClient != null) {
      try {
        await apiClient!.get<void>(
          '/users/me',
          parse: (_) {},
        );
      } catch (_) {
        // If refresh fails, session-expired flow handles logout
      }
    }
    _handleDisconnectAndScheduleRetry();
  }

  void _handleDisconnectAndScheduleRetry() {
    if (_isExplicitlyDisconnected) {
      _setState(RealtimeConnectionState.disconnected);
      return;
    }

    _isReconnecting = true;
    _setState(RealtimeConnectionState.reconnecting);

    final delay = calculateBackoff(
      _reconnectAttempts,
      withJitter: true,
      random: _random,
    );
    _reconnectAttempts++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isExplicitlyDisconnected) {
        connect(vehicleId: _currentVehicleId);
      }
    });
  }

  Future<void> _closeChannel() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  @override
  Future<void> disconnect() async {
    _isExplicitlyDisconnected = true;
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeChannel();
    _setState(RealtimeConnectionState.disconnected);
  }

  @override
  void dispose() {
    _isExplicitlyDisconnected = true;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSubscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (!_eventsController.isClosed) {
      _eventsController.close();
    }
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
    if (!_resyncController.isClosed) {
      _resyncController.close();
    }
  }
}
