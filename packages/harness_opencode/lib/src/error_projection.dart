import 'package:codewalk_core/codewalk_core.dart';

import 'shell_projection.dart';

/// The shown error text is kept within this many UTF-8 bytes, as a tool
/// error's is.
const openCodeErrorMessageLimit = 8 * 1024;

/// The 2.0.22 `Session.StructuredError` types with a category; any other type
/// is [ErrorKind.unknown]. `aborted` has none: it is an interruption.
const _kinds = <String, ErrorKind>{
  'provider.auth': ErrorKind.auth,
  'provider.rate-limit': ErrorKind.rateLimit,
  'provider.quota': ErrorKind.quota,
  'provider.content-filter': ErrorKind.contentFilter,
  'provider.transport': ErrorKind.network,
  'provider.timeout': ErrorKind.network,
  'provider.internal': ErrorKind.provider,
  'provider.invalid-output': ErrorKind.provider,
  'provider.invalid-request': ErrorKind.provider,
  'provider.unsupported-operation': ErrorKind.provider,
  'provider.no-route': ErrorKind.provider,
  'provider.unknown': ErrorKind.provider,
  'provider.error': ErrorKind.provider,
  // 2.0.22 has no context-overflow error: the runner compacts instead, so a
  // failed compaction is the context problem a turn can end with.
  'compaction.failed': ErrorKind.contextOverflow,
  'compaction.interrupted': ErrorKind.contextOverflow,
  'compaction.unavailable': ErrorKind.contextOverflow,
  'permission.rejected': ErrorKind.permissionRejected,
  'tool.execution': ErrorKind.toolFailure,
  'tool.unknown': ErrorKind.toolFailure,
  'tool.input-json': ErrorKind.toolFailure,
  'tool.result-missing': ErrorKind.toolFailure,
};

/// Whether an outcome failed by an error of [type] carries that error.
/// `aborted` is an interruption (a stop, a declined tool or an exhausted
/// restart budget), not an error, so its outcome keeps the plain marker.
bool openCodeErrorHasCard(String type) => type != 'aborted';

/// The typed [ErrorInfo] of a 2.0.22 `Session.StructuredError` of the
/// nonempty [type], with the server's [message].
///
/// The category comes from the exact type alone: the HTTP status, the text and
/// the provider never choose it, and the response body is never read. The
/// message is shown, so it is redacted and bounded first; `details` records
/// whether it was cut or redacted. Every category suggests choosing another
/// model, the one recovery that exists for these failures; the hint never
/// grants a replay.
ErrorInfo openCodeErrorInfo(String type, String? message) {
  final kept = openCodeRedactedText(message ?? '', openCodeErrorMessageLimit);
  return ErrorInfo(
    kind: OpenValue.known(_kinds[type] ?? ErrorKind.unknown),
    rawType: type,
    rawMessage: kept.text,
    action: openCodeErrorHasCard(type)
        ? const OpenValue.known(ErrorAction.changeModel)
        : null,
    details: kept.cut || kept.redacted
        ? CanonicalValue({
            if (kept.cut) 'messageTruncated': true,
            if (kept.redacted) 'messageRedacted': true,
          })
        : null,
  );
}
