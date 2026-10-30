import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'session_projection.dart';
import 'version_policy.dart';

/// A receipt for one form reply or dismiss, not a local resolution of the form.
final class OpenCodeFormReplyAttempt {
  const OpenCodeFormReplyAttempt({
    required this.command,
    required this.receipt,
    this.payload,
  });
  final OriginalCommand command;
  final CommandReceipt receipt;

  /// Exact attempted body. Keep in memory, not in diagnostics. Null when nothing
  /// was sent; no replay guarantee is implied.
  final String? payload;
}

/// Caller-invoked form replies and dismissals.
final class OpenCodeFormReplyClient {
  OpenCodeFormReplyClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
  }) {
    if (deadline <= Duration.zero) {
      throw ArgumentError('Form reply bounds must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;

  Future<OpenCodeFormReplyAttempt> reply({
    required InteractionRequest request,
    required FormResponse response,
    required CommandId id,
    RequestCancellation? cancellation,
  }) => _execute(
    request: request,
    id: id,
    isDismiss: false,
    response: response,
    cancellation: cancellation,
  );

  Future<OpenCodeFormReplyAttempt> dismiss({
    required InteractionRequest request,
    required CommandId id,
    RequestCancellation? cancellation,
  }) => _execute(
    request: request,
    id: id,
    isDismiss: true,
    response: null,
    cancellation: cancellation,
  );

  Future<OpenCodeFormReplyAttempt> _execute({
    required InteractionRequest request,
    required CommandId id,
    required bool isDismiss,
    required FormResponse? response,
    RequestCancellation? cancellation,
  }) async {
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
        'action': isDismiss ? 'dismiss' : 'reply',
        if (response != null) 'answers': response.answers.toJson(),
      }),
    );
    String? payload;
    OpenCodeFormReplyAttempt finish(CommandReceipt receipt) =>
        OpenCodeFormReplyAttempt(
          command: command,
          receipt: receipt,
          payload: payload,
        );
    OpenCodeFormReplyAttempt unavailable(String reason) =>
        OpenCodeFormReplyAttempt(
          command: command,
          receipt: CommandReceipt.unavailable(
            id: id,
            owner: owner,
            unavailable: CapabilityUnavailable('formReply', reason: reason),
          ),
        );
    OpenCodeFormReplyAttempt uncertain(String reason) =>
        finish(CommandReceipt.uncertain(id: id, owner: owner, reason: reason));
    OpenCodeFormReplyAttempt rejected(
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

    if (!OpenCodeCompatibility.supportsV2(connectedVersion)) {
      return unavailable('unverifiedVersion');
    }
    String ownerSegment;
    if (owner is SessionOwner && owner.isKnown) {
      try {
        ownerSegment = openCodeSessionId(owner.session.nativeId);
      } on FormatException {
        return unavailable('invalidSession');
      }
    } else if (owner is GlobalOwner && owner.isKnown) {
      ownerSegment = 'global';
    } else {
      return unavailable('unsupportedOwner');
    }

    if (!_boundedText(request.id.value, 4096) ||
        !request.id.value.startsWith('frm_')) {
      return unavailable('invalidRequestId');
    }
    if (request.kind.known != InteractionKind.form) {
      return unavailable('unsupportedInteraction');
    }
    if (!isDismiss) {
      if (request.form == null) {
        return unavailable('unsupportedInteraction');
      }
      if (response == null || request.validateResponse(response).isNotEmpty) {
        return unavailable('invalidFormAnswers');
      }
    }
    if (cancellation?.isCancelled ?? false) {
      return unavailable('cancelledBeforeSend');
    }
    if (transport.isClosed) return unavailable('closed');

    final String? encoded = isDismiss
        ? null
        : jsonEncode({'answer': response!.answers.toJson()});

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
      final pathSegments = isDismiss
          ? ['api', 'session', ownerSegment, 'form', request.id.value]
          : ['api', 'session', ownerSegment, 'form', request.id.value, 'reply'];
      final sending = transport.send(
        TransportRequest(
          method: isDismiss ? 'DELETE' : 'POST',
          path: Uri(pathSegments: pathSegments).toString(),
          headers: {
            'Accept': 'application/json',
            if (!isDismiss) 'Content-Type': 'application/json',
          },
          body: encoded != null ? utf8.encode(encoded) : null,
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
        409 => rejected(
          ErrorKind.protocol,
          'FormAlreadySettledError',
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
