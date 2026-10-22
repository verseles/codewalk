import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'session_projection.dart';
import 'version_policy.dart';

/// The outcome of one session lifecycle command.
///
/// The receipt admits the exchange: it says the endpoint answered with this
/// command's success status for this exact request. It never proves the
/// effect, which is server-side and is observed later by the endpoint's
/// stream or by an authoritative re-read.
final class OpenCodeSessionLifecycleAttempt {
  const OpenCodeSessionLifecycleAttempt({
    required this.command,
    required this.receipt,
    this.payload,
    this.session,
  });

  /// The immutable canonical intent of the command.
  final OriginalCommand command;

  /// The receipt of the exchange.
  final CommandReceipt receipt;

  /// The exact JSON body handed to the transport, when bytes were sent.
  final String? payload;

  /// The session the endpoint returned, for the commands whose contract
  /// answers with one.
  final SessionSummary? session;
}

/// The bound of an identifier or a path the client sends to the endpoint.
const _idLimit = 4096;

/// The bound of a title the client sends to the endpoint. It matches the
/// title the lifecycle projection accepts, so the client never sends a title
/// the projection would later reject.
const _titleLimit = 256 * 1024;

/// An absolute path: a POSIX root or a Windows drive.
bool _absolutePath(String value) =>
    value.startsWith('/') ||
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);

bool _boundedText(String value, int bytes) =>
    value.length <= bytes &&
    utf8.encode(value).length <= bytes &&
    utf8.decode(utf8.encode(value)) == value;

