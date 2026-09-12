import '../../core/i18n/l10n_bridge.dart';

class ChatServerErrorDisplay {
  const ChatServerErrorDisplay({required this.name, required this.message});

  final String name;
  final String message;
}

bool isServerConnectionFailure({
  String? rawMessage,
  String? code,
  int? statusCode,
}) {
  final normalizedMessage = _sanitizeMessage(rawMessage);
  final normalizedCode = code?.trim().toLowerCase() ?? '';
  final combined = '$normalizedCode $normalizedMessage'.toLowerCase();

  return statusCode == 408 ||
      combined.contains('network connection failed') ||
      combined.contains('network connection error') ||
      combined.contains('connection timeout') ||
      combined.contains('connection refused') ||
      combined.contains('connection reset') ||
      combined.contains('failed host lookup') ||
      combined.contains('socketexception') ||
      combined.contains('network is unreachable') ||
      combined.contains('unable to connect') ||
      combined.contains('timed out');
}

bool isServerUnavailableFailure({
  String? rawMessage,
  String? code,
  int? statusCode,
}) {
  final normalizedMessage = _sanitizeMessage(rawMessage);
  final normalizedCode = code?.trim().toLowerCase() ?? '';
  final combined = '$normalizedCode $normalizedMessage'.toLowerCase();

  return (statusCode != null && statusCode >= 500) ||
      combined.contains('service unavailable') ||
      combined.contains('provider unavailable') ||
      combined.contains('temporarily unavailable') ||
      combined.contains('gateway timeout');
}

ChatServerErrorDisplay formatServerErrorForDisplay({
  String? rawMessage,
  String? code,
  int? statusCode,
}) {
  final l10n = L10nBridge.current;
  final normalizedMessage = _sanitizeMessage(rawMessage);
  final normalizedCode = code?.trim().toLowerCase() ?? '';
  final combined = '$normalizedCode $normalizedMessage'.toLowerCase();

  if (isServerConnectionFailure(
    rawMessage: rawMessage,
    code: code,
    statusCode: statusCode,
  )) {
    return ChatServerErrorDisplay(
      name: l10n?.errorConnectionFailed ?? 'Connection failed',
      message: l10n?.errorConnectionFailedDesc ?? 'Unable to reach the server. Check connection and server status.',
    );
  }

  final hasQuotaSignal =
      combined.contains('insufficient_quota') ||
      combined.contains('usage_not_included') ||
      combined.contains('quota') ||
      combined.contains('billing') ||
      combined.contains('credit');
  if (hasQuotaSignal) {
    return ChatServerErrorDisplay(
      name: l10n?.errorQuotaExceeded ?? 'Quota exceeded',
      message: l10n?.errorQuotaExceededDesc ?? 'Quota exceeded. Check your provider plan or billing.',
    );
  }

  final hasRateLimitSignal =
      statusCode == 429 ||
      normalizedCode == '429' ||
      combined.contains('rate limit') ||
      combined.contains('too many requests') ||
      combined.contains('status: 429') ||
      combined.contains('status code 429');
  if (hasRateLimitSignal) {
    return ChatServerErrorDisplay(
      name: l10n?.errorRateLimitExceeded ?? 'Rate limit exceeded',
      message: l10n?.errorRateLimitExceededDesc ?? 'Rate limit exceeded. Wait a moment and try again.',
    );
  }

  final hasAuthSignal =
      statusCode == 401 ||
      statusCode == 403 ||
      combined.contains('unauthorized') ||
      combined.contains('forbidden') ||
      combined.contains('authentication') ||
      combined.contains('invalid api key') ||
      combined.contains('token refresh failed');
  if (hasAuthSignal) {
    return ChatServerErrorDisplay(
      name: l10n?.errorAuthRequired ?? 'Authentication required',
      message: l10n?.errorAuthRequiredDesc ?? 'Authentication failed. Reconnect the provider and try again.',
    );
  }

  if (statusCode == 503 ||
      combined.contains('service temporarily unavailable')) {
    return ChatServerErrorDisplay(
      name: l10n?.errorServiceUnavailable ?? 'Service unavailable',
      message: l10n?.errorServiceUnavailableDesc ?? 'Service temporarily unavailable. The server may be starting up — please try again shortly.',
    );
  }

  if (isServerUnavailableFailure(
    rawMessage: rawMessage,
    code: code,
    statusCode: statusCode,
  )) {
    return ChatServerErrorDisplay(
      name: l10n?.errorProviderUnavailable ?? 'Provider unavailable',
      message: l10n?.errorProviderUnavailableDesc ?? 'Provider temporarily unavailable. Try again shortly.',
    );
  }

  if (normalizedMessage.isNotEmpty) {
    return ChatServerErrorDisplay(
      name: l10n?.errorServerError ?? 'Server error',
      message: normalizedMessage,
    );
  }

  return ChatServerErrorDisplay(
    name: l10n?.errorServerError ?? 'Server error',
    message: l10n?.errorServerErrorDesc ?? 'Server error. Please try again.',
  );
}

String _sanitizeMessage(String? input) {
  if (input == null) {
    return '';
  }
  var sanitized = input.trim();
  if (sanitized.isEmpty) {
    return '';
  }
  if (sanitized.startsWith('Exception:')) {
    sanitized = sanitized.substring('Exception:'.length).trim();
  }
  if (sanitized.startsWith('Error:')) {
    sanitized = sanitized.substring('Error:'.length).trim();
  }
  sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
  if (sanitized.length > 160) {
    sanitized = '${sanitized.substring(0, 157)}...';
  }
  return sanitized;
}
