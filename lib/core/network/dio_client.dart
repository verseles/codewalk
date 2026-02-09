import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'dart:convert';

/// Dio HTTP client configuration
class DioClient {
  late final Dio _dio;
  String? _basicAuthHeader; // cached Authorization header

  DioClient({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.defaultBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {ApiConstants.contentType: ApiConstants.applicationJson},
      ),
    );

    _setupInterceptors();
  }

  Dio get dio => _dio;

  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
    // Log base URL change for easier debugging during configuration updates
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('[Dio] Base URL updated: $baseUrl');
    }
  }

  /// Set Basic Authorization header using username and password
  void setBasicAuth(String username, String password) {
    final credentials = '$username:$password';
    final encoded = base64Encode(utf8.encode(credentials));
    _basicAuthHeader = 'Basic $encoded';
    _dio.options.headers[ApiConstants.authorization] = _basicAuthHeader!;
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('[Dio] Basic auth header set');
    }
  }

  /// Clear Authorization header
  void clearAuth() {
    _basicAuthHeader = null;
    _dio.options.headers.remove(ApiConstants.authorization);
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      print('[Dio] Authorization header cleared');
    }
  }

  void _setupInterceptors() {
    // Request interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Ensure Authorization header is present if configured
          if (_basicAuthHeader != null &&
              (options.headers[ApiConstants.authorization] == null)) {
            options.headers[ApiConstants.authorization] = _basicAuthHeader;
          }

          if (!kReleaseMode) {
            options.extra['request_start_ms'] = DateTime.now().millisecondsSinceEpoch;
            final uri = options.uri.toString();
            print('[Dio] --> ${options.method.toUpperCase()} $uri');
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          if (!kReleaseMode) {
            final startMs =
                response.requestOptions.extra['request_start_ms'] as int?;
            final elapsedMs = startMs == null
                ? -1
                : DateTime.now().millisecondsSinceEpoch - startMs;
            final uri = response.requestOptions.uri.toString();
            final status = response.statusCode ?? 0;
            final durationLabel = elapsedMs >= 0 ? ' (${elapsedMs}ms)' : '';
            print(
              '[Dio] <-- $status ${response.requestOptions.method.toUpperCase()} $uri$durationLabel',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (!kReleaseMode) {
            final uri = error.requestOptions.uri.toString();
            final method = error.requestOptions.method.toUpperCase();
            final status = error.response?.statusCode;
            print(
              '[Dio] xx> ${status ?? 'ERR'} $method $uri: ${error.type.name}',
            );
          }
          // Centralized error handling
          _handleError(error);
          handler.next(error);
        },
      ),
    );
  }

  void _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        // Timeout error
        break;
      case DioExceptionType.badResponse:
        // HTTP error status code
        break;
      case DioExceptionType.cancel:
        // Request cancelled
        break;
      case DioExceptionType.connectionError:
        // Connection error
        break;
      case DioExceptionType.unknown:
        // Unknown error
        break;
      case DioExceptionType.badCertificate:
        // Certificate error
        break;
    }
  }

  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
