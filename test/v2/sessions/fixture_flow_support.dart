import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/sessions/session_live_factory_io.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../packages/harness_opencode/test/support/fake_opencode_server.dart';
import '../../../packages/harness_opencode/test/support/fixture_replay.dart';
import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'outbox_fakes.dart';

/// Test-only rig wiring [FakeOpenCodeServer] to the REAL IO factories.
///
/// VM loopback only (`127.0.0.1`, ephemeral port). Nothing here is production
/// code: routes reuse captured 2.0.22 payload shapes, re-keyed to the rig's
/// native session id where the harness requires identity match
/// (`sessionID` on permission rows, re-keyed stream frames).
final class FixtureFlowRig {
  FixtureFlowRig._(
    this.server,
    this.fixtures,
    this.profiles,
    this.metadata,
    this.modes,
    this.payloads,
  );

  static Future<FixtureFlowRig> start({
    required FixtureScenario scenario,
  }) async {
    final fixtures = OpenCodeFixtures();
    final server = await FakeOpenCodeServer.start(
      scenario: scenario,
      fixtures: fixtures,
    );
    // Real-zone belt for widget tests: if a failed test leaves HTTP internals
    // parked in a dead fake-async zone, teardown still finishes. A request no
    // route covered (409) would otherwise let the app tolerate a silently
    // dropped read, and an SSE epoch beyond the declared streams answers a
    // tolerated 409 too, so the rig asserts that every request was admitted
    // and that no extra epoch was opened.
    addTearDown(() async {
      await server.close().timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
      final uncovered = server.observations
          .where(
            (observation) =>
                observation.kind == 'mismatch' ||
                observation.kind == 'stream-epoch-exhausted',
          )
          .length;
      if (uncovered != 0) {
        throw StateError('Fake routes did not cover $uncovered request(s).');
      }
    });
    final rig = FixtureFlowRig._(
      server,
      fixtures,
      MemoryProfiles(),
      V2MetadataStore(backend: FakeMetadataBackend()),
      PermissionModeStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      ),
      OutboxStore(),
    );
    // Default-on policy like a new install; individual tests may override.
    await rig.modes.initialize();
    return rig;
  }

  final FakeOpenCodeServer server;
  final OpenCodeFixtures fixtures;
  final MemoryProfiles profiles;
  final V2MetadataStore metadata;
  final PermissionModeStore modes;
  final OutboxStore payloads;
  int _commands = 0;

  CommandId nextCommand() => CommandId('cmd_${++_commands}');

  Future<({EndpointProfile profile, EndpointCredential credential})> addProfile(
    String id,
    String label,
  ) async {
    final profile = EndpointProfile(
      id: id,
      label: label,
      endpoint: server.endpoint,
    );
    await profiles.save(profile, server.auth.bootstrapPassword);
    final credential = await profiles.readCredential(profile);
    return (profile: profile, credential: credential!);
  }

  SessionRef ref(String profileId, String nativeId) =>
      SessionRef(HostId(profileId), HarnessInstanceId(profileId), nativeId);

  // Non-null on IO (these tests run on the VM); the stub returns null off-IO.
  SessionLiveDirectory openDirectory() => createSessionLiveDirectory(
    payloads: payloads,
    permissionModes: modes,
    commandIds: nextCommand,
  )!;
}

/// Waits for a live view predicate, like the hand-rolled directory tests.
Future<T> until<T>(Stream<T> stream, bool Function(T) test) =>
    stream.firstWhere(test).timeout(const Duration(seconds: 10));

