import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'history_projection.dart';
import 'inbox_projection.dart';
import 'interaction_projection.dart';
import 'revert_projection.dart';
import 'session_projection.dart';
import 'version_policy.dart';

enum OpenCodeSessionReadFailure {
  closed,
  cancelled,
  unsupportedQuery,
  invalidScope,
  invalidCursor,
  invalidRequest,
  authenticationRequired,
  notFound,
  rateLimited,
  unavailable,
  incompatibleResponse,
  timeout,
  bodyTooLarge,
  connection,
}

/// Contains no native error message, identifier, URL, body or credential.
final class OpenCodeSessionReadException implements Exception {
  const OpenCodeSessionReadException(this.failure, {this.statusCode});

  final OpenCodeSessionReadFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'OpenCodeSessionReadException(${failure.name}'
      '${statusCode == null ? '' : ', status: $statusCode'})';
}

/// Where [OpenCodeSessionReader.locatePrompt] found one native prompt id.
sealed class OpenCodePromptLocation {
  const OpenCodePromptLocation();
}

/// Still in the inbox: admitted, not yet delivered.
final class OpenCodePromptPending extends OpenCodePromptLocation {
  const OpenCodePromptPending({required this.text, required this.delivery});
  final String text;

  /// The native delivery (`steer` or `queue`).
  final String delivery;
}

/// Promoted to history: delivered.
final class OpenCodePromptPromoted extends OpenCodePromptLocation {
  const OpenCodePromptPromoted();
}

/// The id belongs to another kind of record.
final class OpenCodePromptOccupied extends OpenCodePromptLocation {
  const OpenCodePromptOccupied();
}

/// Neither in the inbox nor anywhere in the complete history.
final class OpenCodePromptAbsent extends OpenCodePromptLocation {
  const OpenCodePromptAbsent();
}

/// Not in the inbox nor in the history pages read, but history goes on.
final class OpenCodePromptIncomplete extends OpenCodePromptLocation {
  const OpenCodePromptIncomplete();
}

/// Read-only metadata and flat history; borrows an authenticated transport.
/// Continuation tokens belong to this reader and are not durable credentials.
const _hydrationListLimit = 4096;

