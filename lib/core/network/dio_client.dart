import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../logging/app_logger.dart';

import 'dio_sse_adapter.dart';

/// Dio HTTP client configuration
class DioClient {
  DioClient({String? baseUrl}) {
    final base = baseUrl ?? ApiConstants.defaultBaseUrl;

    _dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {ApiConstants.contentType: ApiConstants.applicationJson},
      ),
    );

    // Dedicated Dio for SSE streams with isolated connection pool.
    // Prevents Android HTTP client from closing SSE connections when
    // regular HTTP requests compete for connections in the shared pool.
    _sseDio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(hours: 2),
        sendTimeout: const Duration(seconds: 10),
        headers: {ApiConstants.contentType: ApiConstants.applicationJson},
      ),
    );
    configureSseAdapter(_sseDio);

    _setupInterceptors();
    _setupSseInterceptors();
  }
  late final Dio _dio;
  late final Dio _sseDio;
  String? _basicAuthHeader;
  Uri? _basicAuthOrigin;
  String? _oauthBearerToken;
  Uri? _oauthOrigin;
  HttpClientAdapter? _tailscaleAdapter;
  String? _stickySessionId;

  static const String _stickySessionIdHeader = 'X-Session-Id';
  static const String _performanceRequestStartMsKey = 'cw_performance_start_ms';

  Dio get dio => _dio;

  /// Isolated Dio instance for SSE long-lived streams.
  Dio get sseDio => _sseDio;

  void updateBaseUrl(String baseUrl) {
    _stickySessionId = null;
    _dio.options.baseUrl = baseUrl;
    _sseDio.options.baseUrl = baseUrl;
    AppLogger.debug('[Dio] Base URL updated: $baseUrl');
  }

  void applyTailscaleAdapter(HttpClientAdapter adapter) {
    _tailscaleAdapter = adapter;
    _dio.httpClientAdapter = adapter;
    _sseDio.httpClientAdapter = adapter;
    AppLogger.debug('[Dio] Tailscale transport enabled');
  }

  void removeTailscaleAdapter() {
    if (_tailscaleAdapter == null) return;
    _tailscaleAdapter = null;
    _dio.httpClientAdapter.close(force: true);
    _dio.httpClientAdapter = Dio().httpClientAdapter;
    configureSseAdapter(_sseDio);
    AppLogger.debug('[Dio] Tailscale transport disabled');
  }

  Dio createHealthCheckDio() {
    final healthDio = Dio(
      BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: Map<String, dynamic>.from(_dio.options.headers),
      ),
    );
    final tailscaleAdapter = _tailscaleAdapter;
    if (tailscaleAdapter != null) {
      healthDio.httpClientAdapter = tailscaleAdapter;
    }
    return healthDio;
  }

  /// Set Basic Authorization header using username and password
  void setBasicAuth(
    String username,
    String password, {
    required String origin,
  }) {
    final credentials = '$username:$password';
    final encoded = base64Encode(utf8.encode(credentials));
    _basicAuthHeader = 'Basic $encoded';
    _basicAuthOrigin = Uri.tryParse(origin);
    _dio.options.headers.remove(ApiConstants.authorization);
    _sseDio.options.headers.remove(ApiConstants.authorization);
    AppLogger.debug('[Dio] Basic auth header set');
  }

  void clearBasicAuth() {
    _basicAuthHeader = null;
    _basicAuthOrigin = null;
    _dio.options.headers.remove(ApiConstants.authorization);
    _sseDio.options.headers.remove(ApiConstants.authorization);
    AppLogger.debug('[Dio] Basic auth header cleared');
  }

  /// Clear every auth owner when the active profile changes.
  void clearAuth() {
    _stickySessionId = null;
    clearBasicAuth();
    clearOAuthToken();
    AppLogger.debug('[Dio] All auth headers cleared');
  }

  void setOAuthToken(String token, {required String origin}) {
    _oauthBearerToken = token;
    _oauthOrigin = Uri.tryParse(origin);
    _dio.options.headers.remove(ApiConstants.authorization);
    _sseDio.options.headers.remove(ApiConstants.authorization);
    AppLogger.debug('[Dio] OAuth bearer token set');
  }

  void clearOAuthToken() {
    _oauthBearerToken = null;
    _oauthOrigin = null;
    _dio.options.headers.remove(ApiConstants.authorization);
    _sseDio.options.headers.remove(ApiConstants.authorization);
    AppLogger.debug('[Dio] OAuth bearer token cleared');
  }

  bool get hasOAuthToken =>
      _oauthBearerToken != null && _oauthBearerToken!.isNotEmpty;

  void _setupInterceptors() {
    // Request interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _applyAuthorization(options);

          _applyStickySessionHeader(options);

          if (AppLogger.loggingEnabled &&
              (AppLogger.performanceLoggingEnabled || !kReleaseMode)) {
            options.extra[_performanceRequestStartMsKey] =
                DateTime.now().millisecondsSinceEpoch;
          }

          if (!kReleaseMode && AppLogger.loggingEnabled) {
            final uri = options.uri.toString();
            AppLogger.debug('[Dio] --> ${options.method.toUpperCase()} $uri');
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          _rememberStickySessionId(
            response.headers.value(_stickySessionIdHeader),
          );
          if (!kReleaseMode && AppLogger.loggingEnabled) {
            final startMs =
                response.requestOptions.extra[_performanceRequestStartMsKey]
                    as int?;
            final elapsedMs = startMs == null
                ? -1
                : DateTime.now().millisecondsSinceEpoch - startMs;
            final uri = response.requestOptions.uri.toString();
            final status = response.statusCode ?? 0;
            final durationLabel = elapsedMs >= 0 ? ' (${elapsedMs}ms)' : '';
            AppLogger.debug(
              '[Dio] <-- $status ${response.requestOptions.method.toUpperCase()} $uri$durationLabel',
            );
          }
          _recordHttpPerformance(
            response.requestOptions,
            status: 'ok',
            statusCode: response.statusCode,
          );
          handler.next(response);
        },
        onError: (error, handler) {
          _rememberStickySessionId(
            error.response?.headers.value(_stickySessionIdHeader),
          );
          if (!kReleaseMode && AppLogger.loggingEnabled) {
            final uri = error.requestOptions.uri.toString();
            final method = error.requestOptions.method.toUpperCase();
            final status = error.response?.statusCode;
            AppLogger.warn(
              '[Dio] xx> ${status ?? 'ERR'} $method $uri: ${error.type.name}',
              error: error,
              stackTrace: error.stackTrace,
            );
          }
          _recordHttpPerformance(
            error.requestOptions,
            status: 'error',
            statusCode: error.response?.statusCode,
            error: error,
            stackTrace: error.stackTrace,
          );
          // Centralized error handling
          _handleError(error);
          handler.next(error);
        },
      ),
    );
  }

  void _recordHttpPerformance(
    RequestOptions options, {
    required String status,
    int? statusCode,
    Object? error,
    StackTrace? stackTrace,
    Set<String> tags = const <String>{'network:http'},
  }) {
    if (!AppLogger.loggingEnabled || !AppLogger.performanceLoggingEnabled) {
      return;
    }
    final startMs = options.extra[_performanceRequestStartMsKey] as int?;
    if (startMs == null) {
      return;
    }
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;
    AppLogger.recordPerformanceTask(
      operation: 'network_request',
      elapsed: Duration(milliseconds: elapsedMs),
      status: status,
      tags: tags,
      context: <String, Object?>{
        'method': options.method.toUpperCase(),
        'hostHash': AppLogger.safeContextId(options.uri.host),
        'route': AppLogger.safePathShape(options.uri),
        'statusCode': statusCode,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Lightweight interceptors for SSE Dio — auth propagation and error logging.
  void _setupSseInterceptors() {
    _sseDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _applyAuthorization(options);

          _applyStickySessionHeader(options);

          if (AppLogger.loggingEnabled &&
              (AppLogger.performanceLoggingEnabled || !kReleaseMode)) {
            options.extra[_performanceRequestStartMsKey] =
                DateTime.now().millisecondsSinceEpoch;
          }

          if (!kReleaseMode && AppLogger.loggingEnabled) {
            final uri = options.uri.toString();
            AppLogger.debug('[SSE] --> ${options.method.toUpperCase()} $uri');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _rememberStickySessionId(
            response.headers.value(_stickySessionIdHeader),
          );
          _recordHttpPerformance(
            response.requestOptions,
            status: 'ok',
            statusCode: response.statusCode,
            tags: const <String>{'network:sse'},
          );
          handler.next(response);
        },
        onError: (error, handler) {
          _rememberStickySessionId(
            error.response?.headers.value(_stickySessionIdHeader),
          );
          if (!kReleaseMode && AppLogger.loggingEnabled) {
            final uri = error.requestOptions.uri.toString();
            final method = error.requestOptions.method.toUpperCase();
            final status = error.response?.statusCode;
            AppLogger.warn(
              '[SSE] xx> ${status ?? 'ERR'} $method $uri: ${error.type.name}',
            );
          }
          _recordHttpPerformance(
            error.requestOptions,
            status: 'error',
            statusCode: error.response?.statusCode,
            error: error,
            stackTrace: error.stackTrace,
            tags: const <String>{'network:sse'},
          );
          handler.next(error);
        },
      ),
    );
  }

  bool _shouldUseOAuthFor(Uri uri) {
    final token = _oauthBearerToken;
    final origin = _oauthOrigin;
    if (token == null || token.isEmpty || origin == null) return false;
    return uri.scheme == origin.scheme &&
        uri.host == origin.host &&
        uri.port == origin.port;
  }

  void _applyAuthorization(RequestOptions options) {
    const authorization = ApiConstants.authorization;
    final existing = options.headers[authorization]?.toString();
    if (existing?.startsWith('Basic ') == true) {
      options.headers.remove(authorization);
    }
    if (_sameOrigin(options.uri, _basicAuthOrigin) &&
        _basicAuthHeader != null) {
      options.headers[authorization] = _basicAuthHeader;
    }
    if (_shouldUseOAuthFor(options.uri)) {
      options.headers[authorization] = 'Bearer $_oauthBearerToken';
    }
  }

  bool _sameOrigin(Uri uri, Uri? origin) {
    if (origin == null) return false;
    return uri.scheme == origin.scheme &&
        uri.host == origin.host &&
        uri.port == origin.port;
  }

  void _applyStickySessionHeader(RequestOptions options) {
    final sessionId = _stickySessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    options.headers.putIfAbsent(_stickySessionIdHeader, () => sessionId);
  }

  void _rememberStickySessionId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return;
    _stickySessionId = normalized;
  }

  void _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
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
