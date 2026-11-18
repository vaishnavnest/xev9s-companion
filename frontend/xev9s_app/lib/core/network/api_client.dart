import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'auth_interceptor.dart';
import 'error_codes.dart';

/// Central HTTP Client for communicating with the XEV 9S Companion Platform API.
class ApiClient {
  ApiClient({
    String? baseUrl,
    Dio? dio,
    TokenStorage? tokenStorage,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    if (tokenStorage != null) {
      _authInterceptor = AuthInterceptor(
        tokenStorage: tokenStorage,
        dio: _dio,
      );
      _dio.interceptors.add(_authInterceptor!);
    }
  }

  final Dio _dio;
  AuthInterceptor? _authInterceptor;

  Dio get dio => _dio;
  Stream<AuthEvent>? get authEvents => _authInterceptor?.authEvents;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) parse,
  }) async {
    return _send<T>(
      () => _dio.get(path, queryParameters: query),
      (json, _) => parse(json),
    );
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    required T Function(Object? json) parse,
  }) async {
    return _send<T>(
      () => _dio.post(path, data: body, options: Options(headers: headers)),
      (json, _) => parse(json),
    );
  }

  Future<T> put<T>(
    String path, {
    Object? body,
    required T Function(Object? json) parse,
  }) async {
    return _send<T>(
      () => _dio.put(path, data: body),
      (json, _) => parse(json),
    );
  }

  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) parse,
  }) async {
    return _send<T>(
      () => _dio.patch(path, data: body),
      (json, _) => parse(json),
    );
  }

  Future<T> delete<T>(
    String path, {
    Object? body,
    required T Function(Object? json) parse,
  }) async {
    return _send<T>(
      () => _dio.delete(path, data: body),
      (json, _) => parse(json),
    );
  }

  Future<PagedResult<T>> getPaged<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) parseItem,
  }) async {
    return _send<PagedResult<T>>(
      () => _dio.get(path, queryParameters: query),
      (json, meta) {
        if (json is! List) {
          throw AppError.malformedResponse(
            'Expected list data for paginated response, got ${json.runtimeType}',
          );
        }
        final items = json.map(parseItem).toList();
        return PagedResult<T>(
          items: items,
          pagination: meta?.pagination,
        );
      },
    );
  }

  Future<R> _send<R>(
    Future<Response<dynamic>> Function() request,
    R Function(Object? json, ApiMeta? meta) parse,
  ) async {
    Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.unknown(e.toString());
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw AppError.malformedResponse(
        'Expected JSON map envelope, got ${data.runtimeType}',
      );
    }

    final success = data['success'] as bool? ?? false;
    if (!success) {
      final errorJson = data['error'] as Map<String, dynamic>?;
      if (errorJson != null) {
        throw AppError.fromApiResponseError(
          errorJson,
          httpStatus: response.statusCode,
        );
      }
      throw AppError.malformedResponse(
        'Response indicated failure but provided no error payload',
      );
    }

    try {
      final payload = data['data'];
      final rawMeta = data['meta'] as Map<String, dynamic>?;
      final meta = rawMeta != null ? ApiMeta.fromJson(rawMeta) : null;

      return parse(payload, meta);
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError.malformedResponse('Failed to parse response payload: $e');
    }
  }

  AppError _handleDioError(DioException error) {
    if (error.response?.data is Map<String, dynamic>) {
      final map = error.response!.data as Map<String, dynamic>;
      final errPayload = map['error'] as Map<String, dynamic>?;
      if (errPayload != null) {
        return AppError.fromApiResponseError(
          errPayload,
          httpStatus: error.response?.statusCode,
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppError.timeout();
      case DioExceptionType.connectionError:
        return AppError.noConnection();
      case DioExceptionType.badResponse:
        return AppError(
          code: ApiErrorCode.unknown,
          message: 'Server returned HTTP ${error.response?.statusCode}',
          httpStatus: error.response?.statusCode,
          retryable: (error.response?.statusCode ?? 500) >= 500,
        );
      case DioExceptionType.cancel:
        return const AppError(
          code: ApiErrorCode.unknown,
          message: 'Request was cancelled',
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      default:
        return AppError.unknown(error.message ?? 'Network error occurred');
    }
  }
}