final class OpenCodeSessionReader {
  OpenCodeSessionReader(
    this.transport, {
    required this.harness,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 1024 * 1024,
    this.maxPageItems = 200,
    this.maxHistoryItems = 2000,
  }) : _endpoint = transport.endpoint,
       _cursorScope = List.generate(
         4,
         (_) => Random.secure().nextInt(1 << 32),
       ).join('-') {
    if (deadline <= Duration.zero ||
        maxBodyBytes <= 0 ||
        maxPageItems <= 0 ||
        maxHistoryItems <= 0 ||
        harness.host.value.isEmpty ||
        harness.harness.value.isEmpty) {
      throw ArgumentError('Session read limits must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final Duration deadline;
  final int maxBodyBytes;
  final int maxPageItems;
  final int maxHistoryItems;
  final Uri _endpoint;
  final String _cursorScope;
  final _active = <_ReadOperation>{};
  bool _disposed = false;

  Future<Page<SessionSummary>> listSessions(
    SessionQuery query, {
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (query.project != null ||
        query.activeOnly ||
        query.limit > maxPageItems) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.unsupportedQuery,
      );
    }
    final cursor = query.cursor == null ? null : _decodeCursor(query.cursor!);
    final path = Uri(
      path: 'api/session',
      queryParameters: {
        'limit': '${query.limit}',
        if (cursor == null) 'order': 'desc' else 'cursor': cursor,
      },
    ).toString();
    return _read(path, (value) {
      if (value is! Map<String, Object?> ||
          value['data'] is! List ||
          value['cursor'] is! Map<String, Object?>) {
        throw const FormatException('Malformed OpenCode session page.');
      }
      final rows = value['data'] as List;
      if (rows.length > query.limit || rows.length > maxPageItems) {
        throw const FormatException('Session page exceeds its item limit.');
      }
      final items = rows
          .map((row) => projectOpenCodeSession(row, harness))
          .toList();
      if (items.map((row) => row.info.ref).toSet().length != items.length) {
        throw const FormatException('Duplicate session in one page.');
      }
      final cursors = value['cursor'] as Map<String, Object?>;
      _nativeCursor(cursors['previous']);
      final next = _nativeCursor(cursors['next']);
      if (next != null && next == cursor) {
        throw const FormatException('Session cursor did not advance.');
      }
      return Page(
        items: items,
        nextCursor: next == null ? null : _encodeCursor(next),
      );
    }, cancellation);
  }

  Future<SessionSummary> readSession(
    SessionRef ref, {
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (ref.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    try {
      openCodeSessionId(ref.nativeId);
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final path = Uri(pathSegments: ['api', 'session', ref.nativeId]).toString();
    return _read(path, (value) {
      if (value is! Map<String, Object?>) {
        throw const FormatException('Malformed OpenCode session response.');
      }
      final result = projectOpenCodeSession(value['data'], harness);
      if (result.info.ref != ref) {
        throw const FormatException('Session response has another identity.');
      }
      return result;
    }, cancellation);
  }

  /// Reads one ascending history page without assigning causal read barriers.
  /// [sourceVersion] must be observed for this endpoint by the caller; native
  /// message count and projected-item count have independent bounds.
  Future<Page<TimelineItem>> readHistory(
    SessionRef ref, {
    required String sourceVersion,
    int limit = 50,
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (ref.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    try {
      openCodeSessionId(ref.nativeId);
      if (limit < 1 ||
          limit > min(200, maxPageItems) ||
          OpenCodeCompatibility.parse(sourceVersion) == null ||
          !OpenCodeCompatibility.assess(sourceVersion).canUse) {
        throw const FormatException();
      }
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final continuation = cursor == null
        ? null
        : _decodeHistoryCursor(cursor, ref, limit, sourceVersion);
    return _read(
      _historyPath(ref, limit, 'asc', continuation?.native),
      (value) => _historyPage(
        value,
        ref,
        limit,
        sourceVersion,
        continuation?.order ?? 'asc',
        continuation?.native,
      ),
      cancellation,
    );
  }

  /// Finds one prompt by its native id: the inbox first, then history newest
  /// first, the order hydration uses, so an input promoted between the two
  /// reads is found in history. Only a complete scan proves absence; a scan
  /// that reaches [maxHistoryPages] full pages is [OpenCodePromptIncomplete].
  ///
  /// History is in promotion order, not id order, so no id or time cutoff
  /// stops the scan early. A 2.0.22 page keeps a `next` cursor even at the
  /// end, so the end is a page shorter than its limit. Any failed read throws
  /// [OpenCodeSessionReadException]; it never reads as absence.
  Future<OpenCodePromptLocation> locatePrompt(
    SessionRef ref,
    String messageId, {
    required String sourceVersion,
    int maxHistoryPages = 5,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (ref.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    final limit = min(200, maxPageItems);
    try {
      openCodeSessionId(ref.nativeId);
      if (!messageId.startsWith('msg_') ||
          maxHistoryPages < 1 ||
          OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
        throw const FormatException();
      }
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    List<Map<String, Object?>> rows(Object? value, int max) {
      if (value is! Map<String, Object?> || value['data'] is! List) {
        throw const FormatException('Malformed list response.');
      }
      final data = value['data']! as List;
      if (data.length > max) throw const FormatException('List limit.');
      final ids = <String>{};
      return [
        for (final row in data)
          if (row is Map<String, Object?> &&
              row['id'] is String &&
              ids.add(row['id']! as String))
            row
          else
            throw const FormatException('Malformed or duplicate row.'),
      ];
    }

    // Identity only: a row of another type under this id is not ours.
    final inbox = await _read(
      Uri(pathSegments: ['api', 'session', ref.nativeId, 'inbox']).toString(),
      (value) => rows(value, _hydrationListLimit),
      cancellation,
    );
    for (final row in inbox) {
      if (row['id'] != messageId) continue;
      final payload = row['payload'];
      final text = payload is Map<String, Object?> ? payload['text'] : null;
      final delivery = row['delivery'];
      if (row['type'] != 'user' ||
          row['sessionID'] != ref.nativeId ||
          text is! String ||
          delivery is! String) {
        return const OpenCodePromptOccupied();
      }
      return OpenCodePromptPending(text: text, delivery: delivery);
    }
    String? native;
    for (var page = 0; page < maxHistoryPages; page++) {
      final (
        found,
        next,
        length,
      ) = await _read(_historyPath(ref, limit, 'desc', native), (value) {
        final data = rows(value, limit);
        final cursors = value is Map<String, Object?> ? value['cursor'] : null;
        if (cursors is! Map<String, Object?>) {
          throw const FormatException('Malformed history page.');
        }
        final next = _nativeCursor(cursors['next']);
        if (next != null && next == native) {
          throw const FormatException('History cursor did not advance.');
        }
        final match = data.where((row) => row['id'] == messageId);
        return (match.firstOrNull, next, data.length);
      }, cancellation);
      if (found != null) {
        return found['type'] == 'user'
            ? const OpenCodePromptPromoted()
            : const OpenCodePromptOccupied();
      }
      if (next == null || length < limit) return const OpenCodePromptAbsent();
      native = next;
    }
    return const OpenCodePromptIncomplete();
  }

  /// Reads the authoritative state of one open session for a hydration cycle
  /// and returns it as one [SessionSnapshot]; nothing is applied.
  ///
  /// [readStart] is the caller's stream position captured before this call;
  /// every collection keeps it with its own read times. The reads run in
  /// order — active map, session, inbox, newest history page (descending),
  /// pending permissions, pending forms — so an input promoted between the
  /// inbox and history reads is found in history. Any failure fails the whole
  /// snapshot; a successful empty list is an authoritative empty collection.
  ///
  /// A session absent from the active map is idle, with the last outcome of
  /// the history page. Inbox rows, permissions and forms map exactly like the
  /// live producers; an inbox entry whose message is already in the history
  /// page is settled there and is neither pending nor admitted again. The
  /// timeline is complete only when the page has no older continuation.
  Future<SessionSnapshot> hydrateSession(
    SessionRef ref, {
    required String hydrationGeneration,
    required StreamPosition readStart,
    required String sourceVersion,
    int historyLimit = 50,
    DateTime Function()? now,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (ref.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    try {
      openCodeSessionId(ref.nativeId);
      if (hydrationGeneration.isEmpty ||
          historyLimit < 1 ||
          historyLimit > min(200, maxPageItems) ||
          OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
        throw const FormatException();
      }
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final clock = now ?? DateTime.now;
    String sessionPath(String child) =>
        Uri(pathSegments: ['api', 'session', ref.nativeId, child]).toString();
    SnapshotBoundary boundary(
      String operation,
      DateTime started,
      DateTime completed,
    ) => SnapshotBoundary(
      owner: SessionOwner(ref),
      hydrationGeneration: hydrationGeneration,
      readStart: readStart,
      readStartedAt: started,
      readCompletedAt: completed,
      source: SourceProvenance(
        harness: harness,
        version: sourceVersion,
        nativeType: operation,
      ),
      authority: const OpenValue.known(SnapshotAuthority.authoritative),
    );
    Future<(T, DateTime, DateTime)> timed<T>(
      String path,
      T Function(Object?) project,
    ) async {
      final started = clock();
      final value = await _read(path, project, cancellation);
      final completed = clock();
      if (completed.isBefore(started)) {
        throw const OpenCodeSessionReadException(
          OpenCodeSessionReadFailure.incompatibleResponse,
        );
      }
      return (value, started, completed);
    }

    List<Object?> list(Object? value) {
      if (value is! Map<String, Object?> || value['data'] is! List) {
        throw const FormatException('Malformed list response.');
      }
      final rows = value['data']! as List;
      if (rows.length > _hydrationListLimit) {
        throw const FormatException('List limit.');
      }
      return rows.cast<Object?>();
    }

    final (running, activeStart, activeEnd) = await timed(
      Uri(pathSegments: ['api', 'session', 'active']).toString(),
      (value) {
        if (value is! Map<String, Object?> ||
            value['data'] is! Map<String, Object?>) {
          throw const FormatException('Malformed active map.');
        }
        final active = value['data']! as Map<String, Object?>;
        for (final MapEntry(:key, :value) in active.entries) {
          if (!key.startsWith('ses') ||
              value is! Map<String, Object?> ||
              value['type'] != 'running') {
            throw const FormatException('Malformed active entry.');
          }
        }
        return active.containsKey(ref.nativeId);
      },
    );
    final (record, infoStart, infoEnd) = await timed(
      Uri(pathSegments: ['api', 'session', ref.nativeId]).toString(),
      (value) {
        if (value is! Map<String, Object?>) {
          throw const FormatException('Malformed OpenCode session response.');
        }
        final result = projectOpenCodeSession(value['data'], harness);
        if (result.info.ref != ref) {
          throw const FormatException('Session response has another identity.');
        }
        // The staged revert is projected once the history page is known.
        return (result, (value['data']! as Map)['revert']);
      },
    );
    final (summary, revert) = record;
    final generation = jsonEncode([
      'hydration',
      ref.storageKey,
      hydrationGeneration,
    ]);
    final (inbox, inboxStart, inboxEnd) = await timed(
      sessionPath('inbox'),
      (value) => _projected(() {
        final ids = <Object?>{};
        return [
          for (final row in list(value))
            if (ids.add(row is Map ? row['id'] : null))
              openCodeInboxRow(
                row,
                ref,
                sourceVersion: sourceVersion,
                generation: generation,
              )
            else
              throw const FormatException('Duplicate inbox row.'),
        ];
      }),
    );
    final (page, historyStart, historyEnd) = await timed(
      _historyPath(ref, historyLimit, 'desc', null),
      (value) =>
          _historyPage(value, ref, historyLimit, sourceVersion, 'desc', null),
    );
    final (permissions, permissionStart, permissionEnd) = await timed(
      sessionPath('permission'),
      (value) => _projected(
        () => [
          for (final row in list(value)) openCodePendingPermission(row, ref),
        ],
      ),
    );
    final (forms, formStart, formEnd) = await timed(
      sessionPath('form'),
      (value) => _projected(
        () => [for (final row in list(value)) openCodePendingForm(row, ref)],
      ),
    );

    String? messageOf(ItemId id) {
      try {
        final decoded = jsonDecode(id.value);
        return decoded is List && decoded.length == 4 && decoded[1] is String
            ? decoded[1] as String
            : null;
      } on FormatException {
        return null;
      }
    }

    final promoted = {for (final item in page.items) messageOf(item.id)};
    final admissions = <TimelineItem>[];
    final pending = <PendingInput>[];
    for (final row in inbox) {
      final entry = row.pending;
      if (entry == null || promoted.contains(messageOf(entry.id))) continue;
      pending.add(entry);
      admissions.addAll(row.items);
    }
    final interactions = [...permissions, ...forms];
    final identities = {
      for (final request in interactions) request.identityKey,
    };
    if (identities.length != interactions.length) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    ExecutionOutcome? lastOutcome;
    for (final item in page.items.reversed) {
      if (item is TurnOutcome) {
        lastOutcome = ExecutionOutcome(
          OpenValue.known(switch (item.kind.known) {
            OutcomeKind.succeeded => ExecutionOutcomeKind.succeeded,
            OutcomeKind.failed => ExecutionOutcomeKind.failed,
            OutcomeKind.interrupted => ExecutionOutcomeKind.interrupted,
            null => ExecutionOutcomeKind.unknown,
          }),
        );
        break;
      }
    }
    final RevertState revertState;
    try {
      revertState = revert == null
          ? const RevertState(kind: OpenValue.known(RevertKind.none))
          : openCodeStagedRevert(revert, ref, page.items);
    } on OpenCodeRevertProjectionException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final more = page.nextCursor;
    return SessionSnapshot(
      ref: ref,
      hydrationGeneration: hydrationGeneration,
      info: SnapshotValue(
        value: summary.info,
        boundary: boundary('session.get', infoStart, infoEnd),
      ),
      execution: SnapshotValue(
        value: ExecutionState(
          kind: OpenValue.known(
            running ? ExecutionKind.running : ExecutionKind.idle,
          ),
          lastOutcome: lastOutcome,
        ),
        boundary: boundary('session.active', activeStart, activeEnd),
      ),
      timeline: SnapshotCollection(
        values: [...page.items, ...admissions],
        boundary: boundary('session.message.list', historyStart, historyEnd),
        complete: more == null,
      ),
      pending: SnapshotCollection(
        values: pending,
        boundary: boundary('session.inbox.list', inboxStart, inboxEnd),
      ),
      // One Core slot holds both reads: the earlier start and the later end.
      interactions: SnapshotCollection(
        values: interactions,
        boundary: boundary(
          'session.permission.list+session.form.list',
          formStart.isBefore(permissionStart) ? formStart : permissionStart,
          formEnd.isAfter(permissionEnd) ? formEnd : permissionEnd,
        ),
      ),
      // The session record carries the staged revert; absent means none.
      revert: SnapshotValue(
        value: revertState,
        boundary: boundary('session.get', infoStart, infoEnd),
      ),
      nextHistoryCursor: more == null ? null : HistoryCursor(more),
      hasMoreHistory: more != null,
    );
  }

  /// Producer failures carry finite categories; for a read they are an
  /// incompatible response, never a transport failure.
  T _projected<T>(T Function() project) {
    try {
      return project();
    } on OpenCodeInboxProjectionException {
      throw const FormatException('Inbox row rejected.');
    } on OpenCodeInteractionProjectionException {
      throw const FormatException('Interaction row rejected.');
    }
  }

  String _historyPath(
    SessionRef ref,
    int limit,
    String order,
    String? native,
  ) => Uri(
    pathSegments: ['api', 'session', ref.nativeId, 'message'],
    // The native API rejects an order next to a continuation cursor; the
    // cursor already encodes its direction.
    queryParameters: {
      'limit': '$limit',
      if (native == null) 'order': order else 'cursor': native,
    },
  ).toString();

  /// One page in chronological order. A descending page is reversed by native
  /// message, before projection, so one message's items stay contiguous.
  Page<TimelineItem> _historyPage(
    Object? value,
    SessionRef ref,
    int limit,
    String sourceVersion,
    String order,
    String? native,
  ) {
    if (value is! Map<String, Object?> ||
        value['data'] is! List ||
        value['cursor'] is! Map<String, Object?>) {
      throw const FormatException('Malformed history page.');
    }
    final rows = value['data'] as List;
    if (rows.length > limit) {
      throw const FormatException('History row limit.');
    }
    final cursors = value['cursor'] as Map<String, Object?>;
    _nativeCursor(cursors['previous']);
    final next = _nativeCursor(cursors['next']);
    if (next != null && next == native) {
      throw const FormatException('History cursor did not advance.');
    }
    final items = projectOpenCodeHistory(
      order == 'desc' ? rows.reversed.toList() : rows.cast<Object?>(),
      ref,
      sourceVersion: sourceVersion,
      maxItems: maxHistoryItems,
    );
    return Page<TimelineItem>(
      items: items,
      nextCursor: next == null
          ? null
          : _encodeHistoryCursor(next, ref, limit, sourceVersion, order),
    );
  }

  String _encodeHistoryCursor(
    String native,
    SessionRef ref,
    int limit,
    String sourceVersion,
    String order,
  ) {
    if (utf8.decode(utf8.encode(native)) != native) {
      throw const FormatException('Malformed history continuation.');
    }
    final encoded = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'version': 2,
          'kind': 'history',
          'scope': _cursorScope,
          'ref': ref.storageKey,
          'order': order,
          'limit': limit,
          'sourceVersion': sourceVersion,
          'native': native,
        }),
      ),
    );
    if (encoded.length > 32 * 1024) {
      throw const FormatException('History continuation exceeds its limit.');
    }
    return encoded;
  }

  ({String native, String order}) _decodeHistoryCursor(
    String value,
    SessionRef ref,
    int limit,
    String sourceVersion,
  ) {
    try {
      if (value.length > 32 * 1024) throw const FormatException();
      final data = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (data is! Map<String, Object?> ||
          data['version'] != 2 ||
          data['kind'] != 'history' ||
          data['scope'] != _cursorScope ||
          data['ref'] != ref.storageKey ||
          (data['order'] != 'asc' && data['order'] != 'desc') ||
          data['limit'] != limit ||
          data['sourceVersion'] != sourceVersion) {
        throw const FormatException();
      }
      return (
        native:
            _nativeCursor(data['native']) ?? (throw const FormatException()),
        order: data['order']! as String,
      );
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidCursor,
      );
    }
  }

  /// Disposes owned reads, never the borrowed transport or caller signal.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final operation in _active.toList()) {
      operation.stop(OpenCodeSessionReadFailure.closed);
    }
  }

  void _checkOpen() {
    if (_disposed || transport.isClosed) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.closed,
      );
    }
    if (transport.endpoint != _endpoint) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
  }

  Future<T> _read<T>(
    String path,
    T Function(Object?) project,
    RequestCancellation? parent,
  ) async {
    if (parent?.isCancelled ?? false) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.cancelled,
      );
    }
    final operation = _ReadOperation(deadline);
    _active.add(operation);
    final subscription = parent?.onCancel.listen(
      (_) => operation.stop(OpenCodeSessionReadFailure.cancelled),
    );
    T result;
    try {
      result = await Future.any([
        _collect(path, project, operation),
        operation.stopped.future.then<T>((_) => throw operation.failure!),
      ]);
    } on OpenCodeSessionReadException {
      rethrow;
    } on TransportException catch (error) {
      throw _transportError(error);
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    } on Object {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.connection,
      );
    } finally {
      operation.finish();
      _active.remove(operation);
      await subscription?.cancel();
    }
    _checkOpen();
    if (operation.cleanupFailed) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.connection,
      );
    }
    if (parent?.isCancelled ?? false) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.cancelled,
      );
    }
    if (operation.clock.elapsed >= deadline) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.timeout,
      );
    }
    return result;
  }

  Future<T> _collect<T>(
    String path,
    T Function(Object?) project,
    _ReadOperation operation,
  ) async {
    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        path: path,
        headers: const {'Accept': 'application/json'},
      ),
      cancellation: operation.cancellation,
    );
    if (operation.finished || operation.failure != null) {
      operation.cancelResponse(response);
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.cancelled,
      );
    }
    operation.response = response;
    if (response.statusCode != 200) throw _statusError(response.statusCode);
    final media = response
        .header('content-type')
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (media != 'application/json' &&
        !(media?.startsWith('application/') == true &&
            media!.endsWith('+json'))) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final bytes = await response.readBytes(
      maxBytes: maxBodyBytes,
      inactivityTimeout: deadline,
    );
    if (operation.failure != null) throw operation.failure!;
    _checkOpen();
    if (operation.clock.elapsed >= deadline) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.timeout,
      );
    }
    return project(jsonDecode(utf8.decode(bytes)));
  }

  String _encodeCursor(String native) => base64Url.encode(
    utf8.encode(
      jsonEncode({'version': 1, 'scope': _cursorScope, 'native': native}),
    ),
  );

  String _decodeCursor(String value) {
    try {
      if (value.length > 32 * 1024) throw const FormatException();
      final data = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (data is! Map<String, Object?> ||
          data['version'] != 1 ||
          data['scope'] != _cursorScope) {
        throw const FormatException();
      }
      return _nativeCursor(data['native']) ?? (throw const FormatException());
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidCursor,
      );
    }
  }

  String? _nativeCursor(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        value.isEmpty ||
        utf8.encode(value).length > 16 * 1024) {
      throw const FormatException('Malformed OpenCode cursor.');
    }
    return value;
  }
}

