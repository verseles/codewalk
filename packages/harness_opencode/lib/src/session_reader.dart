import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'execution_projection.dart';
import 'history_projection.dart';
import 'inbox_projection.dart';
import 'json_reads.dart';
import 'interaction_projection.dart';
import 'revert_projection.dart';
import 'session_projection.dart';
import 'session_rules.dart';
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

final _activePath = Uri(pathSegments: ['api', 'session', 'active']).toString();

/// The ids of the active map: every entry is a running drain.
Set<String> _activeSessions(Object? value) {
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
  return active.keys.toSet();
}

/// The owners of one location's pending permission requests or forms. The
/// answer names its location, which must be the one asked for. A form may be
/// owned by the endpoint's `global` sentinel, which is not a session.
Set<String> _pendingOwners(
  Object? value,
  String directory, {
  bool form = false,
}) {
  if (value is! Map<String, Object?> ||
      value['location'] is! Map<String, Object?> ||
      value['data'] is! List) {
    throw const FormatException('Malformed pending list.');
  }
  final location = value['location']! as Map<String, Object?>;
  if (location['directory'] != directory) {
    throw const FormatException('Pending list of another location.');
  }
  final rows = value['data']! as List;
  if (rows.length > _hydrationListLimit) {
    throw const FormatException('List limit.');
  }
  final owners = <String>{};
  for (final row in rows) {
    if (row is! Map<String, Object?>) {
      throw const FormatException('Malformed pending row.');
    }
    final session = row['sessionID'];
    if (form && session == 'global') continue;
    owners.add(openCodeSessionId(session));
  }
  return owners;
}