Map<String, Object?> _doc(OpenCodeFixtures fixtures, String path) {
  final file = File('${fixtures.root.path}/$path');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// Native session id shared by the B captures reused here.
const String bSessionId = 'ses_1a10548204a0007f0a42202e750e';

/// Captured B session row, usable as-is (native id kept).
Map<String, Object?> bSessionRow(OpenCodeFixtures fixtures) {
  final calls =
      (_doc(fixtures, 'b/disconnect-reconnect.json')['calls'] as List);
  for (final call in calls) {
    final c = call as Map<String, Object?>;
    if (c['method'] == 'GET' &&
        (c['path'] as String).startsWith('/api/session/ses_')) {
      return Map<String, Object?>.from((c['response'] as Map)['data'] as Map);
    }
  }
  throw StateError('B session row not found');
}

/// Captured B message rows, oldest first, for the in-flight state: the first
/// read of the capture still shows the assistant text as empty (the streamed
/// text had not landed when that read was served).
List<Map<String, Object?>> bMessageRows(OpenCodeFixtures fixtures) {
  final calls =
      (_doc(fixtures, 'b/disconnect-reconnect.json')['calls'] as List);
  for (final call in calls) {
    final c = call as Map<String, Object?>;
    if (c['method'] == 'GET' &&
        (c['path'] as String).contains('/message?order=asc')) {
      return [
        for (final row in (c['response'] as Map)['data'] as List)
          Map<String, Object?>.from(row as Map),
      ];
    }
  }
  throw StateError('B message page not found');
}

/// Captured B message rows for the completed state: a later read of the same
/// capture observed the assistant text durably stored (the streamed marker)
/// plus the idle row. Served only by reads issued after the stream delivered
/// its text frames, mirroring the native read progression.
List<Map<String, Object?>> bCompletedMessageRows(OpenCodeFixtures fixtures) {
  final calls =
      (_doc(fixtures, 'b/disconnect-reconnect.json')['calls'] as List);
  List<Map<String, Object?>>? completed;
  for (final call in calls) {
    final c = call as Map<String, Object?>;
    if (c['method'] != 'GET' ||
        !(c['path'] as String).contains('/message?order=asc')) {
      continue;
    }
    final rows = [
      for (final row in (c['response'] as Map)['data'] as List)
        Map<String, Object?>.from(row as Map),
    ];
    final hasText = rows.any(
      (row) => jsonEncode(
        row['parts'] ?? row['content'] ?? '',
      ).contains('SP01_B_NATIVE_RECONNECT_OK'),
    );
    if (hasText) completed = rows;
  }
  if (completed == null) {
    throw StateError('B completed message page not found');
  }
  return completed;
}

/// Captured B stream frames for [key] (`partialStream` or
/// `reconnectedStream`), verbatim with real boundaries.
List<String> bStreamFrames(OpenCodeFixtures fixtures, String key) {
  final doc = _doc(fixtures, 'b/disconnect-reconnect.json');
  final frames = (doc[key] as Map)['frames'] as List;
  return [for (final frame in frames) '${(frame as List).join('\n')}\n\n'];
}

/// Captured C permission rows, re-keyed to [sessionId].
///
/// The projection synthesizes choices from `action`/`save`, so only the
/// `sessionID` needs rewriting; ids stay captured (first-reply-wins and
/// stream settlement reference them).
List<Map<String, Object?>> cPermissionRows(
  OpenCodeFixtures fixtures,
  String sessionId,
) {
  final calls = (_doc(fixtures, 'c/native-interactions.json')['calls'] as List);
  for (final call in calls) {
    final c = call as Map<String, Object?>;
    if (c['method'] == 'GET' && (c['path'] as String).endsWith('/permission')) {
      final rows = (c['response'] as Map)['data'] as List;
      if (rows.isEmpty) continue;
      return [
        for (final row in rows)
          Map<String, Object?>.from(row as Map)..['sessionID'] = sessionId,
      ];
    }
  }
  throw StateError('C permission rows not found');
}

/// Captured C `permission.asked` frames for [requestId], re-keyed to
/// [sessionId].
List<String> cPermissionAskedFrames(
  OpenCodeFixtures fixtures,
  String sessionId,
  String requestId,
) {
  final events =
      (_doc(fixtures, 'c/native-interactions.json')['events'] as List);
  final frames = <String>[];
  for (final event in events) {
    final e = event as Map<String, Object?>;
    if (e['type'] != 'permission.asked') continue;
    final data = e['data'];
    if (data is! Map<String, Object?>) continue;
    if (data['id'] != requestId) continue;
    final fixed = Map<String, Object?>.from(e)
      ..['data'] = (Map<String, Object?>.from(data)..['sessionID'] = sessionId);
    frames.add('data: ${jsonEncode(fixed)}\n\n');
  }
  if (frames.isEmpty) {
    throw StateError('C permission asked frames not found for $requestId');
  }
  return frames;
}

/// Captured C `permission.replied` frames for [requestId], re-keyed to
/// [sessionId]. Emitting these settles the matching resident request.
List<String> cPermissionRepliedFrames(
  OpenCodeFixtures fixtures,
  String sessionId,
  String requestId,
) {
  final events =
      (_doc(fixtures, 'c/native-interactions.json')['events'] as List);
  final frames = <String>[];
  for (final event in events) {
    final e = event as Map<String, Object?>;
    if (e['type'] != 'permission.replied') continue;
    final data = e['data'];
    if (data is! Map<String, Object?>) continue;
    if (data['requestID'] != requestId) continue;
    final fixed = Map<String, Object?>.from(e)
      ..['data'] = (Map<String, Object?>.from(data)..['sessionID'] = sessionId);
    frames.add('data: ${jsonEncode(fixed)}\n\n');
  }
  if (frames.isEmpty) {
    throw StateError('C permission replied frames not found for $requestId');
  }
  return frames;
}

/// Captured C form rows, re-keyed to [sessionId].
List<Map<String, Object?>> cFormRows(
  OpenCodeFixtures fixtures,
  String sessionId,
) {
  final calls = (_doc(fixtures, 'c/native-interactions.json')['calls'] as List);
  for (final call in calls) {
    final c = call as Map<String, Object?>;
    final path = c['path'] as String;
    if (c['status'] == 200 &&
        (path.endsWith('/form') || path.contains('/form/frm_'))) {
      final data = (c['response'] as Map)['data'];
      if (data is List && data.isNotEmpty) {
        return [
          for (final row in data)
            Map<String, Object?>.from(row as Map)..['sessionID'] = sessionId,
        ];
      }
      if (data is Map && (data['state'] as Map?)?['status'] == 'pending') {
        return [Map<String, Object?>.from(data)..['sessionID'] = sessionId];
      }
    }
  }
  throw StateError('C form rows not found');
}

/// Captured C `form.created` frames for [formId], re-keyed to [sessionId].
List<String> cFormCreatedFrames(
  OpenCodeFixtures fixtures,
  String sessionId,
  String formId,
) {
  final events =
      (_doc(fixtures, 'c/native-interactions.json')['events'] as List);
  final frames = <String>[];
  for (final event in events) {
    final e = event as Map<String, Object?>;
    if (e['type'] != 'form.created') continue;
    final data = e['data'];
    if (data is! Map<String, Object?>) continue;
    final form = data['form'] is Map<String, Object?>
        ? Map<String, Object?>.from(data['form'] as Map)
        : Map<String, Object?>.from(data);
    if (form['id'] != formId) continue;
    form['sessionID'] = sessionId;
    final fixed = Map<String, Object?>.from(e)
      ..['data'] = data['form'] is Map
          ? (Map<String, Object?>.from(data)..['form'] = form)
          : form;
    frames.add('data: ${jsonEncode(fixed)}\n\n');
  }
  if (frames.isEmpty) {
    throw StateError('C form created frames not found for $formId');
  }
  return frames;
}

/// Captured C `form.replied` frames for [formId], re-keyed to [sessionId].
List<String> cFormRepliedFrames(
  OpenCodeFixtures fixtures,
  String sessionId,
  String formId,
) {
  final events =
      (_doc(fixtures, 'c/native-interactions.json')['events'] as List);
  final frames = <String>[];
  for (final event in events) {
    final e = event as Map<String, Object?>;
    if (e['type'] != 'form.replied') continue;
    final data = e['data'];
    if (data is! Map<String, Object?>) continue;
    if ((data['id'] ?? data['formID']) != formId) continue;
    final fixed = Map<String, Object?>.from(e)
      ..['data'] = (Map<String, Object?>.from(data)..['sessionID'] = sessionId);
    frames.add('data: ${jsonEncode(fixed)}\n\n');
  }
  if (frames.isEmpty) {
    throw StateError('C form replied frames not found for $formId');
  }
  return frames;
}

/// Captured D `session.execution.interrupted` frame, re-keyed to [sessionId]
/// and durable sequence [seq].
String dExecutionInterruptedFrame(
  OpenCodeFixtures fixtures,
  String sessionId, {
  required int seq,
}) {
  final events =
      (_doc(fixtures, 'd/background-interrupt.json')['events'] as List);
  for (final event in events) {
    final e = event as Map<String, Object?>;
    if (e['type'] != 'session.execution.interrupted') continue;
    final data = e['data'] as Map<String, Object?>;
    final durable = e['durable'] as Map<String, Object?>;
    final fixed = Map<String, Object?>.from(e)
      ..['data'] = (Map<String, Object?>.from(data)..['sessionID'] = sessionId)
      ..['durable'] = (Map<String, Object?>.from(durable)
        ..['aggregateID'] = sessionId
        ..['seq'] = seq);
    return 'data: ${jsonEncode(fixed)}\n\n';
  }
  throw StateError('D execution interrupted frame not found');
}

/// Durable `session.model.selected` frame for [sessionId] at [seq].
String modelSelectedFrame(
  String sessionId, {
  required String providerId,
  required String modelId,
  String? variant,
  required int seq,
}) =>
    'data: ${jsonEncode({
      'id': 'evt_060cmodel$seq',
      'type': 'session.model.selected',
      'created': 1791092040000 + seq,
      'data': {
        'sessionID': sessionId,
        'model': {'providerID': providerId, 'id': modelId, 'variant': ?variant},
      },
      'durable': {'aggregateID': sessionId, 'seq': seq, 'version': 1},
    })}\n\n';

