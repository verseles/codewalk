import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'item_ids.dart';
import 'revert_projection.dart';
import 'session_projection.dart';
import 'version_policy.dart';

/// One exchange, never proof that asynchronous compaction has completed.
final class OpenCodeTurnAttempt {
  const OpenCodeTurnAttempt({
    required this.command,
    required this.receipt,
    this.payload,
    this.revert,
  });

  final OriginalCommand command;
  final CommandReceipt receipt;
  final String? payload;
  final RevertState? revert;
}

/// Official 2.0.22 turn mutations. Each deliberate call makes at most one
/// request. Lost or malformed success is uncertain and is never replayed here.
final class OpenCodeSessionTurnClient {
  OpenCodeSessionTurnClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 1024 * 1024,
  }) {
    if (deadline <= Duration.zero || maxBodyBytes <= 0) {
      throw ArgumentError('Turn command bounds must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;
  final int maxBodyBytes;

  Future<OpenCodeTurnAttempt> stage({
    required SessionRef session,
    required RevertRequest request,
    required CommandId id,
    RequestCancellation? cancellation,
  }) {
    final nativeMessage = openCodeMessageIdOf(request.boundary, session);
    return _send(
      session: session,
      id: id,
      operation: MutationOperation.revertStage,
      message: nativeMessage == null ? null : MessageRef(nativeMessage),
      intent: {
        'boundary': request.boundary.value,
        'includeFiles': request.includeFiles,
      },
      body: {'messageID': nativeMessage, 'files': request.includeFiles},
      route: const ['revert', 'stage'],
      method: 'POST',
      cancellation: cancellation,
    );
  }

  Future<OpenCodeTurnAttempt> clear({
    required SessionRef session,
    required CommandId id,
    RequestCancellation? cancellation,
  }) => _send(
    session: session,
    id: id,
    operation: MutationOperation.revertClear,
    route: const ['revert'],
    method: 'DELETE',
    cancellation: cancellation,
  );

  Future<OpenCodeTurnAttempt> commit({
    required SessionRef session,
    required CommandId id,
    RequestCancellation? cancellation,
  }) => _send(
    session: session,
    id: id,
    operation: MutationOperation.revertCommit,
    route: const ['revert', 'commit'],
    method: 'POST',
    cancellation: cancellation,
  );

  Future<OpenCodeTurnAttempt> compact({
    required SessionRef session,
    required MessageRef input,
    required CommandId id,
    RequestCancellation? cancellation,
  }) => _send(
    session: session,
    id: id,
    operation: MutationOperation.compact,
    message: input,
    intent: {'input': input.value, 'delivery': 'steer'},
    body: {'id': input.value, 'delivery': 'steer'},
    route: const ['compact'],
    method: 'POST',
    cancellation: cancellation,
  );

  Future<OpenCodeTurnAttempt> _send({
    required SessionRef session,
    required CommandId id,
    required MutationOperation operation,
    required List<String> route,
    required String method,
    MessageRef? message,
    Map<String, Object?> intent = const {},
    Map<String, Object?>? body,
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
      operation: OpenValue.known(operation),
      connectedVersion: connectedVersion,
      intent: CanonicalValue(intent),
    );
    String? payload;
    OpenCodeTurnAttempt finish(CommandReceipt receipt, [RevertState? revert]) =>
        OpenCodeTurnAttempt(
          command: command,
          receipt: receipt,
          payload: payload,
          revert: revert,
        );
    OpenCodeTurnAttempt unavailable(String reason) => finish(
      CommandReceipt.unavailable(
        id: id,
        owner: owner,
        unavailable: CapabilityUnavailable(operation.name, reason: reason),
      ),
    );
    OpenCodeTurnAttempt uncertain(String reason) =>
        finish(CommandReceipt.uncertain(id: id, owner: owner, reason: reason));
    OpenCodeTurnAttempt rejected(ErrorKind kind, String type) => finish(
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
      if ((operation == MutationOperation.revertStage ||
              operation == MutationOperation.compact) &&
          (message == null || !_messageId(message.value))) {
        return unavailable('invalidMessage');
      }
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
      payload = body == null ? null : jsonEncode(body);
      final sending = transport.send(
        TransportRequest(
          method: method,
          path: Uri(
            pathSegments: ['api', 'session', session.nativeId, ...route],
          ).toString(),
          headers: {
            'Accept': 'application/json',
            if (body != null) 'Content-Type': 'application/json',
          },
          body: payload == null ? null : utf8.encode(payload),
        ),
        cancellation: token,
      );
      unawaited(
        sending.then<void>((late) {
          if (token.isCancelled) late.cancel();
        }, onError: (Object _, StackTrace _) {}),
      );
      final current = await Future.any<TransportResponse>([
        sending,
        expired.future,
      ]);
      response = current;
      final success = body == null ? 204 : 200;
      if (current.statusCode != success) {
        // Known refusals never require reading an error body, which may echo
        // identifiers, paths or workspace contents.
        return switch (current.statusCode) {
          400 => rejected(ErrorKind.protocol, 'InvalidRequestError'),
          401 || 403 => rejected(ErrorKind.auth, 'UnauthorizedError'),
          404 => rejected(ErrorKind.protocol, 'NotFoundError'),
          409 => rejected(
            ErrorKind.protocol,
            operation == MutationOperation.compact
                ? 'ConflictError'
                : 'SessionBusyError',
          ),
          429 => rejected(ErrorKind.rateLimit, 'RateLimited'),
          final status => uncertain('status$status'),
        };
      }
      if (success == 204) {
        return finish(CommandReceipt.accepted(id: id, owner: owner));
      }
      final bytes = await Future.any<Uint8List>([
        current.readBytes(maxBytes: maxBodyBytes, inactivityTimeout: deadline),
        expired.future,
      ]);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?> ||
          decoded['data'] is! Map<String, Object?>) {
        return uncertain('malformedTurnResponse');
      }
      final data = decoded['data'] as Map<String, Object?>;
      if (operation == MutationOperation.revertStage) {
        final revert = openCodeStagedRevert(data, session, const []);
        if (revert.anchor?.message != message) {
          return uncertain('mismatchedRevert');
        }
        return finish(CommandReceipt.accepted(id: id, owner: owner), revert);
      }
      final time = data['time'];
      final created = time is Map<String, Object?> ? time['created'] : null;
      if (data['id'] != message!.value ||
          data['sessionID'] != session.nativeId ||
          data['type'] != 'compaction' ||
          data['delivery'] != 'steer' ||
          data['payload'] is! Map<String, Object?> ||
          created is! num ||
          !created.isFinite ||
          created < 0 ||
          created > 8640000000000000) {
        return uncertain('malformedCompactAdmission');
      }
      return finish(
        CommandReceipt.accepted(id: id, owner: owner, nativeRef: message.value),
      );
    } on TransportException catch (error) {
      if (timedOut) return uncertain('timeout');
      if (response == null &&
          (error.failure == TransportFailure.invalidTarget ||
              error.failure == TransportFailure.invalidRequest)) {
        payload = null;
        return unavailable(error.failure.name);
      }
      return uncertain(error.failure.name);
    } on FormatException {
      return uncertain('malformedTurnResponse');
    } on OpenCodeRevertProjectionException {
      return uncertain('malformedRevert');
    } on Object {
      return uncertain(timedOut ? 'timeout' : 'unexpectedTransportFailure');
    } finally {
      timer.cancel();
      unawaited(parent?.cancel());
      response?.cancel();
    }
  }
}

bool _messageId(String value) =>
    value.startsWith('msg_') &&
    value.length > 4 &&
    value.length <= 4096 &&
    utf8.encode(value).length <= 4096 &&
    utf8.decode(utf8.encode(value)) == value;
