import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'error_codes.dart';

enum AuthEvent {
  unauthenticated,
  tokenRefreshed,
}

/// Dio Interceptor handling Bearer token injection and seamless token refresh on 401.
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

    // Check if 401 error is eligible for refresh
    if (statusCode == 401 && !_isExempt(err.requestOptions.path)) {
      final data = response?.data;
      String? errorCode;
      if (data is Map<String, dynamic>) {
        final errorObj = data['error'];
        if (errorObj is Map<String, dynamic>) {
          errorCode = errorObj['code'] as String?;
        }
      }

      final parsedCode = ApiErrorCode.fromString(errorCode);

      // If token is expired, attempt refresh
      if (parsedCode == ApiErrorCode.tokenExpired) {
        final refreshToken = await tokenStorage.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          try {
            // Use clean Dio clone to avoid recursive interceptor loops
            final refreshDio = Dio(BaseOptions(
              baseUrl: dio.options.baseUrl,
              headers: {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));

            final refreshResponse = await refreshDio.post<Map<String, dynamic>>(
              refreshEndpoint,
              data: {'refreshToken': refreshToken},
            );

            final respBody = refreshResponse.data;
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

                // Retry original request with updated access token
                final requestOptions = err.requestOptions;
                requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                final cloneResponse = await dio.fetch(requestOptions);
                return handler.resolve(cloneResponse);
              }
            }
          } catch (_) {
            // Refresh failed: fallback to unauthenticated clearing
          }
        }
      }

      // If refresh failed, or code was UNAUTHENTICATED / not refreshable
      await tokenStorage.clearTokens();
      _authEventController.add(AuthEvent.unauthenticated);
    }

    return handler.next(err);
  }

  void dispose() {
    _authEventController.close();
  }
}
