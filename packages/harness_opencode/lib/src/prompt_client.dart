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

  /// Prepares and posts in one call; see [prepare] and [post].
  Future<OpenCodePromptAttempt> send({
    required SessionRef session,
    required CommandId commandId,
    required String messageId,
    required PromptDraft draft,
    required Delivery delivery,
    bool resume = true,
    RequestCancellation? cancellation,
  }) async => switch (prepare(
    session: session,
    commandId: commandId,
    messageId: messageId,
    draft: draft,
    delivery: delivery,
    resume: resume,
  )) {
    OpenCodePromptRefused(:final attempt) => attempt,
    final OpenCodePromptReady ready => await post(
      ready,
      cancellation: cancellation,
    ),
  };

  /// Checks a draft and builds the exact body without any network access, so
  /// a caller can persist it before [post]. A refusal sends nothing.
  OpenCodePromptPreparation prepare({
    required SessionRef session,
    required CommandId commandId,
    required String messageId,
    required PromptDraft draft,
    required Delivery delivery,
    bool resume = true,
  }) {
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
    OpenCodePromptRefused unavailable(String reason) =>
        OpenCodePromptRefused._(_unavailable(command, messageId, reason));
    // Later v2 versions are usable but remain marked untested.
    if (!OpenCodeCompatibility.supportsV2(connectedVersion)) {
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
    return OpenCodePromptReady._(
      session: session,
      command: command,
      messageId: messageId,
      text: draft.text,
      delivery: delivery,
      resume: resume,
      payload: jsonEncode({
        'id': messageId,
        'text': draft.text,
        'delivery': delivery.name,
        'resume': resume,
      }),
    );
  }

  /// Posts exactly [OpenCodePromptReady.payload] once and maps the response.
  Future<OpenCodePromptAttempt> post(
    OpenCodePromptReady ready, {
    RequestCancellation? cancellation,
  }) async {
    final OpenCodePromptReady(:session, :command, :messageId, :payload) = ready;
    final delivery = ready.delivery;
    final commandId = command.id;
    final owner = command.owner;
    if (session.harnessRef != harness ||
        command.connectedVersion != connectedVersion) {
      throw ArgumentError.value(ready, 'ready', 'Prepared by another client');
    }
    if (cancellation?.isCancelled ?? false) {
      return _unavailable(command, messageId, 'cancelledBeforeSend');
    }
    if (transport.isClosed) {
      return _unavailable(command, messageId, 'closed');
    }
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
      if (pending.text != ready.text || pending.delivery.known != delivery) {
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
          _unavailable(command, messageId, error.failure.name),
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

  /// `DELETE /api/session/{id}/inbox/{messageId}` once. A 204 is not proof of
  /// cancellation: 2.0.22 also answers 204 for a delivered or unknown id, so
  /// the caller decides the outcome from the inbox and history.
  Future<OpenCodeInboxResult> cancelInbox({
    required SessionRef session,
    required String messageId,
    RequestCancellation? cancellation,
  }) => _inbox('DELETE', session, messageId, null, cancellation);

  /// `PATCH /api/session/{id}/inbox/{messageId}` with `{delivery}` once.
  /// Steering wakes execution. A 409 (observed for a delivered id) and a 204
  /// are both confirmed from the inbox and history by the caller.
  Future<OpenCodeInboxResult> switchInboxDelivery({
    required SessionRef session,
    required String messageId,
    required Delivery delivery,
    RequestCancellation? cancellation,
  }) {
    if (delivery != Delivery.steer && delivery != Delivery.queue) {
      return Future.value(const OpenCodeInboxNotSent('unsupportedDelivery'));
    }
    return _inbox(
      'PATCH',
      session,
      messageId,
      jsonEncode({'delivery': delivery.name}),
      cancellation,
    );
  }

  Future<OpenCodeInboxResult> _inbox(
    String method,
    SessionRef session,
    String messageId,
    String? body,
    RequestCancellation? cancellation,
  ) async {
    if (session.harnessRef != harness) {
      throw ArgumentError.value(
        session,
        'session',
        'Belongs to another harness',
      );
    }
    if (!OpenCodeCompatibility.supportsV2(connectedVersion)) {
      return const OpenCodeInboxNotSent('unverifiedVersion');
    }
    try {
      openCodeSessionId(session.nativeId);
    } on FormatException {
      return const OpenCodeInboxNotSent('invalidSession');
    }
    if (!messageId.startsWith('msg_') ||
        messageId.length > 4096 ||
        messageId.contains(RegExp(r'\s'))) {
      return const OpenCodeInboxNotSent('invalidMessageId');
    }
    if (cancellation?.isCancelled ?? false) {
      return const OpenCodeInboxNotSent('cancelledBeforeSend');
    }
    if (transport.isClosed) return const OpenCodeInboxNotSent('closed');
    final token = RequestCancellation();
    var timedOut = false;
    // The deadline bounds the headers even if a transport ignores
    // cancellation; no body is ever read.
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
          method: method,
          path: Uri(
            pathSegments: [
              'api',
              'session',
              session.nativeId,
              'inbox',
              messageId,
            ],
          ).toString(),
          headers: {
            'Accept': 'application/json',
            if (body != null) 'Content-Type': 'application/json',
          },
          body: body == null ? null : utf8.encode(body),
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
      // The status alone decides; error bodies can echo ids.
      return switch (current.statusCode) {
        204 => const OpenCodeInboxCompleted(),
        400 => OpenCodeInboxRefused(
          _error(ErrorKind.protocol, 'InvalidRequestError'),
        ),
        401 || 403 => OpenCodeInboxRefused(
          _error(
            ErrorKind.auth,
            'UnauthorizedError',
            action: ErrorAction.authenticate,
          ),
        ),
        404 => OpenCodeInboxRefused(
          _error(ErrorKind.protocol, 'SessionNotFoundError'),
        ),
        409 => OpenCodeInboxRefused(
          _error(
            ErrorKind.protocol,
            'ConflictError',
            action: ErrorAction.refresh,
          ),
        ),
        429 => OpenCodeInboxRefused(
          _error(ErrorKind.rateLimit, 'RateLimited', retryable: true),
        ),
        final status => OpenCodeInboxUncertain('status$status'),
      };
    } on TransportException catch (error) {
      if (timedOut) return const OpenCodeInboxUncertain('timeout');
      return switch (error.failure) {
        TransportFailure.invalidTarget || TransportFailure.invalidRequest
            when response == null =>
          OpenCodeInboxNotSent(error.failure.name),
        _ => OpenCodeInboxUncertain(error.failure.name),
      };
    } on Object {
      if (timedOut) return const OpenCodeInboxUncertain('timeout');
      return const OpenCodeInboxUncertain('unexpectedTransportFailure');
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

OpenCodePromptAttempt _unavailable(
  OriginalCommand command,
  String messageId,
  String reason,
) => OpenCodePromptAttempt._(
  command: command,
  messageId: messageId,
  receipt: CommandReceipt.unavailable(
    id: command.id,
    owner: command.owner,
    unavailable: CapabilityUnavailable('prompt', reason: reason),
  ),
);

/// The result of [OpenCodePromptClient.prepare].
sealed class OpenCodePromptPreparation {
  const OpenCodePromptPreparation();
}

/// A checked draft and the exact body [OpenCodePromptClient.post] will send.
final class OpenCodePromptReady extends OpenCodePromptPreparation {
  const OpenCodePromptReady._({
    required this.session,
    required this.command,
    required this.messageId,
    required this.text,
    required this.delivery,
    required this.resume,
    required this.payload,
  });
  final SessionRef session;
  final OriginalCommand command;
  final String messageId;
  final String text;
  final Delivery delivery;
  final bool resume;
  final String payload;
}

/// Nothing is sent; [attempt] carries the unavailable receipt.
final class OpenCodePromptRefused extends OpenCodePromptPreparation {
  const OpenCodePromptRefused._(this.attempt);
  final OpenCodePromptAttempt attempt;
}

/// The single response to an inbox cancel or delivery switch.
sealed class OpenCodeInboxResult {
  const OpenCodeInboxResult();
}

/// 204: the handler succeeded or the request was a no-op.
final class OpenCodeInboxCompleted extends OpenCodeInboxResult {
  const OpenCodeInboxCompleted();
}

/// A definite refusal known from the status alone; the body is not read.
final class OpenCodeInboxRefused extends OpenCodeInboxResult {
  const OpenCodeInboxRefused(this.error);
  final ErrorInfo error;
}

/// It may or may not have been applied.
final class OpenCodeInboxUncertain extends OpenCodeInboxResult {
  const OpenCodeInboxUncertain(this.reason);
  final String reason;
}

/// Nothing reached the wire.
final class OpenCodeInboxNotSent extends OpenCodeInboxResult {
  const OpenCodeInboxNotSent(this.reason);
  final String reason;
}