/// Durable `session.execution.started` frame for [sessionId] at [seq].
String executionStartedFrame(String sessionId, {required int seq}) =>
    'data: ${jsonEncode({
      'id': 'evt_060cstart$seq',
      'type': 'session.execution.started',
      'created': 1791092041000 + seq,
      'data': {'sessionID': sessionId},
      'durable': {'aggregateID': sessionId, 'seq': seq, 'version': 1},
    })}\n\n';

/// Durable `session.execution.failed` frame for [sessionId] at [seq].
String executionFailedFrame(
  String sessionId, {
  required String errorType,
  required String message,
  required int seq,
}) =>
    'data: ${jsonEncode({
      'id': 'evt_060cfail$seq',
      'type': 'session.execution.failed',
      'created': 1791092042000 + seq,
      'data': {
        'sessionID': sessionId,
        'error': {'type': errorType, 'message': message},
      },
      'durable': {'aggregateID': sessionId, 'seq': seq, 'version': 1},
    })}\n\n';

/// Captured interrupt acknowledgement shape (`{"interrupted": true}`).
Map<String, Object?> interruptAck(OpenCodeFixtures fixtures) {
  for (final name in [
    'd/foreground-nested-collector-diagnostic.json',
    'd/foreground-nested-collector-diagnostic-2.json',
    'd/background-interrupt.json',
  ]) {
    Map<String, Object?> doc;
    try {
      doc = _doc(fixtures, name);
    } on Object {
      continue;
    }
    final calls = doc['calls'];
    if (calls is! List) continue;
    for (final call in calls) {
      final c = call as Map<String, Object?>;
      if (c['method'] == 'POST' &&
          (c['path'] as String).endsWith('/interrupt') &&
          c['status'] == 200) {
        return Map<String, Object?>.from(c['response'] as Map);
      }
    }
  }
  throw StateError('Captured interrupt acknowledgement not found');
}

