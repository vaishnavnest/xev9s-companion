import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'error_codes.dart';

enum AuthEvent {
  unauthenticated,
  tokenRefreshed,
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

  // Single in-flight refresh future to coordinate concurrent 401s
  Future<String?>? _refreshFuture;

  // Paths exempt from Bearer token attachment and automatic refresh
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

    // Guard: Exempt endpoints or non-401 errors pass through
    if (statusCode != 401 || _isExempt(err.requestOptions.path)) {
      return handler.next(err);
    }

    // Guard against infinite retry loops
    if (err.requestOptions.extra['isRetry'] == true) {
      await tokenStorage.clearTokens();
      _authEventController.add(AuthEvent.unauthenticated);
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

    // If token is expired, coordinate a single synchronized refresh
    if (parsedCode == ApiErrorCode.tokenExpired) {
      final currentToken = await tokenStorage.getAccessToken();
      final sentHeader = err.requestOptions.headers['Authorization'] as String?;
      final sentToken = sentHeader?.replaceFirst('Bearer ', '').trim();

      String? newAccessToken;
      if (currentToken != null && currentToken.isNotEmpty && currentToken != sentToken) {
        // Token was already refreshed by another concurrent request
        newAccessToken = currentToken;
      } else {
        newAccessToken = await _performSynchronizedRefresh();
      }

      if (newAccessToken != null) {
        try {
          final requestOptions = err.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          requestOptions.extra['isRetry'] = true;

          // Use a standalone Dio instance for the retry to avoid QueuedInterceptor re-entry deadlocks
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
            await tokenStorage.clearTokens();
            _authEventController.add(AuthEvent.unauthenticated);
          }
          return handler.next(retryErr);
        }
      }
    }

    // Refresh failed or error was UNAUTHENTICATED
    await tokenStorage.clearTokens();
    _authEventController.add(AuthEvent.unauthenticated);
    return handler.next(err);
  }

  Future<String?> _performSynchronizedRefresh() {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final future = _executeRefresh();
    _refreshFuture = future;
    return future.whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<String?> _executeRefresh() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final refreshDio = Dio(BaseOptions(
        baseUrl: dio.options.baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      refreshDio.httpClientAdapter = dio.httpClientAdapter;

      final response = await refreshDio.post<Map<String, dynamic>>(
        refreshEndpoint,
        data: {'refreshToken': refreshToken},
      );

      final respBody = response.data;
      if (respBody != null && respBody['success'] == true) {
        final authTokens = respBody['data'] as Map<String, dynamic>?;
        final newAccessToken = authTokens?['accessToken'] as String?;
        final newRefreshToken = authTokens?['refreshToken'] as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          _authEventController.add(AuthEvent.tokenRefreshed);
          return newAccessToken;
        }
      }
    } catch (_) {
      // Refresh network or validation error
    }

    return null;
  }

  void dispose() {
    _authEventController.close();
  }
}