/// Sends the official 2.0.22 session lifecycle and selection commands.
///
/// The commands share the transport, the connected version, the deadline,
/// the body bound, the ownership assertion, the command and receipt
/// construction and one status vocabulary, so they share one client. The
/// client never retries, replays, persists or updates the catalog, and it
/// never mints a session identifier: a create carries the caller's identifier
/// or omits the key and lets the endpoint mint it.
final class OpenCodeSessionLifecycleClient {
  OpenCodeSessionLifecycleClient(
    this.transport, {
    required this.harness,
    required this.connectedVersion,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 1024 * 1024,
  }) {
    if (deadline <= Duration.zero || maxBodyBytes <= 0) {
      throw ArgumentError('Session command bounds must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final String connectedVersion;
  final Duration deadline;

  /// The bound of the response the endpoint answers with. A create and a
  /// fork answer with a whole session record, not with a small receipt.
  final int maxBodyBytes;

  /// Creates a session at the given directory.
  ///
  /// The directory always travels in the body: the endpoint ignores the
  /// directory header on this route and falls back to the server process
  /// directory, which is the user's home under the background service.
  Future<OpenCodeSessionLifecycleAttempt> create({
    required CommandId id,
    required String directory,
    String? nativeSessionId,
    String? title,
    RequestCancellation? cancellation,
  })async {
    if (nativeSessionId != null) {
      try {
        openCodeSessionId(nativeSessionId);
      } on FormatException {
        throw ArgumentError(
          'Not a native session identifier',
          'nativeSessionId',
        );
      }
    }
    if (directory.isEmpty || !_boundedText(directory, _idLimit)) {
      throw ArgumentError('The create body carries a bounded directory');
    }
    if (!_absolutePath(directory)) {
      // A relative path would be resolved against the endpoint's process
      // directory, which is the user's home under the background service.
      throw ArgumentError('The create body carries an absolute directory');
    }
    if (title != null && !_boundedText(title, _titleLimit)) {
      throw ArgumentError('The create body carries a bounded title');
    }
    final owner = ProjectOwner(
      ProjectRef(harness.host, directory),
      harness: harness,
    );
    // The optional keys are omitted, not set to null: the endpoint tells an
    // absent key from a null one.
    final body = <String, Object?>{'location': {'directory': directory}};
    if (nativeSessionId != null) body['id'] = nativeSessionId;
    if (title != null) body['title'] = title;
    return _send(
      id: id,
      operation: MutationOperation.create,
      owner: owner,
      intent: CanonicalValue(body),
      method: 'POST',
      pathSegments: const ['api', 'session'],
      body: body,
      expectedStatus: 200,
      notFoundType: 'NotFoundError',
      // A create with the caller's identifier may return the session that
      // identifier already owns, with the new fields ignored.
      occupiedTitle: nativeSessionId == null ? null : title,
      occupiedDirectory: nativeSessionId == null ? null : directory,
      occupiedNativeId: nativeSessionId,
      cancellation: cancellation,
    );
  }

  /// Replaces the session's title.
  Future<OpenCodeSessionLifecycleAttempt> rename({
    required SessionRef session,
    required CommandId id,
    required String title,
    RequestCancellation? cancellation,
  })async {
    if (!_boundedText(title, _titleLimit)) {
      throw ArgumentError('The rename body carries a bounded title');
    }
    return _send(
      id: id,
      operation: MutationOperation.rename,
    owner: SessionOwner(session),
    intent: CanonicalValue({
      'sessionID': session.nativeId,
      'title': title,
    }),
      method: 'PATCH',
      pathSegments: ['api', 'session', session.nativeId],
      body: {'title': title},
      expectedStatus: 204,
      session: session,
      cancellation: cancellation,
    );
  }

  /// Deletes the session and its child sessions.
  ///
  /// The endpoint interrupts the execution and deletes the children, and it
  /// emits `session.deleted` per session; the receipt does not prove that the
  /// cascade settled.
  Future<OpenCodeSessionLifecycleAttempt> delete({
    required SessionRef session,
    required CommandId id,
    RequestCancellation? cancellation,
  }) async => _send(
    id: id,
    operation: MutationOperation.delete,
    owner: SessionOwner(session),
    intent: CanonicalValue({'sessionID': session.nativeId}),
    method: 'DELETE',
    pathSegments: ['api', 'session', session.nativeId],
    body: null,
    expectedStatus: 204,
    session: session,
    cancellation: cancellation,
  );

  /// Copies the session's history into a new root session.
  ///
  /// Without a boundary the whole history is copied. The endpoint answers
  /// with the new session and emits `session.forked`, not `session.created`.
  Future<OpenCodeSessionLifecycleAttempt> fork({
    required SessionRef session,
    required CommandId id,
    String? before,
    RequestCancellation? cancellation,
  })async {
    if (before != null &&
        (!before.startsWith('msg_') || !_boundedText(before, _idLimit))) {
      throw ArgumentError('The fork body carries a bounded message boundary');
    }
    final body = <String, Object?>{};
    if (before != null) body['before'] = before;
    final intent = <String, Object?>{'sessionID': session.nativeId};
    if (before != null) intent['before'] = before;
    return _send(
      id: id,
      operation: MutationOperation.fork,
      owner: SessionOwner(session),
      intent: CanonicalValue(intent),
      method: 'POST',
      pathSegments: ['api', 'session', session.nativeId, 'fork'],
      body: body,
      expectedStatus: 200,
      notFoundType: 'NotFoundError',
      session: session,
      cancellation: cancellation,
    );
  }

  /// Marks the observed idle transition of the session as viewed.
  Future<OpenCodeSessionLifecycleAttempt> markViewed({
    required SessionRef session,
    required CommandId id,
    required int idle,
    RequestCancellation? cancellation,
  }) async => _send(
    id: id,
    operation: MutationOperation.markViewed,
    owner: SessionOwner(session),
    intent: CanonicalValue({
      'sessionID': session.nativeId,
      'idle': idle,
    }),
    method: 'POST',
    pathSegments: ['api', 'session', session.nativeId, 'view'],
    body: {'idle': idle},
    expectedStatus: 204,
    session: session,
    cancellation: cancellation,
  );

  /// Switches the model of the session's next provider turns: the whole
  /// reference, so a reference without a variant clears it.
  ///
  /// The endpoint emits `session.model.selected`. The receipt never proves the
  /// selection, and an uncertain one must not be repeated: the session's
  /// record decides it, because another switch may have landed since.
  Future<OpenCodeSessionLifecycleAttempt> selectModel({
    required SessionRef session,
    required CommandId id,
    required String modelId,
    required String providerId,
    String? variant,
    RequestCancellation? cancellation,
  }) async {
    _checkSelection(session, [modelId, providerId]);
    if (variant != null && !_boundedText(variant, _idLimit)) {
      throw ArgumentError('The model reference carries a bounded variant');
    }
    final model = <String, Object?>{
      'id': modelId,
      'providerID': providerId,
      'variant': ?variant,
    };
    return _send(
      id: id,
      operation: MutationOperation.selection,
      owner: SessionOwner(session),
      intent: CanonicalValue({'sessionID': session.nativeId, 'model': model}),
      method: 'POST',
      pathSegments: ['api', 'session', session.nativeId, 'model'],
      body: {'model': model},
      expectedStatus: 204,
      session: session,
      cancellation: cancellation,
    );
  }

  /// Switches the agent of the session's next provider turns.
  ///
  /// The endpoint emits `session.agent.selected`; an uncertain receipt is
  /// settled by the session's record, never by repeating the switch.
  Future<OpenCodeSessionLifecycleAttempt> selectAgent({
    required SessionRef session,
    required CommandId id,
    required String agentId,
    RequestCancellation? cancellation,
  }) async {
    _checkSelection(session, [agentId]);
    return _send(
      id: id,
      operation: MutationOperation.selection,
      owner: SessionOwner(session),
      intent: CanonicalValue({'sessionID': session.nativeId, 'agent': agentId}),
      method: 'POST',
      pathSegments: ['api', 'session', session.nativeId, 'agent'],
      body: {'agent': agentId},
      expectedStatus: 204,
      session: session,
      cancellation: cancellation,
    );
  }

  /// A selection names one session of this harness and nonempty bounded ids.
  void _checkSelection(SessionRef session, List<String> ids) {
    if (session.harnessRef != harness) {
      throw ArgumentError('Session belongs to another harness.');
    }
    for (final id in ids) {
      if (id.isEmpty || !_boundedText(id, _idLimit)) {
        throw ArgumentError('The selection carries bounded ids');
      }
    }
  }

  Future<OpenCodeSessionLifecycleAttempt> _send({
    required CommandId id,
    required MutationOperation operation,
    required DomainOwner owner,
    required CanonicalValue intent,
    required String method,
    required List<String> pathSegments,
    required Map<String, Object?>? body,
    required int expectedStatus,
    String notFoundType = 'SessionNotFoundError',
    String? occupiedTitle,
    String? occupiedDirectory,
    String? occupiedNativeId,
    SessionRef? session,
    RequestCancellation? cancellation,
  }) async {
    final command = OriginalCommand(
      id: id,
      harness: harness,
      owner: owner,
      operation: OpenValue.known(operation),
      connectedVersion: connectedVersion,
      intent: intent,
    );
    // The exact body is kept once it was handed to the transport, so a
    // refusal or an uncertainty can still be reconciled against it.
    String? sentPayload;
    OpenCodeSessionLifecycleAttempt finish(
      CommandReceipt receipt, {
      SessionSummary? summary,
    }) => OpenCodeSessionLifecycleAttempt(
      command: command,
      receipt: receipt,
      payload: sentPayload,
      session: summary,
    );
    OpenCodeSessionLifecycleAttempt unavailable(String reason) => finish(
      CommandReceipt.unavailable(
        id: id,
        owner: owner,
        unavailable: CapabilityUnavailable(operation.name, reason: reason),
      ),
    );
    OpenCodeSessionLifecycleAttempt uncertain(String reason) => finish(
      CommandReceipt.uncertain(id: id, owner: owner, reason: reason),
    );
    OpenCodeSessionLifecycleAttempt rejected(
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

    // Only the observed 2.0.22 semantics are relied on.
    if (OpenCodeCompatibility.parse(connectedVersion)?.toString() != '2.0.22') {
      return unavailable('unverifiedVersion');
    }
    if (session != null) {
      try {
        openCodeSessionId(session.nativeId);
      } on FormatException {
        return unavailable('invalidSession');
      }
    }
    if (cancellation?.isCancelled ?? false) {
      return unavailable('cancelledBeforeSend');
    }
    if (transport.isClosed) return unavailable('closed');

    final payload = body == null ? null : jsonEncode(body);
    final payloadBytes = payload == null ? null : utf8.encode(payload);
    sentPayload = payload;
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
          method: method,
          path: Uri(pathSegments: pathSegments).toString(),
          headers: {
            'Accept': 'application/json',
            if (body != null) 'Content-Type': 'application/json',
          },
          body: payloadBytes,
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
      // A refusal is known from the status; the native body is never read,
      // because its messages echo identifiers and paths.
      final status = current.statusCode;
      if (status != expectedStatus) {
        return switch (status) {
          400 => rejected(ErrorKind.protocol, 'InvalidRequestError'),
          401 || 403 => rejected(
            ErrorKind.auth,
            'UnauthorizedError',
            action: ErrorAction.authenticate,
          ),
          404 => rejected(
            ErrorKind.protocol,
            notFoundType,
            action: ErrorAction.refresh,
          ),
          429 => rejected(ErrorKind.rateLimit, 'RateLimited', retryable: true),
          final other => uncertain('status$other'),
        };
      }
      final expectsSession = expectedStatus == 200;
      if (!expectsSession) {
        // A 204 with no body: the exchange was admitted.
        return finish(
          CommandReceipt.accepted(
            id: id,
            owner: owner,
            nativeRef: session?.nativeId,
          ),
        );
      }
      final bytes = await Future.any<Uint8List>([
        current.readBytes(maxBytes: maxBodyBytes, inactivityTimeout: deadline),
        expired.future,
      ]);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?> ||
          decoded['data'] is! Map<String, Object?>) {
        return uncertain('malformedSession');
      }
      final summary = projectOpenCodeSession(decoded['data'], harness);
      // A create with the caller's identifier answers with the session that
      // identifier already owns and ignores the changed fields, so a response
      // that does not match the intent is not the session the caller asked
      // for.
      if (occupiedNativeId != null &&
          summary.info.ref.nativeId != occupiedNativeId) {
        return rejected(
          ErrorKind.protocol,
          'SessionIdentityOccupied',
          action: ErrorAction.refresh,
        );
      }
      if (occupiedTitle != null && summary.info.title != occupiedTitle) {
        return rejected(
          ErrorKind.protocol,
          'SessionIdentityOccupied',
          action: ErrorAction.refresh,
        );
      }
      if (occupiedDirectory != null &&
          summary.info.project?.canonicalDirectory != occupiedDirectory) {
        return rejected(
          ErrorKind.protocol,
          'SessionIdentityOccupied',
          action: ErrorAction.refresh,
        );
      }
      return finish(
        CommandReceipt.accepted(
          id: id,
          owner: owner,
          nativeRef: summary.info.ref.nativeId,
        ),
        summary: summary,
      );
    } on TransportException catch (error) {
      if (timedOut) return uncertain('timeout');
      if (response == null &&
          (error.failure == TransportFailure.invalidTarget ||
              error.failure == TransportFailure.invalidRequest)) {
        // The transport refused the request itself, so nothing was sent.
        sentPayload = null;
        return unavailable(error.failure.name);
      }
      return uncertain(error.failure.name);
    } on FormatException {
      return uncertain('malformedSession');
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