Map<String, Object?> _page(List<Object?> rows) => {
  'data': rows,
  'cursor': {'previous': null, 'next': null},
};

/// Builds a `FixtureExchange` without touching the captures on disk.
FixtureExchange _exchange({
  required String method,
  required String path,
  Object? request,
  required int status,
  Object? response,
}) => FixtureExchange.fromCapture({
  'method': method,
  'path': path,
  'request': request,
  'status': status,
  'response': response,
}, 'rig/synthetic-target');

/// Standard route set for one watched session.
///
/// [messageRows] (oldest first) back the newest-first `order=desc` hydration /
/// locate reads and the oldest-first `order=asc` history reads. Pass
/// [descRows] to serve a dynamic newest-first page instead (e.g. a promoted
/// message that only exists after a send), and/or [ascRows] for a dynamic
/// oldest-first page (e.g. durable text observed only by later reads); both
/// receive null to fall back to the static [messageRows]. [times] bounds
/// every route.
List<FixtureRoute> sessionRoutes({
  required Map<String, Object?> sessionRow,
  required List<Map<String, Object?>> messageRows,
  List<Map<String, Object?>>? Function()? descRows,
  List<Map<String, Object?>>? Function()? ascRows,
  List<Map<String, Object?>> permissionRows = const [],
  List<Map<String, Object?>> Function()? permissionRowsFn,
  List<Map<String, Object?>> formRows = const [],
  List<Map<String, Object?>> Function()? formRowsFn,
  List<Map<String, Object?>> inboxRows = const [],
  List<Map<String, Object?>> extraSessionRows = const [],
  Map<String, Object?> Function()? sessionRowFn,
  bool activeRunning = false,
  int times = 10,
}) {
  final ses = (sessionRow['id'] as String?) ?? bSessionId;
  final desc = messageRows.reversed.toList();
  final descFn = descRows;
  final directory = (sessionRow['location'] as Map?)?['directory'] as String?;
  List<Map<String, Object?>> inDirectory(List<Map<String, Object?>> rows) => [
    for (final row in rows)
      if ((row['location'] as Map?)?['directory'] == directory) row,
  ];
  // A location-scoped list: the sidebar reads who waits for the user in the
  // open group's directory, and a live session reads its model and agent
  // catalogs there.
  FixtureRoute located(String path, [List<Object?> data = const []]) =>
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: Uri(
            path: path,
            queryParameters: {'location[directory]': directory},
          ).toString(),
          status: 200,
          response: {
            'location': {'directory': directory},
            'data': data,
          },
        ),
        times: times,
      );
  return [
    if (directory != null) ...[
      located('/api/permission/request'),
      located('/api/form'),
      // The captured model row, its variant settings included; the captured
      // agent list was empty.
      located('/api/model', [_doc(OpenCodeFixtures(), 'model.json')]),
      located('/api/agent'),
    ],
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session?limit=50&order=desc',
        status: 200,
        response: _page([sessionRow, ...extraSessionRows]),
      ),
      times: times,
      respond: sessionRowFn == null
          ? null
          : (_) => _page([sessionRowFn(), ...extraSessionRows]),
    ),
    // The project the list shows reads only the sessions of its directory.
    if (directory != null)
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: Uri(
            path: '/api/session',
            queryParameters: {
              'limit': '50',
              'order': 'desc',
              'directory': directory,
            },
          ).toString(),
          status: 200,
          response: _page([sessionRow, ...inDirectory(extraSessionRows)]),
        ),
        times: times,
        respond: sessionRowFn == null
            ? null
            : (_) => _page([sessionRowFn(), ...inDirectory(extraSessionRows)]),
      ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session?parentID=$ses&limit=50',
        status: 200,
        response: _page([]),
      ),
      times: times,
    ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session/active',
        status: 200,
        response: {
          'data': activeRunning
              ? {
                  ses: {'type': 'running'},
                }
              : <String, Object?>{},
        },
      ),
      times: times,
    ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session/$ses',
        status: 200,
        response: {'data': sessionRow},
      ),
      times: times,
      respond: sessionRowFn == null ? null : (_) => {'data': sessionRowFn()},
    ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session/$ses/inbox',
        status: 200,
        response: {'data': inboxRows},
      ),
      times: times,
    ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session/$ses/message?limit=200&order=desc',
        status: 200,
        response: _page(desc),
      ),
      times: times,
      respond: descFn == null
          ? null
          : (_) {
              final custom = descFn();
              return _page(<Object?>[for (final row in custom ?? desc) row]);
            },
    ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session/$ses/message?limit=50&order=asc',
        status: 200,
        response: _page(messageRows),
      ),
      times: times,
      respond: ascRows == null
          ? null
          : (_) => _page([for (final row in ascRows() ?? messageRows) row]),
    ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session/$ses/permission',
        status: 200,
        response: {'data': permissionRows},
      ),
      times: times,
      respond: permissionRowsFn == null
          ? null
          : (_) => {'data': permissionRowsFn()},
    ),
    FixtureRoute(
      _exchange(
        method: 'GET',
        path: '/api/session/$ses/form',
        status: 200,
        response: {'data': formRows},
      ),
      times: times,
      respond: formRowsFn == null ? null : (_) => {'data': formRowsFn()},
    ),
    for (final extra in extraSessionRows) ...[
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: '/api/session?parentID=${extra['id']}&limit=50',
          status: 200,
          response: _page([]),
        ),
        times: times,
      ),
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: '/api/session/${extra['id']}',
          status: 200,
          response: {'data': extra},
        ),
        times: times,
      ),
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: '/api/session/${extra['id']}/inbox',
          status: 200,
          response: {'data': const <Object?>[]},
        ),
        times: times,
      ),
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: '/api/session/${extra['id']}/message?limit=200&order=desc',
          status: 200,
          response: _page(const []),
        ),
        times: times,
      ),
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: '/api/session/${extra['id']}/message?limit=50&order=asc',
          status: 200,
          response: _page(const []),
        ),
        times: times,
      ),
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: '/api/session/${extra['id']}/permission',
          status: 200,
          response: {'data': const <Object?>[]},
        ),
        times: times,
      ),
      FixtureRoute(
        _exchange(
          method: 'GET',
          path: '/api/session/${extra['id']}/form',
          status: 200,
          response: {'data': const <Object?>[]},
        ),
        times: times,
      ),
    ],
  ];
}

/// Admission echo: the native server confirms the client's own id, text and
/// delivery, so the response is built from the request (captured shape).
Map<String, Object?> promptAdmissionEcho(Object? request) {
  final req = request as Map<String, Object?>;
  return {
    'data': {
      'id': req['id'],
      'sessionID': (req['sessionID'] as String?) ?? bSessionId,
      'time': {'created': 1791089345000},
      'type': 'user',
      'payload': {'text': req['text']},
      'delivery': req['delivery'] ?? 'steer',
    },
  };
}
