import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'inbox_projection.dart';
import 'session_projection.dart';
import 'version_policy.dart';

/// The outcome of one `POST /api/session/{id}/prompt`. [messageId] is the
/// reconciliation key even when the receipt is uncertain; [payload] is the
/// exact body sent, which a later same-id replay must repeat unchanged.
final class OpenCodePromptAttempt {
  const OpenCodePromptAttempt._({
    required this.command,
    required this.messageId,
    required this.receipt,
    this.payload,
    this.submission,
    this.pending,
    this.items = const [],
  });

  final OriginalCommand command;
  final String messageId;
  final CommandReceipt receipt;

  /// Null when nothing was sent.
  final String? payload;
  final SubmissionState? submission;

  /// The admitted inbox row, built like hydration and the live stream build
  /// it; a steer prompt also yields its pending [UserInput].
  final PendingInput? pending;
  final List<TimelineItem> items;

  bool get posted => payload != null;
}

/// Sends one text prompt to an OpenCode 2.0.22 session and maps the single
/// response; it never retries, persists, reads the inbox or mints the id.
/// The caller mints (and later persists) [messageId] before calling [send].
///
/// Admission is not delivery: a 200 is `admitted`, never delivered or
/// settled. A response that cannot prove what happened is `uncertain`, so a
/// later reconciliation decides; only a definite refusal is `rejected`.
/// A same-id 200 matching this intent is admitted even if that id was already
/// promoted to history, so reconcile by native id before applying it again.
final class OpenCodePromptClient {
  OpenCodePromptClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 1024 * 1024,
  }) {
    // Rejected here, not after the POST where it would lose the receipt.
    if (deadline <= Duration.zero || maxBodyBytes <= 0) {
      throw ArgumentError('Prompt deadline and body limit must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;
  final int maxBodyBytes;

  Future<OpenCodePromptAttempt> send({
    required SessionRef session,
    required CommandId commandId,
    required String messageId,
    required PromptDraft draft,
    required Delivery delivery,
    bool resume = true,
    RequestCancellation? cancellation,
  }) async {
    if (session.harnessRef != harness) {
      throw ArgumentError.value(
        session,
        'session',
        'Belongs to another harness',
      );
    }
    final owner = SessionOwner(session);
    final command = OriginalCommand(
      id: commandId,
      harness: harness,
      owner: owner,
      operation: const OpenValue.known(MutationOperation.prompt),
      connectedVersion: connectedVersion,
      intent: CanonicalValue({
        'messageId': messageId,
        'text': draft.text,
        'delivery': delivery.name,
        'resume': resume,
      }),
    );
    OpenCodePromptAttempt unavailable(String reason) => OpenCodePromptAttempt._(
      command: command,
      messageId: messageId,
      receipt: CommandReceipt.unavailable(
        id: commandId,
        owner: owner,
        unavailable: CapabilityUnavailable('prompt', reason: reason),
      ),
    );
    // Only the observed 2.0.22 admission semantics are relied on.
    if (OpenCodeCompatibility.parse(connectedVersion)?.toString() != '2.0.22') {
      return unavailable('unverifiedVersion');
    }
    try {
      openCodeSessionId(session.nativeId);
    } on FormatException {
      return unavailable('invalidSession');
    }
    if (!messageId.startsWith('msg_') ||
        messageId.length > 4096 ||
        messageId.contains(RegExp(r'\s'))) {
      return unavailable('invalidMessageId');
    }
    // Attachments, mentions, selection and metadata are later children;
    // never send a draft with fields silently dropped.
    if (draft.attachments.isNotEmpty ||
        draft.mentions.isNotEmpty ||
        draft.selection != null ||
        draft.metadata != null) {
      return unavailable('unsupportedDraft');
    }
    if (draft.text.trim().isEmpty) return unavailable('emptyText');
    if (delivery != Delivery.steer && delivery != Delivery.queue) {
      return unavailable('unsupportedDelivery');
    }
    if (cancellation?.isCancelled ?? false) {
      return unavailable('cancelledBeforeSend');
    }
    if (transport.isClosed) return unavailable('closed');
    final payload = jsonEncode({
      'id': messageId,
      'text': draft.text,
      'delivery': delivery.name,
      'resume': resume,
    });
    OpenCodePromptAttempt finish(
      CommandReceipt receipt,
      SubmissionKind kind, {
      ErrorInfo? error,
      PendingInput? pending,
      List<TimelineItem> items = const [],
    }) => OpenCodePromptAttempt._(
      command: command,
      messageId: messageId,
      receipt: receipt,
      payload: payload,
      submission: SubmissionState(
        kind: OpenValue.known(kind),
        delivery: kind == SubmissionKind.admitted
            ? OpenValue.known(delivery)
            : null,
        error: error,
      ),
      pending: pending,
      items: items,
    );
    OpenCodePromptAttempt rejected(ErrorInfo error) => finish(
      CommandReceipt.rejected(id: commandId, owner: owner, error: error),
      SubmissionKind.rejected,
      error: error,
    );
    OpenCodePromptAttempt uncertain(String reason) => finish(
      CommandReceipt.uncertain(id: commandId, owner: owner, reason: reason),
      SubmissionKind.uncertain,
    );

    final token = RequestCancellation();
    var timedOut = false;
    // The deadline bounds headers and body even if a transport ignores
    // cancellation.
    final expired = Completer<Never>();
    expired.future.ignore();
    final timer = Timer(deadline, () {
      timedOut = true;
      token.cancel();
      expired.completeError(const TransportException(TransportFailure.timeout));
    });
    final parent = cancellation?.onCancel.listen((_) => token.cancel());
    TransportResponse? response;
    try {
      final sending = transport.send(
        TransportRequest(
          method: 'POST',
          path: Uri(
            pathSegments: ['api', 'session', session.nativeId, 'prompt'],
          ).toString(),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: utf8.encode(payload),
        ),
        cancellation: token,
      );
      unawaited(
        sending.then((late) {
          if (timedOut) late.cancel();
        }, onError: (Object _) {}),
      );
      final current = await Future.any<TransportResponse>([
        sending,
        expired.future,
      ]);
      response = current;
      final status = current.statusCode;
      // A definite refusal is known from the status alone; its body is not
      // read, so a slow or oversized error body cannot make it uncertain.
      if (status != 200) {
        return switch (status) {
          400 => rejected(_error(ErrorKind.protocol, 'InvalidRequestError')),
          401 || 403 => rejected(
            _error(
              ErrorKind.auth,
              'UnauthorizedError',
              action: ErrorAction.authenticate,
            ),
          ),
          404 => rejected(_error(ErrorKind.protocol, 'NotFoundError')),
          // Another durable record owns this id (for example another
          // session); 2.0.22 does not use 409 for changed pending text.
          409 => rejected(
            _error(
              ErrorKind.protocol,
              'ConflictError',
              action: ErrorAction.refresh,
            ),
          ),
          429 => rejected(
            _error(ErrorKind.rateLimit, 'RateLimited', retryable: true),
          ),
          _ => uncertain('status$status'),
        };
      }
      final bytes = await Future.any<Uint8List>([
        current.readBytes(maxBytes: maxBodyBytes, inactivityTimeout: deadline),
        expired.future,
      ]);
      final Object? body;
      try {
        body = jsonDecode(utf8.decode(bytes));
      } on FormatException {
        return uncertain('malformedAdmission');
      }
      final data = body is Map<String, Object?> ? body['data'] : null;
      if (data is! Map<String, Object?> ||
          data['id'] != messageId ||
          data['type'] != 'user') {
        return uncertain('malformedAdmission');
      }
      final row = openCodeInboxRow(
        data,
        session,
        sourceVersion: connectedVersion,
        generation: 'prompt',
      );
      final pending = row.pending;
      if (pending == null) return uncertain('malformedAdmission');
      // A pending same-id replay returns the original admission, even for
      // changed text or delivery: this intent was not admitted.
      if (pending.text != draft.text || pending.delivery.known != delivery) {
        return rejected(
          _error(
            ErrorKind.protocol,
            'PromptIdentityOccupied',
            action: ErrorAction.refresh,
          ),
        );
      }
      return finish(
        CommandReceipt.accepted(
          id: commandId,
          owner: owner,
          nativeRef: messageId,
        ),
        SubmissionKind.admitted,
        pending: pending,
        items: row.items,
      );
    } on OpenCodeInboxProjectionException {
      return uncertain('malformedAdmission');
    } on FormatException {
      return uncertain('malformedAdmission');
    } on TransportException catch (error) {
      if (timedOut) return uncertain('timeout');
      return switch (error.failure) {
        // Refused locally before anything reached the wire. A close while
        // sending may follow the body, so it stays uncertain.
        TransportFailure.invalidTarget || TransportFailure.invalidRequest
            when response == null =>
          unavailable(error.failure.name),
        _ => uncertain(error.failure.name),
      };
    } on Object {
      // Out-of-contract transport errors still keep the id and payload.
      if (timedOut) return uncertain('timeout');
      return uncertain('unexpectedTransportFailure');
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      response?.cancel();
    }
  }
}

ErrorInfo _error(
  ErrorKind kind,
  String rawType, {
  ErrorAction? action,
  bool retryable = false,
}) => ErrorInfo(
  kind: OpenValue.known(kind),
  rawType: rawType,
  // Native messages can echo ids or paths; they are not shown verbatim.
  rawMessage: '',
  retryable: retryable,
  action: action == null ? null : OpenValue.known(action),
);
