import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'error_codes.dart';

enum AuthEvent {
  unauthenticated,
  tokenRefreshed,
}

/// Sealed result for _executeRefresh so callers can distinguish success from
/// failure and act appropriately without relying on a bare null return.
sealed class _RefreshResult {}

class _RefreshSuccess extends _RefreshResult {
  _RefreshSuccess(this.accessToken);
  final String accessToken;
}

/// Refresh call failed — either a network error (timeout, no connection) or
/// a server-side rejection (401 from /auth/refresh).
class _RefreshFailure extends _RefreshResult {
  _RefreshFailure({required this.isNetworkError});
  final bool isNetworkError;
}

/// Dio Interceptor handling Bearer token injection, synchronized token refresh,
/// and infinite-loop prevention.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.dio,
    this.refreshEndpoint = '/auth/refresh',
  });

  final TokenStorage tokenStorage;
  final Dio dio;
  final String refreshEndpoint;

  final _authEventController = StreamController<AuthEvent>.broadcast();
  Stream<AuthEvent> get authEvents => _authEventController.stream;

  // Single in-flight refresh future to coordinate concurrent 401s.
  Future<_RefreshResult>? _refreshFuture;

  // Paths exempt from Bearer token attachment and automatic refresh.
  static const _exemptPaths = [
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
  ];

  bool _isExempt(String path) {
    return _exemptPaths.any((exempt) => path.contains(exempt));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isExempt(options.path)) {
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final statusCode = response?.statusCode;

    // Guard: Exempt endpoints or non-401 errors pass through.
    if (statusCode != 401 || _isExempt(err.requestOptions.path)) {
      return handler.next(err);
    }

    // Guard against infinite retry loops.
    if (err.requestOptions.extra['isRetry'] == true) {
      await _clearTokensAndNotify();
      return handler.next(err);
    }

    final data = response?.data;
    String? errorCode;
    if (data is Map<String, dynamic>) {
      final errorObj = data['error'];
      if (errorObj is Map<String, dynamic>) {
        errorCode = errorObj['code'] as String?;
      }
    }

    final parsedCode = ApiErrorCode.fromString(errorCode);

    // If token is expired or request returned 401, coordinate a single synchronized refresh.
    final isExplicitUnauth = parsedCode == ApiErrorCode.unauthenticated &&
        !(data is Map<String, dynamic> && (data['detail'] as String? ?? '').toLowerCase().contains('token'));
    final shouldAttemptRefresh = (parsedCode == ApiErrorCode.tokenExpired || statusCode == 401) && !isExplicitUnauth;
    if (shouldAttemptRefresh) {
      final currentToken = await tokenStorage.getAccessToken();
      final sentHeader = err.requestOptions.headers['Authorization'] as String?;
      final sentToken = sentHeader?.replaceFirst('Bearer ', '').trim();

      String? newAccessToken;
      if (currentToken != null &&
          currentToken.isNotEmpty &&
          currentToken != sentToken) {
        // Token was already refreshed by another concurrent request.
        newAccessToken = currentToken;
      } else {
        final result = await _performSynchronizedRefresh();
        if (result is _RefreshSuccess) {
          newAccessToken = result.accessToken;
        }
        // On failure, fall through to clear + notify below.
      }

      if (newAccessToken != null) {
        try {
          final requestOptions = err.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          requestOptions.extra['isRetry'] = true;

          // Use a standalone Dio instance for the retry to avoid
          // QueuedInterceptor re-entry deadlocks. No interceptors are added —
          // the refresh Dio also has no interceptors, so neither path re-enters
          // this interceptor queue.
          final retryDio = Dio(BaseOptions(
            baseUrl: dio.options.baseUrl,
            connectTimeout: dio.options.connectTimeout,
            receiveTimeout: dio.options.receiveTimeout,
          ));
          retryDio.httpClientAdapter = dio.httpClientAdapter;

          final retriedResponse = await retryDio.fetch(requestOptions);
          return handler.resolve(retriedResponse);
        } on DioException catch (retryErr) {
          if (retryErr.response?.statusCode == 401) {
            await _clearTokensAndNotify();
          }
          return handler.next(retryErr);
        }
      }
    }

    // Refresh failed or error was UNAUTHENTICATED — clear everything.
    await _clearTokensAndNotify();
    return handler.next(err);
  }

  Future<void> _clearTokensAndNotify() async {
    await tokenStorage.clearTokens();
    _authEventController.add(AuthEvent.unauthenticated);
  }

  Future<_RefreshResult> _performSynchronizedRefresh() {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final future = _executeRefresh();
    _refreshFuture = future;
    return future.whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<_RefreshResult> _executeRefresh() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return _RefreshFailure(isNetworkError: false);
    }

    // The refreshDio is intentionally created WITHOUT any interceptors —
    // especially not this AuthInterceptor — so the refresh call can never
    // re-enter the queue and loop.
    final refreshDio = Dio(BaseOptions(
      baseUrl: dio.options.baseUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    refreshDio.httpClientAdapter = dio.httpClientAdapter;

    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        refreshEndpoint,
        data: {
          'refresh_token': refreshToken,
          'refreshToken': refreshToken,
        },
      );

      final respBody = response.data;
      if (respBody != null) {
        final map = (respBody['success'] == true && respBody['data'] is Map<String, dynamic>)
            ? respBody['data'] as Map<String, dynamic>
            : respBody;
        final newAccessToken = (map['access_token'] ?? map['accessToken']) as String?;
        final newRefreshToken = (map['refresh_token'] ?? map['refreshToken']) as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          _authEventController.add(AuthEvent.tokenRefreshed);
          return _RefreshSuccess(newAccessToken);
        }
      }

      // Server replied but indicated failure (e.g. success=false / missing tokens).
      return _RefreshFailure(isNetworkError: false);
    } on DioException catch (e) {
      // Network-level failures (timeout, no connection, 401 from /auth/refresh).
      final isNetworkErr = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError;
      return _RefreshFailure(isNetworkError: isNetworkErr);
    } catch (_) {
      return _RefreshFailure(isNetworkError: false);
    }
  }

  void dispose() {
    _authEventController.close();
  }
}
