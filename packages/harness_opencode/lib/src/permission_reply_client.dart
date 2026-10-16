import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'session_projection.dart';
import 'version_policy.dart';

/// A receipt for one reply, not a local resolution of the interaction or batch.
final class OpenCodePermissionReplyAttempt {
  const OpenCodePermissionReplyAttempt({
    required this.command,
    required this.receipt,
    this.payload,
  });
  final OriginalCommand command;
  final CommandReceipt receipt;

  /// Exact attempted body, including private feedback. Keep in memory, not in
  /// diagnostics. Null when nothing was sent; no replay guarantee is implied.
  final String? payload;
}

/// Caller-invoked permission replies only. This does not choose a mode, watch
/// sessions, start an automatic responder, persist grants or retry a mutation.
final class OpenCodePermissionReplyClient {
  OpenCodePermissionReplyClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
    this.maxNoteBytes = 64 * 1024,
  }) {
    if (deadline <= Duration.zero || maxNoteBytes <= 0) {
      throw ArgumentError('Permission reply bounds must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;
  // Local guard, not an upstream limit.
  final int maxNoteBytes;

  Future<OpenCodePermissionReplyAttempt> reply({
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
    RequestCancellation? cancellation,
  }) => _reply(request, response, id, false, cancellation);

  /// Executes only an eligible native `once`, never `always` or a note. The
  /// caller must establish mode/foreground authority before invoking this.
  Future<OpenCodePermissionReplyAttempt> approveOnce({
    required InteractionRequest request,
    required CommandId id,
    RequestCancellation? cancellation,
  }) => _reply(request, ApprovalResponse('once'), id, true, cancellation);

  Future<OpenCodePermissionReplyAttempt> _reply(
    InteractionRequest request,
    ApprovalResponse response,
    CommandId id,
    bool automatic,
    RequestCancellation? cancellation,
  ) async {
    final owner = request.owner;
    if (owner.isKnown && owner.harness != harness) {
      throw ArgumentError('Interaction belongs to another harness.');
    }
    final command = OriginalCommand(
      id: id,
      harness: harness,
      owner: owner,
      operation: const OpenValue.known(MutationOperation.respond),
      connectedVersion: connectedVersion,
      intent: CanonicalValue({
        'requestId': request.id.value,
        'decision': response.choiceId,
        'automatic': automatic,
        'messageIncluded': response.note != null,
      }),
    );
    String? payload;
    OpenCodePermissionReplyAttempt finish(CommandReceipt receipt) =>
        OpenCodePermissionReplyAttempt(
          command: command,
          receipt: receipt,
          payload: payload,
        );
    OpenCodePermissionReplyAttempt unavailable(String reason) =>
        OpenCodePermissionReplyAttempt(
          command: command,
          receipt: CommandReceipt.unavailable(
            id: id,
            owner: owner,
            unavailable: CapabilityUnavailable(
              'permissionReply',
              reason: reason,
            ),
          ),
        );
    OpenCodePermissionReplyAttempt uncertain(String reason) =>
        finish(CommandReceipt.uncertain(id: id, owner: owner, reason: reason));
    OpenCodePermissionReplyAttempt rejected(
      ErrorKind kind,
      String type, {
      ErrorAction? action,
      bool retryable = false,
    }) => finish(
      CommandReceipt.rejected(
        id: id,
        owner: owner,
        error: ErrorInfo(
          kind: OpenValue.known(kind),
          rawType: type,
          rawMessage: '',
          retryable: retryable,
          action: action == null ? null : OpenValue.known(action),
        ),
      ),
    );
    if (OpenCodeCompatibility.parse(connectedVersion)?.toString() != '2.0.22') {
      return unavailable('unverifiedVersion');
    }
    if (owner is! SessionOwner || !owner.isKnown) {
      return unavailable('unsupportedOwner');
    }
    try {
      openCodeSessionId(owner.session.nativeId);
    } on FormatException {
      return unavailable('invalidSession');
    }
    if (!_boundedText(request.id.value, 4096) ||
        !request.id.value.startsWith('per')) {
      return unavailable('invalidRequestId');
    }
    if (request.kind.known != InteractionKind.permission ||
        request.form != null ||
        request.requiresInput) {
      return unavailable('unsupportedInteraction');
    }
    if (request.validateResponse(response).isNotEmpty ||
        request.choices.any((choice) => !_nativeChoice(choice))) {
      return unavailable('unsupportedChoice');
    }
    if (automatic && request.automaticChoice?.id != 'once') {
      return unavailable('notAutoApprovable');
    }
    final note = response.note;
    if (note != null && !_boundedText(note, maxNoteBytes)) {
      return unavailable('invalidNote');
    }
    if (cancellation?.isCancelled ?? false) {
      return unavailable('cancelledBeforeSend');
    }
    if (transport.isClosed) return unavailable('closed');

    // Preserve native truthiness: null omits the field, an empty message is a
    // decline, and spaces are feedback. Never silently trim or swap variants.
    final encoded = jsonEncode({
      'decision': response.choiceId,
      'message': ?note,
    });
    final token = RequestCancellation();
    final expired = Completer<Never>();
    expired.future.ignore();
    var timedOut = false;
    void stop(TransportFailure failure) {
      token.cancel();
      if (!expired.isCompleted) {
        expired.completeError(TransportException(failure));
      }
    }

    final timer = Timer(deadline, () {
      timedOut = true;
      stop(TransportFailure.timeout);
    });
    final parent = cancellation?.onCancel.listen(
      (_) => stop(TransportFailure.cancelled),
    );
    TransportResponse? receipt;
    try {
      payload = encoded;
      final sending = transport.send(
        TransportRequest(
          method: 'POST',
          path: Uri(
            pathSegments: [
              'api',
              'session',
              owner.session.nativeId,
              'permission',
              request.id.value,
              'reply',
            ],
          ).toString(),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: utf8.encode(encoded),
        ),
        cancellation: token,
      );
      unawaited(
        sending.then((late) {
          if (token.isCancelled) late.cancel();
        }, onError: (Object _) {}),
      );
      final current = await Future.any<TransportResponse>([
        sending,
        expired.future,
      ]);
      receipt = current;
      // No status needs a response body, including 204. In particular, 404
      // cannot tell us who answered or whether the session itself disappeared.
      return switch (current.statusCode) {
        204 => finish(CommandReceipt.accepted(id: id, owner: owner)),
        400 => rejected(ErrorKind.protocol, 'InvalidRequestError'),
        401 || 403 => rejected(
          ErrorKind.auth,
          'UnauthorizedError',
          action: ErrorAction.authenticate,
        ),
        404 => rejected(
          ErrorKind.protocol,
          'NotFoundError',
          action: ErrorAction.refresh,
        ),
        429 => rejected(ErrorKind.rateLimit, 'RateLimited', retryable: true),
        final status => uncertain('status$status'),
      };
    } on TransportException catch (error) {
      if (timedOut) return uncertain('timeout');
      if (receipt == null &&
          (error.failure == TransportFailure.invalidTarget ||
              error.failure == TransportFailure.invalidRequest)) {
        return unavailable(error.failure.name);
      }
      return uncertain(error.failure.name);
    } on Object {
      return uncertain(timedOut ? 'timeout' : 'unexpectedTransportFailure');
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      receipt?.cancel();
    }
  }
}

bool _boundedText(String value, int bytes) =>
    value.length <= bytes &&
    utf8.encode(value).length <= bytes &&
    utf8.decode(utf8.encode(value)) == value;

bool _nativeChoice(ApprovalChoice choice) => switch (choice.id) {
  'once' =>
    choice.allows &&
        !choice.acceptsNote &&
        choice.scope.known == ApprovalScope.once &&
        choice.resolutionScope.known == ResolutionScope.request,
  'always' =>
    choice.allows &&
        !choice.acceptsNote &&
        choice.scope.known == ApprovalScope.persistentProject &&
        choice.resolutionScope.known == ResolutionScope.project &&
        _savePreview(choice),
  'reject' =>
    !choice.allows &&
        choice.acceptsNote &&
        choice.scope.known == ApprovalScope.once &&
        choice.resolutionScope.known == ResolutionScope.session,
  _ => false,
};

bool _savePreview(ApprovalChoice choice) {
  final preview = choice.scopePreview?.value;
  final patterns = preview is Map ? preview['patterns'] : null;
  return patterns is List &&
      patterns.isNotEmpty &&
      patterns.every(
        (p) => p is String && p.isNotEmpty && _boundedText(p, 4096),
      );
}
