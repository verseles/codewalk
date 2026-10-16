import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'session_projection.dart';
import 'version_policy.dart';

/// A receipt for the request, not proof that asynchronous cleanup has settled.
final class OpenCodeInterruptAttempt {
  const OpenCodeInterruptAttempt({
    required this.command,
    required this.receipt,
    this.interrupted,
  });
  final OriginalCommand command;
  final CommandReceipt receipt;
  final bool? interrupted;
}

/// Stops the session's current execution once. No resume, persistence or replay:
/// a repeated interrupt could stop a successor execution instead.
final class OpenCodeInterruptClient {
  OpenCodeInterruptClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 4096,
  }) {
    if (deadline <= Duration.zero || maxBodyBytes <= 0) {
      throw ArgumentError('Interrupt bounds must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;
  final int maxBodyBytes;

  Future<OpenCodeInterruptAttempt> interrupt({
    required SessionRef session,
    required CommandId id,
    RequestCancellation? cancellation,
  }) async {
    if (session.harnessRef != harness) {
      throw ArgumentError('Session belongs to another harness.');
    }
    final owner = SessionOwner(session);
    final command = OriginalCommand(
      id: id,
      harness: harness,
      owner: owner,
      operation: const OpenValue.known(MutationOperation.interrupt),
      connectedVersion: connectedVersion,
      intent: CanonicalValue({'target': 'currentExecution', 'resume': false}),
    );
    OpenCodeInterruptAttempt finish(CommandReceipt receipt, [bool? value]) =>
        OpenCodeInterruptAttempt(
          command: command,
          receipt: receipt,
          interrupted: value,
        );
    OpenCodeInterruptAttempt unavailable(String reason) => finish(
      CommandReceipt.unavailable(
        id: id,
        owner: owner,
        unavailable: CapabilityUnavailable('interrupt', reason: reason),
      ),
    );
    OpenCodeInterruptAttempt uncertain(String reason) =>
        finish(CommandReceipt.uncertain(id: id, owner: owner, reason: reason));
    OpenCodeInterruptAttempt rejected(ErrorKind kind, String type) => finish(
      CommandReceipt.rejected(
        id: id,
        owner: owner,
        error: ErrorInfo(
          kind: OpenValue.known(kind),
          rawType: type,
          rawMessage: '',
          retryable: false,
        ),
      ),
    );
    if (OpenCodeCompatibility.parse(connectedVersion)?.toString() != '2.0.22') {
      return unavailable('unverifiedVersion');
    }
    try {
      openCodeSessionId(session.nativeId);
    } on FormatException {
      return unavailable('invalidSession');
    }
    if (cancellation?.isCancelled ?? false) {
      return unavailable('cancelledBeforeSend');
    }
    if (transport.isClosed) return unavailable('closed');

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
    TransportResponse? response;
    try {
      final sending = transport.send(
        TransportRequest(
          method: 'POST',
          path: Uri(
            pathSegments: ['api', 'session', session.nativeId, 'interrupt'],
          ).toString(),
          headers: const {'Accept': 'application/json'},
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
      response = current;
      // Refusals are known from the status; never read a native error body.
      if (current.statusCode != 200) {
        return switch (current.statusCode) {
          400 => rejected(ErrorKind.protocol, 'InvalidRequestError'),
          401 || 403 => rejected(ErrorKind.auth, 'UnauthorizedError'),
          404 => rejected(ErrorKind.protocol, 'SessionNotFoundError'),
          429 => rejected(ErrorKind.rateLimit, 'RateLimited'),
          final status => uncertain('status$status'),
        };
      }
      final bytes = await Future.any<Uint8List>([
        current.readBytes(maxBytes: maxBodyBytes, inactivityTimeout: deadline),
        expired.future,
      ]);
      final body = jsonDecode(utf8.decode(bytes));
      // Both real D responses are bare, not the prompt admission's wrapper.
      if (body is! Map<String, Object?> || body['interrupted'] is! bool) {
        return uncertain('malformedInterrupt');
      }
      return finish(
        CommandReceipt.accepted(id: id, owner: owner),
        body['interrupted'] as bool,
      );
    } on TransportException catch (error) {
      if (timedOut) return uncertain('timeout');
      if (response == null &&
          (error.failure == TransportFailure.invalidTarget ||
              error.failure == TransportFailure.invalidRequest)) {
        return unavailable(error.failure.name);
      }
      return uncertain(error.failure.name);
    } on FormatException {
      return uncertain('malformedInterrupt');
    } on Object {
      if (timedOut) return uncertain('timeout');
      return uncertain('unexpectedTransportFailure');
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      response?.cancel();
    }
  }
}
