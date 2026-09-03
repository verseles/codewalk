import 'package:dio/dio.dart';

import '../../core/errors/failures.dart';
import '../../core/i18n/l10n_bridge.dart';

/// Mixin that maps DioException types to domain Failure values.
/// Used by repository implementations to avoid duplicating error-handling logic.
mixin DioExceptionHandler {
  Failure handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return NetworkFailure(
          L10nBridge.current?.errorConnectionTimeout ?? 'Connection timeout',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          if (statusCode >= 400 && statusCode < 500) {
            return NetworkFailure(
              L10nBridge.current?.errorClientError ?? 'Client error',
              statusCode,
            );
          } else if (statusCode >= 500) {
            return ServerFailure(
              L10nBridge.current?.errorServerError ?? 'Server error',
              statusCode,
            );
          }
        }
        // Unexpected 1xx/2xx/3xx from badResponse, or null status — treat as server error.
        return ServerFailure(
          L10nBridge.current?.errorServerErrorDesc ??
              'Server error. Please try again.',
        );
      case DioExceptionType.cancel:
        return NetworkFailure(
          L10nBridge.current?.errorRequestCancelled ?? 'Request cancelled',
        );
      case DioExceptionType.connectionError:
        return NetworkFailure(
          L10nBridge.current?.errorConnectionFailedDesc ??
              'Unable to reach the server. Check connection and server status.',
        );
      case DioExceptionType.unknown:
        return NetworkFailure(
          L10nBridge.current?.errorUnknownNetworkError('${e.message}') ??
              'Unknown network error: ${e.message}',
        );
      case DioExceptionType.badCertificate:
        return NetworkFailure(
          L10nBridge.current?.errorCertificateError ?? 'Certificate error',
        );
    }
  }
}
