import 'values.dart';

enum ErrorKind {
  auth,
  quota,
  rateLimit,
  contextOverflow,
  network,
  contentFilter,
  permissionRejected,
  toolFailure,
  versionUnsupported,
  protocol,
  unknown,
}

enum ErrorAction {
  authenticate,
  retryRecovery,
  refresh,
  upgrade,
  changeModel,
  contactHost,
}

/// Recovery hints never grant permission to replay an uncertain mutation.
final class ErrorInfo {
  ErrorInfo({
    required this.kind,
    required String rawType,
    required this.rawMessage,
    this.retryable = false,
    this.retryAt,
    this.action,
    this.details,
  }) : rawType = requireText(rawType, 'rawType');
  final OpenValue<ErrorKind> kind;
  final String rawType;
  final String rawMessage;
  final bool retryable;
  final DateTime? retryAt;
  final OpenValue<ErrorAction>? action;
  final CanonicalValue? details;
}

final class CapabilityUnavailable implements Exception {
  CapabilityUnavailable(String capability, {required String reason})
    : capability = requireText(capability),
      reason = requireText(reason);
  final String capability;
  final String reason;
  @override
  String toString() => 'CapabilityUnavailable($capability: $reason)';
}
