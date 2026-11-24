import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../features/vehicles/domain/realtime_event.dart';
import '../config/app_config.dart';
import 'realtime_service.dart';

/// Polling fallback implementation of [RealtimeService] for environments where
/// WebSockets are unavailable or disallowed.
class PollingRealtimeService with WidgetsBindingObserver implements RealtimeService {
  PollingRealtimeService({
    Duration? pollInterval,
  }) : _pollInterval =
            pollInterval ?? Duration(seconds: AppConfig.pollIntervalSeconds) {
    _registerLifecycleObserver();
  }

  final Duration _pollInterval;
  final _eventsController = StreamController<RealtimeEvent>.broadcast();
  final _connectionStateController =
      StreamController<RealtimeConnectionState>.broadcast();
  final _resyncController = StreamController<void>.broadcast();

  RealtimeConnectionState _currentState = RealtimeConnectionState.disconnected;
  Timer? _pollingTimer;
  bool _isActive = false;
  bool _isBackgrounded = false;

  @override
  Stream<RealtimeEvent> get events => _eventsController.stream;

  @override
  Stream<RealtimeConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  RealtimeConnectionState get currentConnectionState => _currentState;

  @override
  Stream<void> get onResync => _resyncController.stream;

  void _setState(RealtimeConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
    }
  }

  void _registerLifecycleObserver() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // In headless unit tests without Flutter WidgetsBinding, safely continue
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isBackgrounded = false;
      if (_isActive) {
        _startTimer();
        // Resume with an immediate resync
        _resyncController.add(null);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _isBackgrounded = true;
      _stopTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    if (!_isActive || _isBackgrounded) return;

    _pollingTimer = Timer.periodic(_pollInterval, (_) {
      if (_isActive && !_isBackgrounded) {
        _resyncController.add(null);
      }
    });
  }

  void _stopTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  Future<void> connect({String? vehicleId}) async {
    _isActive = true;
    _setState(RealtimeConnectionState.connected);
    if (!_isBackgrounded) {
      _startTimer();
    }
  }

  @override
  Future<void> disconnect() async {
    _isActive = false;
    _stopTimer();
    _setState(RealtimeConnectionState.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _eventsController.close();
    _connectionStateController.close();
    _resyncController.close();
  }
}