final class _ReadOperation {
  _ReadOperation(Duration deadline) {
    timer = Timer(deadline, () => stop(OpenCodeSessionReadFailure.timeout));
  }

  final clock = Stopwatch()..start();
  final cancellation = RequestCancellation();
  final stopped = Completer<void>();
  late final Timer timer;
  TransportResponse? response;
  OpenCodeSessionReadException? failure;
  bool finished = false;
  bool cleanupFailed = false;

  void stop(OpenCodeSessionReadFailure reason) {
    if (finished || failure != null) return;
    failure = OpenCodeSessionReadException(reason);
    stopped.complete();
    cancellation.cancel();
    cancelResponse(response);
  }

  void finish() {
    finished = true;
    timer.cancel();
    cancellation.cancel();
    cancelResponse(response);
  }

  void cancelResponse(TransportResponse? value) {
    try {
      value?.cancel();
    } on Object {
      // A late response cannot replace an already reported cancellation.
      cleanupFailed = true;
    }
  }
}

OpenCodeSessionReadException _statusError(int status) =>
    OpenCodeSessionReadException(switch (status) {
      400 => OpenCodeSessionReadFailure.invalidRequest,
      401 || 403 => OpenCodeSessionReadFailure.authenticationRequired,
      404 => OpenCodeSessionReadFailure.notFound,
      408 => OpenCodeSessionReadFailure.timeout,
      429 => OpenCodeSessionReadFailure.rateLimited,
      500 || 502 || 503 || 504 => OpenCodeSessionReadFailure.unavailable,
      _ => OpenCodeSessionReadFailure.incompatibleResponse,
    }, statusCode: status);

OpenCodeSessionReadException _transportError(TransportException error) =>
    OpenCodeSessionReadException(switch (error.failure) {
      TransportFailure.closed => OpenCodeSessionReadFailure.closed,
      TransportFailure.cancelled => OpenCodeSessionReadFailure.cancelled,
      TransportFailure.timeout => OpenCodeSessionReadFailure.timeout,
      TransportFailure.bodyTooLarge => OpenCodeSessionReadFailure.bodyTooLarge,
      TransportFailure.invalidTarget || TransportFailure.invalidRequest =>
        OpenCodeSessionReadFailure.invalidRequest,
      _ => OpenCodeSessionReadFailure.connection,
    }, statusCode: error.statusCode);