final class OpenCodeSessionReader {
  OpenCodeSessionReader(
    this.transport, {
    required this.harness,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 1024 * 1024,
    this.maxPageItems = 200,
    this.maxHistoryItems = 2000,
    this.maxCatalogBytes = 8 * 1024 * 1024,
  }) : _endpoint = transport.endpoint,
       _cursorScope = List.generate(
         4,
         (_) => Random.secure().nextInt(1 << 32),
       ).join('-') {
    if (deadline <= Duration.zero ||
        maxBodyBytes <= 0 ||
        maxPageItems <= 0 ||
        maxHistoryItems <= 0 ||
        maxCatalogBytes <= 0 ||
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

  /// A location's model list carries every model of every configured
  /// provider: an observed 2.0.22 list of 185 models took 178 KB, so the
  /// catalogs have their own bound.
  final int maxCatalogBytes;
  final Uri _endpoint;
  final String _cursorScope;
  late final _reads = OpenCodeJsonReads(
    transport,
    deadline: deadline,
    maxBodyBytes: maxBodyBytes,
    checkOpen: _checkOpen,
  );
  bool _disposed = false;

  Future<Page<SessionSummary>> listSessions(
    SessionQuery query, {
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (query.activeOnly || query.limit > maxPageItems) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.unsupportedQuery,
      );
    }
    // A project scopes the list to the sessions of exactly its directory,
    // the directory the endpoint records for each session.
    final directory = query.project?.canonicalDirectory;
    // A parent scopes the list to its direct children across its whole
    // family, whatever their directory.
    final parent = query.parent;
    if ((query.project != null && query.project!.host != harness.host) ||
        (parent != null &&
            (parent.harnessRef != harness || query.project != null))) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    if (parent != null) {
      try {
        openCodeSessionId(parent.nativeId);
      } on FormatException {
        throw const OpenCodeSessionReadException(
          OpenCodeSessionReadFailure.invalidRequest,
        );
      }
    }
    final scope = parent == null ? directory : 'parent:${parent.nativeId}';
    if (directory != null &&
        (directory.isEmpty || utf8.encode(directory).length > 4096)) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final cursor = query.cursor == null
        ? null
        : _decodeCursor(query.cursor!, scope);
    // The native cursor carries its original filters, so a continuation
    // sends the cursor and the page size only, never the order or directory.
    final path = Uri(
      path: 'api/session',
      queryParameters: {
        'limit': '${query.limit}',
        if (cursor != null)
          'cursor': cursor
        else ...{
          'order': 'desc',
          'directory': ?directory,
          'parentID': ?parent?.nativeId,
        },
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
      if (directory != null &&
          items.any(
            (row) => row.info.project?.canonicalDirectory != directory,
          )) {
        throw const FormatException('Session of another directory.');
      }
      if (parent != null &&
          items.any(
            (row) =>
                row.info.lineage.parent != parent || row.info.ref == parent,
          )) {
        throw const FormatException('Child row names another parent.');
      }
      final cursors = value['cursor'] as Map<String, Object?>;
      _nativeCursor(cursors['previous']);
      final next = _nativeCursor(cursors['next']);
      if (next != null && next == cursor) {
        throw const FormatException('Session cursor did not advance.');
      }
      return Page(
        items: items,
        nextCursor: next == null ? null : _encodeCursor(next, scope),
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

  /// The session's current model and agent, as its record carries them.
  Future<Selection> readSelection(
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
      if (projectOpenCodeSession(value['data'], harness).info.ref != ref) {
        throw const FormatException('Session response has another identity.');
      }
      return projectOpenCodeSelection(value['data']);
    }, cancellation);
  }

  /// The models one location offers: enabled ones only, each with its
  /// variant ids. Nothing else of a variant is copied, because its settings
  /// may carry provider credentials.
  Future<List<ModelEntry>> readModels(
    String directory, {
    RequestCancellation? cancellation,
  }) => _readCatalog(
    directory,
    'model',
    (row) {
      final model = _catalogObject(row);
      if (model['enabled'] is! bool) {
        throw const FormatException('Malformed model.');
      }
      if (model['enabled'] != true) return null;
      final limit = _catalogObject(model['limit']);
      final variants = model['variants'];
      if (variants is! List) throw const FormatException('Malformed model.');
      return ModelEntry(
        id: _catalogText(model['id']),
        providerId: _catalogText(model['providerID']),
        label: _catalogText(model['name'], empty: true),
        contextLimit: _catalogCount(limit['context']),
        outputLimit: _catalogCount(limit['output']),
        // An empty id cannot be named (`provider/model#variant`), so that
        // variant is not offered; the rest of the catalog still is.
        variants: [
          for (final variant in variants)
            _catalogText(_catalogObject(variant)['id'], empty: true),
        ].where((id) => id.isNotEmpty),
        cost: _catalogCost(model['cost']),
      );
    },
    (model) => '${model.providerId}/${model.id}',
    cancellation,
  );

  /// The agents a user may pick at one location: primary ones, not hidden.
  /// The others stay out of the list rather than being offered.
  Future<List<CatalogEntry>> readAgents(
    String directory, {
    RequestCancellation? cancellation,
  }) => _readCatalog(
    directory,
    'agent',
    (row) {
      final agent = _catalogObject(row);
      final mode = agent['mode'];
      final hidden = agent['hidden'];
      final description = agent['description'];
      if (mode is! String || hidden is! bool) {
        throw const FormatException('Malformed agent.');
      }
      // An agent that is not offered is not projected either.
      if (hidden || (mode != 'primary' && mode != 'all')) return null;
      return CatalogEntry(
        id: _catalogText(agent['id']),
        kind: const OpenValue.known(CatalogKind.agent),
        label: _catalogText(agent['name'], empty: true),
        description: description == null
            ? null
            : _catalogText(description, empty: true),
      );
    },
    (agent) => agent.id,
    cancellation,
  );

  /// One location's catalog list. The answer names its location, which must
  /// be the one asked for; a row the [project] function skips is not offered.
  Future<List<T>> _readCatalog<T>(
    String directory,
    String route,
    T? Function(Object? row) project,
    String Function(T entry) key,
    RequestCancellation? cancellation,
  ) async {
    _checkOpen();
    if (directory.isEmpty || utf8.encode(directory).length > 4096) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final path = Uri(
      path: 'api/$route',
      queryParameters: {'location[directory]': directory},
    ).toString();
    return _read(
      path,
      (value) {
        if (value is! Map<String, Object?> ||
            value['location'] is! Map<String, Object?> ||
            value['data'] is! List) {
          throw const FormatException('Malformed catalog.');
        }
        final location = value['location']! as Map<String, Object?>;
        if (location['directory'] != directory) {
          throw const FormatException('Catalog of another location.');
        }
        final rows = value['data']! as List;
        if (rows.length > _hydrationListLimit) {
          throw const FormatException('List limit.');
        }
        final entries = <T>[];
        final ids = <String>{};
        for (final row in rows) {
          final entry = project(row);
          if (entry == null) continue;
          if (!ids.add(key(entry))) {
            throw const FormatException('Duplicate catalog entry.');
          }
          entries.add(entry);
        }
        return List<T>.unmodifiable(entries);
      },
      cancellation,
      maxBytes: maxCatalogBytes,
    );
  }

  /// The sessions the endpoint runs now: the foreground drains its process
  /// owns. A session absent from the answer is not running.
  Future<Set<String>> readActiveSessions({RequestCancellation? cancellation}) {
    _checkOpen();
    return _read(_activePath, _activeSessions, cancellation);
  }

  /// The sessions that wait for the user at one location: the owners of its
  /// pending permission requests and forms. Both lists must answer for that
  /// same location. A form the endpoint owns itself names no session.
  Future<Set<String>> readPendingSessions(
    String directory, {
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (directory.isEmpty || utf8.encode(directory).length > 4096) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final query = {'location[directory]': directory};
    final permissions = await _read(
      Uri(path: 'api/permission/request', queryParameters: query).toString(),
      (value) => _pendingOwners(value, directory),
      cancellation,
    );
    final forms = await _read(
      Uri(path: 'api/form', queryParameters: query).toString(),
      (value) => _pendingOwners(value, directory, form: true),
      cancellation,
    );
    return {...permissions, ...forms};
  }

  /// Direct children of [parent] (sub-agent sessions), newest first page only.
  /// Upstream matches `parentID` exactly, so grandchildren never appear.
  Future<List<SessionRef>> listChildSessions(
    SessionRef parent, {
    int limit = maxChildSessions,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (parent.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    try {
      openCodeSessionId(parent.nativeId);
      if (limit < 1 || limit > min(maxChildSessions, maxPageItems)) {
        throw const FormatException();
      }
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final path = Uri(
      path: 'api/session',
      queryParameters: {'parentID': parent.nativeId, 'limit': '$limit'},
    ).toString();
    return _read(path, (value) {
      if (value is! Map<String, Object?> || value['data'] is! List) {
        throw const FormatException('Malformed OpenCode session page.');
      }
      final rows = value['data'] as List;
      if (rows.length > limit) {
        throw const FormatException('Child page exceeds its item limit.');
      }
      final children = <SessionRef>[];
      for (final row in rows) {
        final info = projectOpenCodeSession(row, harness).info;
        if (info.lineage.parent != parent || info.ref == parent) {
          throw const FormatException('Child row names another parent.');
        }
        if (children.contains(info.ref)) {
          throw const FormatException('Duplicate child session.');
        }
        children.add(info.ref);
      }
      return children;
    }, cancellation);
  }

  /// One page of children, like the official web app's session family read.
  static const maxChildSessions = 50;

  /// Reads the session's own permission rules from its info record. The
  /// identity is checked like [readSession]; an unexpected rules shape is
  /// returned as unrecognized instead of failing the read.
  Future<OpenCodeSessionRules> readSessionRules(
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
      final data = value['data'];
      final result = projectOpenCodeSession(data, harness);
      if (result.info.ref != ref) {
        throw const FormatException('Session response has another identity.');
      }
      return OpenCodeSessionRules.parse((data as Map)['permissions']);
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
          !OpenCodeCompatibility.supportsV2(sourceVersion)) {
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
      if (next == null || length < limit) {
        // Only 2.0.22 has evidence that this scan proves absence. Newer
        // histories may omit compacted turns, so retain uncertainty.
        return OpenCodeCompatibility.parse(sourceVersion)?.toString() ==
                '2.0.22'
            ? const OpenCodePromptAbsent()
            : const OpenCodePromptIncomplete();
      }
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
  /// the history page; each of [children] the map shows running becomes a
  /// running child record of the work. Inbox rows, permissions and forms map exactly like the
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
    Iterable<SessionRef> children = const [],
  }) async {
    _checkOpen();
    final childRefs = children.toList();
    if (childRefs.length > maxChildSessions * 2 ||
        childRefs.any((c) => c.harnessRef != harness || c == ref)) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
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
          !OpenCodeCompatibility.supportsV2(sourceVersion)) {
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

    final (active, activeStart, activeEnd) = await timed(
      _activePath,
      _activeSessions,
    );
    final running = active.contains(ref.nativeId);
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
        return (
          result,
          (value['data']! as Map)['revert'],
          projectOpenCodeSelection(value['data']),
        );
      },
    );
    final (summary, revert, selection) = record;
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
    // Children's pending requests join the parent's authoritative collection,
    // owned by the child with the parent as origin, so a re-hydration never
    // drops them and a request raised before connecting is still shown.
    final childPermissions = <InteractionRequest>[];
    var childEnd = formEnd;
    for (final child in childRefs) {
      try {
        final (rows, _, end) = await timed(
          Uri(
            pathSegments: ['api', 'session', child.nativeId, 'permission'],
          ).toString(),
          (value) => _projected(
            () => [
              for (final row in list(value))
                openCodePendingPermission(row, child, origin: ref),
            ],
          ),
        );
        childPermissions.addAll(rows);
        if (end.isAfter(childEnd)) childEnd = end;
      } on OpenCodeSessionReadException catch (error) {
        // Explicit cancellation halts the entire hydration. Any read failure
        // on a child (deleted, 500, timeout, malformed) is skipped so a child
        // issue never degrades or sets aside the parent session.
        if (error.failure == OpenCodeSessionReadFailure.cancelled) rethrow;
      }
    }

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
    final interactions = [...permissions, ...forms, ...childPermissions];
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
      // The record is the selection's authority; an absent field is the
      // server's default, not an unknown.
      selection: SnapshotValue(
        value: selection,
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
      // The given children the active map shows running; the parent's own
      // entry says nothing about them.
      work: SnapshotCollection(
        values: [
          for (final child in childRefs)
            if (active.contains(child.nativeId))
              openCodeRunningChild(child, ref),
        ],
        boundary: boundary('session.active', activeStart, activeEnd),
        complete: true,
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
          childEnd.isAfter(permissionEnd) ? childEnd : permissionEnd,
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
    _reads.dispose();
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
    RequestCancellation? parent, {
    int? maxBytes,
  }) => _reads.read(path, project, parent, maxBytes: maxBytes);

  /// A list cursor names its reader and the directory it pages, so it never
  /// continues another reader's list or another directory's.
  String _encodeCursor(String native, String? directory) => base64Url.encode(
    utf8.encode(
      jsonEncode({
        'version': 1,
        'scope': _cursorScope,
        'directory': ?directory,
        'native': native,
      }),
    ),
  );

  String _decodeCursor(String value, String? directory) {
    try {
      if (value.length > 32 * 1024) throw const FormatException();
      final data = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (data is! Map<String, Object?> ||
          data['version'] != 1 ||
          data['scope'] != _cursorScope ||
          data['directory'] != directory) {
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

Map<String, Object?> _catalogObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Malformed catalog row.');
  }
  return value;
}

String _catalogText(Object? value, {bool empty = false}) {
  if (value is! String ||
      (value.isEmpty && !empty) ||
      utf8.encode(value).length > 4096 ||
      utf8.decode(utf8.encode(value)) != value) {
    throw const FormatException('Malformed catalog text.');
  }
  return value;
}

/// A model's prices, or null when they cannot be read: a price is shown
/// only as stated, and an unreadable one never fails the catalog.
List<ModelCost>? _catalogCost(Object? value) {
  if (value is! List || value.length > 16) return null;
  double? money(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.toDouble() : null;
  final prices = <ModelCost>[];
  for (final row in value) {
    if (row is! Map<String, Object?>) return null;
    final cache = row['cache'];
    final tier = row['tier'];
    if (cache is! Map<String, Object?>) return null;
    final size = switch (tier) {
      null => null,
      {'type': 'context', 'size': final int size} when size >= 0 => size,
      _ => -1,
    };
    if (size == -1) return null;
    final input = money(row['input']);
    final output = money(row['output']);
    final read = money(cache['read']);
    final write = money(cache['write']);
    if (input == null || output == null || read == null || write == null) {
      return null;
    }
    prices.add(
      ModelCost(
        input: input,
        output: output,
        cacheRead: read,
        cacheWrite: write,
        contextTier: size,
      ),
    );
  }
  return prices;
}

int _catalogCount(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Malformed catalog limit.');
  }
  return value;
}
