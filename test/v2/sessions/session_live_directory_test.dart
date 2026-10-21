@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/sessions/session_live_factory_io.dart';
import 'package:codewalk/platform/sessions/unrestricted_ownership_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_permission_reply.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk/shared/sessions/session_unrestricted.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../storage/storage_fakes.dart';
import 'outbox_fakes.dart';

/// A loopback OpenCode 2.0.22 stand-in: probe, one event stream per
/// connection and the hydration reads. It records every request path.
final class _Server {
  _Server._(this._server) {
    _server.listen(_handle);
  }
  static Future<_Server> start() async =>
      _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  final HttpServer _server;
  String version = '2.0.22';
  int? eventStatus;
  final paths = <String>[];
  final streams = <HttpResponse>[];
  final methods = <String>{};
  final prompts = <String>[];
  final replies = <String>[];
  final permissions = <Object?>[];
  int replyStatus = 204;

  /// The older-history cursor the newest page offers; null for none.
  String? olderCursor;

  /// Holds a continuation read until completed.
  Completer<void>? holdOlder;

  /// Session rules by session id; absent means never set.
  final sessionRules = <String, List<Object?>>{};
  final patches = <String>[];
  int patchStatus = 204;

  /// Whether a PATCH is stored even when its status says otherwise.
  bool? patchApplies;

  /// Child session ids by parent id, served on `GET /api/session?parentID=`.
  final children = <String, List<String>>{};

  /// 1-based indices of `GET /api/session/<id>` reads answered with 500.
  final failSessionReads = <int>{};
  int sessionReads = 0;
  final running = <String>{};
  bool includePreviousOutcome = false;
  final interrupts = <Uri>[];
  final firstInterrupt = Completer<void>();
  Completer<void>? holdInterrupt;
  Object? interruptBody = const {'interrupted': true};
  int interruptStatus = 200;
  int _seq = 0;
  int get port => _server.port;
  int get events => paths.where((p) => p == '/proxy/api/event').length;

  Future<void> _handle(HttpRequest r) async {
    methods.add(r.method);
    expect(
      r.headers.value('authorization'),
      'Basic ${base64Encode(utf8.encode('opencode:fake-secret'))}',
    );
    paths.add(r.uri.path);
    final segments = r.uri.pathSegments;
    if (r.uri.path == '/proxy/api/event' && eventStatus != null) {
      r.response.statusCode = eventStatus!;
      await r.response.close();
      return;
    }
    if (r.uri.path == '/proxy/api/event') {
      r.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      r.response.bufferOutput = false;
      streams.add(r.response);
      r.response.write('data: ${jsonEncode({'type': 'server.connected'})}\n\n');
      await r.response.flush();
      return;
    }
    r.response.headers.contentType = ContentType.json;
    final tail = segments.last;
    if (r.method == 'POST' && tail == 'interrupt') {
      interrupts.add(r.uri);
      if (!firstInterrupt.isCompleted) firstInterrupt.complete();
      expect(await utf8.decoder.bind(r).join(), isEmpty);
      expect(r.uri.hasQuery, isFalse);
      await holdInterrupt?.future;
      r.response.statusCode = interruptStatus;
      r.response.write(jsonEncode(interruptBody));
      await r.response.close();
      return;
    }
    if (r.method == 'POST' && tail == 'reply') {
      replies.add(await utf8.decoder.bind(r).join());
      r.response.statusCode = replyStatus;
      await r.response.close();
      return;
    }
    if (r.method == 'PATCH' && segments.length == 4) {
      final body = await utf8.decoder.bind(r).join();
      patches.add(body);
      if (patchApplies ?? patchStatus == 204) {
        final decoded = jsonDecode(body) as Map<String, Object?>;
        sessionRules[segments[3]] = (decoded['permissions']! as List).toList();
      }
      r.response.statusCode = patchStatus;
      await r.response.close();
      return;
    }
    if (r.method == 'POST' && tail == 'prompt') {
      prompts.add(await utf8.decoder.bind(r).join());
      final body = jsonDecode(prompts.last) as Map<String, Object?>;
      r.response.write(
        jsonEncode({
          'data': {
            'id': body['id'],
            'sessionID': segments[3],
            'time': {'created': 1},
            'type': 'user',
            'payload': {'text': body['text']},
            'delivery': body['delivery'],
          },
        }),
      );
      await r.response.close();
      return;
    }
    if (r.method == 'GET' &&
        tail == 'session' &&
        r.uri.queryParameters.containsKey('parentID')) {
      final parent = r.uri.queryParameters['parentID']!;
      r.response.write(
        jsonEncode({
          'data': [
            for (final child in children[parent] ?? const <String>[])
              {
                'id': child,
                'parentID': parent,
                'title': 'Child $child',
                'projectID': 'prj_a',
                'location': {'directory': '/workspace'},
                'time': {'created': 1, 'updated': 2},
              },
          ],
          'cursor': <String, Object?>{},
        }),
      );
      await r.response.close();
      return;
    }
    final session = segments.length > 3 ? segments[3] : 'ses_one';
    if (r.method == 'GET' && segments.length == 4 && tail == session) {
      if (failSessionReads.contains(++sessionReads)) {
        r.response.statusCode = 500;
        await r.response.close();
        return;
      }
    }
    if (tail == 'message' && r.uri.queryParameters.containsKey('cursor')) {
      await holdOlder?.future;
    }
    r.response.write(
      jsonEncode(switch (tail) {
        'info' => {
          'version': version,
          'pid': 1,
          'urls': [],
          'paths': {'tmp': '/tmp'},
        },
        'active' => {
          'data': {
            for (final id in running) id: {'type': 'running'},
          },
        },
        'inbox' || 'form' => {'data': <Object?>[]},
        'permission' => {
          'data': [
            for (final permission in permissions)
              if ((permission! as Map)['sessionID'] == session) permission,
          ],
        },
        'message' when r.uri.queryParameters.containsKey('cursor') => {
          'data': [
            {
              'id': 'msg_old',
              'type': 'user',
              'time': {'created': 100},
              'text': 'older',
            },
          ],
          'cursor': {'previous': null, 'next': null},
        },
        'message' => {
          'data': [
            {
              'id': 'msg_1',
              'type': 'user',
              'time': {'created': 1000},
              'text': 'hello from $session',
            },
            if (includePreviousOutcome)
              {
                'id': 'msg_0',
                'type': 'idle',
                'time': {'created': 500},
                'outcome': 'succeeded',
              },
          ],
          'cursor': {'previous': null, 'next': olderCursor},
        },
        _ => {
          'data': {
            'id': session,
            for (final entry in children.entries)
              if (entry.value.contains(session)) 'parentID': entry.key,
            'title': 'Session',
            'projectID': 'prj_a',
            'location': {'directory': '/workspace'},
            'time': {'created': 1, 'updated': 2},
            'permissions': ?sessionRules[session],
          },
        },
      }),
    );
    await r.response.close();
  }

  /// Sends one ephemeral frame of [type] with [data] to every open stream.
  Future<void> emit(String type, Map<String, Object?> data) async {
    final seq = ++_seq;
    final frame = {
      'id': 'evt_x$seq',
      'type': type,
      'created': 1000 + seq,
      'data': data,
    };
    for (final stream in streams) {
      stream.write('data: ${jsonEncode(frame)}\n\n');
      await stream.flush();
    }
  }

  Future<void> execution(String session, String type, {String? reason}) async {
    final seq = ++_seq;
    if (type == 'started') {
      running.add(session);
    } else {
      running.remove(session);
    }
    final frame = {
      'id': 'evt_$seq',
      'type': 'session.execution.$type',
      'created': 1000 + seq,
      'durable': {'aggregateID': session, 'version': 1, 'seq': seq},
      'data': {'sessionID': session, 'reason': ?reason},
    };
    for (final stream in streams) {
      stream.write('data: ${jsonEncode(frame)}\n\n');
      await stream.flush();
    }
  }

  Future<void> close() async {
    for (final stream in streams) {
      unawaited(stream.close().catchError((_) {}));
    }
    await _server.close(force: true);
  }
}

void main() {
  late _Server server;
  late EndpointProfile p;
  final credential = EndpointCredential(
    kind: EndpointAuthKind.password,
    secret: 'fake-secret',
  );
  SessionRef ref(String id) =>
      SessionRef(HostId(p.id), HarnessInstanceId(p.id), id);
  Future<SessionLiveView> until(
    SessionLiveHandle handle,
    bool Function(SessionLiveView) test,
  ) => handle.updates.firstWhere(test).timeout(const Duration(seconds: 10));

  setUp(() async {
    server = await _Server.start();
    p = EndpointProfile(
      id: 'profile_one',
      label: 'One',
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/proxy/'),
    );
  });
  tearDown(() => server.close());

  test(
    'Stop shares a fence across leases, same credential/prefix, no ledger',
    () async {
      server.running.add('ses_one');
      server.holdInterrupt = Completer();
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final b = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(a, (_) => a.canStop);
      expect(a.outbox, isNull);
      final pending = a.stop(id: const CommandId('first'));
      await b.stop(id: const CommandId('second'));
      expect(b.stopState.busy, isTrue);
      await server.firstInterrupt.future.timeout(const Duration(seconds: 10));
      expect(
        server.interrupts.single.path,
        '/proxy/api/session/ses_one/interrupt',
      );
      server.holdInterrupt!.complete();
      await pending;
      expect(b.stopState.phase, SessionStopPhase.requested);
      expect(a.current.state?.execution?.kind.known, ExecutionKind.running);
      await b.stop(id: const CommandId('third'));
      expect(server.interrupts, hasLength(1));
      await server.execution('ses_one', 'interrupted', reason: 'user');
      await until(
        a,
        (v) => v.state?.execution?.kind.known == ExecutionKind.idle,
      );
      expect(b.stopState.busy, isFalse);
      expect(
        a.current.state!.timeline.whereType<TurnOutcome>().single.kind.known,
        OutcomeKind.interrupted,
      );
      expect(server.events, 1);
      a.close();
      b.close();
      await b.stop(id: const CommandId('closed'));
      expect(server.interrupts, hasLength(1));
    },
  );

  test(
    'terminal and successor before HTTP answer do not restore a stop wait',
    () async {
      server.running.add('ses_one');
      server.holdInterrupt = Completer();
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(a, (_) => a.canStop);
      final pending = a.stop(id: const CommandId('first'));
      await server.firstInterrupt.future.timeout(const Duration(seconds: 10));
      await server.execution('ses_one', 'interrupted', reason: 'user');
      await until(
        a,
        (v) => v.state?.execution?.kind.known == ExecutionKind.idle,
      );
      await server.execution('ses_one', 'started');
      await until(
        a,
        (v) => v.state?.execution?.kind.known == ExecutionKind.running,
      );
      expect(a.canStop, isFalse, reason: 'HTTP attempt is still in flight');
      server.holdInterrupt!.complete();
      await pending;
      expect(a.stopState.busy, isFalse);
      expect(a.canStop, isTrue);
      expect(server.interrupts, hasLength(1));
    },
  );

  test(
    'an older page read when its last lease closed leaves no closed view',
    () async {
      server.olderCursor = 'older-1';
      server.holdOlder = Completer();
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      // Another session keeps the profile's stream open.
      final keep = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final lease = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_two'),
      );
      await until(lease, (_) => lease.canLoadOlderHistory);
      final reading = lease.loadOlderHistory();
      expect(lease.olderHistory.loading, isTrue);
      lease.close();
      server.holdOlder!.complete();
      await reading;
      final reopened = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_two'),
      );
      expect(reopened.current.phase, isNot(SessionLivePhase.closed));
      expect(reopened.olderHistory.loading, isFalse);
      expect(reopened.olderHistory.failure, isNull);
      reopened.close();
      keep.close();
    },
  );

  test('reconnect hydration cannot settle a still-running Stop', () async {
    server.running.add('ses_one');
    server.includePreviousOutcome = true;
    final directory = createSessionLiveDirectory()!;
    addTearDown(directory.close);
    final a = await directory.open(
      profile: p,
      credential: credential,
      session: ref('ses_one'),
    );
    await until(a, (_) => a.canStop);
    final previous = a.current.state!.execution!.lastOutcome;
    expect(previous, isNotNull);
    await a.stop(id: const CommandId('first'));
    expect(a.stopState.phase, SessionStopPhase.requested);
    final reconnect = a.updates.firstWhere(
      (v) => v.phase == SessionLivePhase.live && server.events >= 2,
    );
    final oldStream = server.streams.removeLast();
    await oldStream.close();
    await reconnect.timeout(const Duration(seconds: 10));
    expect(
      identical(previous, a.current.state!.execution!.lastOutcome),
      isFalse,
      reason: 'the same historical outcome was reconstructed by hydration',
    );
    expect(a.current.state!.execution!.kind.known, ExecutionKind.running);
    expect(a.stopState.phase, SessionStopPhase.requested);
    expect(a.canStop, isFalse);
    await a.stop(id: const CommandId('must-not-send'));
    expect(server.interrupts, hasLength(1));
    await server.execution('ses_one', 'interrupted', reason: 'user');
    await until(a, (_) => !a.stopState.busy);
    expect(a.stopState.phase, SessionStopPhase.ready);
  });

  test(
    'an uncertain HTTP receipt clears only after authoritative settlement',
    () async {
      server.running.add('ses_one');
      server.interruptBody = {
        'data': {'interrupted': true},
      };
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(a, (_) => a.canStop);
      await a.stop(id: const CommandId('first'));
      expect(a.stopState.phase, SessionStopPhase.unconfirmed);
      await server.execution('ses_one', 'interrupted', reason: 'user');
      await until(
        a,
        (v) => v.state?.execution?.kind.known == ExecutionKind.idle,
      );
      expect(a.stopState.phase, SessionStopPhase.ready);
      expect(server.interrupts, hasLength(1));
    },
  );

  test('false, malformed, refusal: no optimistic idle or retry', () async {
    for (final body in [
      {'interrupted': false},
      {
        'data': {'interrupted': true},
      },
      {'secret': 'not displayed'},
    ]) {
      server.running.add('ses_one');
      server.interruptBody = body;
      server.interruptStatus = body.containsKey('secret') ? 401 : 200;
      final directory = createSessionLiveDirectory()!;
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(a, (_) => a.canStop);
      final count = server.interrupts.length;
      await a.stop(id: const CommandId('first'));
      expect(
        a.stopState.phase,
        body.containsKey('secret')
            ? SessionStopPhase.refused
            : body.containsKey('data')
            ? SessionStopPhase.unconfirmed
            : SessionStopPhase.idle,
      );
      expect(a.current.state?.execution?.kind.known, ExecutionKind.running);
      expect(server.interrupts.length, count + 1);
      await directory.close();
    }
  });

  test('an idle parent cannot Stop its running child', () async {
    server.running.add('ses_child');
    final directory = createSessionLiveDirectory()!;
    addTearDown(directory.close);
    final parent = await directory.open(
      profile: p,
      credential: credential,
      session: ref('ses_one'),
    );
    final child = await directory.open(
      profile: p,
      credential: credential,
      session: ref('ses_child'),
    );
    await until(
      parent,
      (v) => v.phase == SessionLivePhase.live && v.state != null,
    );
    await until(child, (_) => child.canStop);
    await parent.stop(id: const CommandId('parent'));
    expect(server.interrupts, isEmpty);
    expect(child.canStop, isTrue);
    await child.stop(id: const CommandId('child'));
    expect(server.interrupts.single.path, endsWith('/ses_child/interrupt'));
  });

  test(
    'accepted request waiting state is bounded; never sends another POST',
    () async {
      server.running.add('ses_one');
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(a, (_) => a.canStop);
      await a.stop(id: const CommandId('first'));
      expect(a.stopState.busy, isTrue);
      await a.updates
          .firstWhere((_) => a.stopState.phase == SessionStopPhase.unconfirmed)
          .timeout(const Duration(seconds: 35));
      expect(a.canStop, isTrue);
      expect(server.interrupts, hasLength(1));
      await server.execution('ses_one', 'interrupted', reason: 'user');
      await until(
        a,
        (v) => v.state?.execution?.kind.known == ExecutionKind.idle,
      );
      expect(a.stopState.phase, SessionStopPhase.ready);
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'handles share one event stream, hydrate read-only and release it',
    () async {
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final b = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final c = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_two'),
      );
      final live = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      expect(live.version, '2.0.22');
      expect(live.lastSyncedAt, isNotNull);
      expect(live.stale, isFalse);
      final text = live.state!.timeline.whereType<UserInput>().single.text;
      expect(text, 'hello from ses_one');
      final other = await until(c, (v) => v.state != null);
      expect(
        other.state!.timeline.whereType<UserInput>().single.text,
        'hello from ses_two',
      );
      expect(b.current.state, isNotNull);
      expect(server.events, 1);
      expect(server.methods, {'GET'});

      a.close();
      c.close();
      expect(b.current.phase, isNot(SessionLivePhase.closed));
      b.close();
      expect(b.current.phase, SessionLivePhase.closed);
      // The slot is gone: a new lease opens a fresh stream.
      final again = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(again, (v) => v.phase == SessionLivePhase.live);
      expect(server.events, 2);
      again.close();
    },
  );

  test(
    'a first hydration is never stale; a session added to a live stream hydrates first',
    () async {
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final seen = <SessionLiveView>[];
      final sub = a.updates.listen(seen.add);
      await until(a, (v) => v.phase == SessionLivePhase.live);
      await sub.cancel();
      for (final view in seen) {
        expect(view.stale, isFalse, reason: view.phase.name);
      }
      final b = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_two'),
      );
      expect(b.current.phase, SessionLivePhase.hydrating);
      final live = await until(
        b,
        (v) => v.phase == SessionLivePhase.live && v.lastSyncedAt != null,
      );
      expect(live.stale, isFalse);
      a.close();
      b.close();
    },
  );

  test(
    'a terminal stream is detached: a retry opens a fresh one beside open screens',
    () async {
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final b = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(a, (v) => v.phase == SessionLivePhase.live);
      server.eventStatus = 401;
      for (final stream in server.streams) {
        await stream.close();
      }
      final terminal = await until(
        b,
        (v) => v.phase == SessionLivePhase.authRequired,
      );
      expect(terminal.stale, isTrue);
      expect(terminal.lastSyncedAt, isNotNull);
      server.eventStatus = null;
      final events = server.events;
      // `a` retries while `b` still holds the dead stream.
      a.close();
      final retried = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(retried, (v) => v.phase == SessionLivePhase.live);
      expect(server.events, events + 1);
      expect(b.current.phase, SessionLivePhase.authRequired);
      // Closing the directory also reaches the detached terminal stream.
      await directory.close();
      expect(b.current.phase, SessionLivePhase.closed);
      expect(retried.current.phase, SessionLivePhase.closed);
    },
  );

  test('an unverified server version fails closed before streaming', () async {
    server.version = '2.0.23';
    final directory = createSessionLiveDirectory()!;
    addTearDown(directory.close);
    await expectLater(
      directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      ),
      throwsA(
        isA<SessionLiveException>().having(
          (e) => e.failure,
          'failure',
          SessionLiveFailure.incompatibleResponse,
        ),
      ),
    );
    expect(server.events, 0);
    expect(server.paths, ['/proxy/api/info']);
  });

  test('a second secret is never multiplexed over a live stream', () async {
    final directory = createSessionLiveDirectory()!;
    addTearDown(directory.close);
    final a = await directory.open(
      profile: p,
      credential: credential,
      session: ref('ses_one'),
    );
    await expectLater(
      directory.open(
        profile: p,
        credential: EndpointCredential(
          kind: EndpointAuthKind.password,
          secret: 'other-secret',
        ),
        session: ref('ses_one'),
      ),
      throwsA(
        isA<SessionLiveException>().having(
          (e) => e.failure,
          'failure',
          SessionLiveFailure.authenticationRequired,
        ),
      ),
    );
    a.close();
  });

  test(
    'a session of another profile is rejected without any request',
    () async {
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      await expectLater(
        directory.open(
          profile: p,
          credential: credential,
          session: const SessionRef(
            HostId('other'),
            HarnessInstanceId('other'),
            'ses_one',
          ),
        ),
        throwsA(isA<SessionLiveException>()),
      );
      expect(server.paths, isEmpty);
    },
  );

  test(
    'capacity is bounded per stream; closing the directory ends handles',
    () async {
      final directory = createSessionLiveDirectory()!;
      final handles = <SessionLiveHandle>[];
      Object? refused;
      for (var n = 0; n < 12 && refused == null; n++) {
        try {
          handles.add(
            await directory.open(
              profile: p,
              credential: credential,
              session: ref('ses_$n'),
            ),
          );
        } on SessionLiveException catch (error) {
          refused = error.failure;
        }
      }
      expect(refused, SessionLiveFailure.capacity);
      expect(handles, isNotEmpty);
      await until(handles.first, (v) => v.phase == SessionLivePhase.live);
      expect(server.events, 1);
      await directory.close();
      expect(handles.first.current.phase, SessionLivePhase.closed);
      await expectLater(
        directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_x'),
        ),
        throwsA(isA<SessionLiveException>()),
      );
    },
  );

  test('a lease sends only through its outbox, on the same stream', () async {
    final readOnly = createSessionLiveDirectory()!;
    addTearDown(readOnly.close);
    final plain = await readOnly.open(
      profile: p,
      credential: credential,
      session: ref('ses_one'),
    );
    expect(plain.outbox, isNull);
    plain.close();

    final directory = createSessionLiveDirectory(payloads: OutboxStore())!;
    addTearDown(directory.close);
    final handle = await directory.open(
      profile: p,
      credential: credential,
      session: ref('ses_one'),
    );
    await until(handle, (v) => v.phase == SessionLivePhase.live);
    expect(server.methods, {'GET'});
    final outbox = handle.outbox!;
    final result = await outbox.submit(
      session: ref('ses_one'),
      commandId: const CommandId('cmd_1'),
      draft: PromptDraft(text: 'Hi'),
      delivery: Delivery.steer,
    );
    expect(result.entry?.state, SubmissionKind.admitted);
    final body = jsonDecode(server.prompts.single) as Map<String, Object?>;
    expect(body.keys, ['id', 'text', 'delivery', 'resume']);
    expect(body['id'], matches(RegExp(r'^msg_[0-9a-f]{12}[0-9A-Za-z]{14}$')));
    expect(body, containsPair('text', 'Hi'));
    expect(body, containsPair('delivery', 'steer'));
    expect(body, containsPair('resume', true));
    expect(server.paths, contains('/proxy/api/session/ses_one/prompt'));
    expect(server.events, 1);
    handle.close();
    expect(handle.outbox, isNull);
  });

  test(
    'permission replies share one fence, exact JSON, no replay, no ledger',
    () async {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': 'ses_one',
        'action': 'read',
        'resources': ['src/a.txt'],
      });
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final b = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final view = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      final req = view.state!.interactions.single;
      expect(a.outbox, isNull);
      expect(a.canReply(req), isTrue);
      await a.reply(
        request: req,
        response: ApprovalResponse('once'),
        id: const CommandId('r1'),
      );
      expect(server.replies.single, '{"decision":"once"}');
      expect(
        server.paths,
        contains('/proxy/api/session/ses_one/permission/per_1/reply'),
      );
      expect(a.replyState(req.id).phase, SessionPermissionReplyPhase.requested);
      await b.reply(
        request: req,
        response: ApprovalResponse('once'),
        id: const CommandId('r2'),
      );
      expect(server.replies, hasLength(1));
      a.close();
      b.close();
      await b.reply(
        request: req,
        response: ApprovalResponse('once'),
        id: const CommandId('r3'),
      );
      expect(server.replies, hasLength(1));
    },
  );

  test(
    'refused replies keep the card actionable and change nothing else',
    () async {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': 'ses_one',
        'action': 'read',
        'resources': ['src/a.txt'],
      });
      server.replyStatus = 401;
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final view = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      final req = view.state!.interactions.single;
      await a.reply(
        request: req,
        response: ApprovalResponse('once'),
        id: const CommandId('r1'),
      );
      expect(a.replyState(req.id).phase, SessionPermissionReplyPhase.refused);
      expect(
        a.current.state?.execution?.kind.known,
        isNot(ExecutionKind.running),
      );
      expect(a.canReply(req), isTrue);
      a.close();
    },
  );

  for (final (status, phase) in [
    (404, SessionPermissionReplyPhase.refused),
    (500, SessionPermissionReplyPhase.unconfirmed),
  ]) {
    test('reply status $status maps to ${phase.name} with one POST', () async {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': 'ses_one',
        'action': 'read',
        'resources': ['src/a.txt'],
      });
      server.replyStatus = status;
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final view = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      final req = view.state!.interactions.single;
      await a.reply(
        request: req,
        response: ApprovalResponse('once'),
        id: const CommandId('r1'),
      );
      expect(a.replyState(req.id).phase, phase);
      expect(server.replies, hasLength(1));
      expect(
        a.current.state?.execution?.kind.known,
        isNot(ExecutionKind.running),
      );
      a.close();
    });
  }

  test('the same request id in two sessions keeps two fences', () async {
    for (final session in ['ses_one', 'ses_two']) {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': session,
        'action': 'read',
        'resources': ['src/a.txt'],
      });
    }
    final directory = createSessionLiveDirectory()!;
    addTearDown(directory.close);
    final a = await directory.open(
      profile: p,
      credential: credential,
      session: ref('ses_one'),
    );
    final b = await directory.open(
      profile: p,
      credential: credential,
      session: ref('ses_two'),
    );
    InteractionRequest askFor(SessionRef session, SessionLiveView view) =>
        view.state!.interactions.singleWhere(
          (r) =>
              r.owner is SessionOwner &&
              (r.owner as SessionOwner).session == session,
        );
    final askA = askFor(
      ref('ses_one'),
      await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      ),
    );
    final askB = askFor(
      ref('ses_two'),
      await until(
        b,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      ),
    );

    expect(a.canReply(askB), isFalse);
    await a.reply(
      request: askA,
      response: ApprovalResponse('once'),
      id: const CommandId('r1'),
    );
    expect(a.replyState(askA.id).phase, SessionPermissionReplyPhase.requested);
    expect(b.replyState(askB.id).phase, SessionPermissionReplyPhase.ready);
    expect(b.canReply(askB), isTrue);
    await b.reply(
      request: askB,
      response: ApprovalResponse('once'),
      id: const CommandId('r2'),
    );
    expect(server.replies, hasLength(2));
    expect(
      server.paths,
      containsAll([
        '/proxy/api/session/ses_one/permission/per_1/reply',
        '/proxy/api/session/ses_two/permission/per_1/reply',
      ]),
    );
    a.close();
    b.close();
  });

  group('automatic once responder (V2-047A3)', () {
    Future<PermissionModeStore> defaultOnStore() async {
      final backend = FakeMetadataBackend();
      final store = PermissionModeStore(
        store: V2MetadataStore(backend: backend),
      );
      await store.initialize();
      addTearDown(store.dispose);
      return store;
    }

    Future<void> waitForReplies(int count) async {
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (server.replies.length < count &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    test(
      'default ON sends one exact once POST and never PATCH/always',
      () async {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/a.txt'],
        });
        final policy = await defaultOnStore();
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final a = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        final view = await until(
          a,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        final req = view.state!.interactions.single;
        expect(req.automaticChoice?.id, 'once');
        await waitForReplies(1);
        expect(server.replies, hasLength(1));
        expect(server.replies.single, '{"decision":"once"}');
        expect(
          server.paths,
          contains('/proxy/api/session/ses_one/permission/per_1/reply'),
        );
        expect(server.methods, isNot(contains('PATCH')));
        expect(server.prompts, isEmpty);
        expect(
          a.replyState(req.id).phase,
          SessionPermissionReplyPhase.requested,
        );
        a.close();
      },
    );

    test(
      'per-session Ask suppresses the automatic reply, manual still works',
      () async {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/a.txt'],
        });
        final policy = await defaultOnStore();
        await policy.setSessionMode(ref('ses_one'), PermissionMode.ask);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final a = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        final view = await until(
          a,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        final req = view.state!.interactions.single;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
        expect(a.canReply(req), isTrue);
        await a.reply(
          request: req,
          response: ApprovalResponse('once'),
          id: const CommandId('manual_1'),
        );
        expect(server.replies.single, '{"decision":"once"}');
        a.close();
      },
    );

    test('no policy sends nothing automatically', () async {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': 'ses_one',
        'action': 'read',
        'resources': ['src/a.txt'],
      });
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final view = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      expect(view.state!.interactions.single.id.value, 'per_1');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(server.replies, isEmpty);
      expect(a.canReply(view.state!.interactions.single), isTrue);
      a.close();
    });

    test('404 auto is refused, latched and stays actionable', () async {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': 'ses_one',
        'action': 'read',
        'resources': ['src/a.txt'],
      });
      server.replyStatus = 404;
      final policy = await defaultOnStore();
      final directory = createSessionLiveDirectory(permissionModes: policy)!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final view = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      final req = view.state!.interactions.single;
      await waitForReplies(1);
      expect(server.replies, hasLength(1));
      expect(a.replyState(req.id).phase, SessionPermissionReplyPhase.refused);
      // The card is not removed by the receipt; only the stream removes it.
      expect(a.current.state!.interactions.single.id.value, 'per_1');
      expect(a.canReply(req), isTrue);
      // Latch: a second concurrent lease on the same slot never replays.
      final b = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      await until(b, (v) => v.phase == SessionLivePhase.live);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(server.replies, hasLength(1));
      a.close();
      b.close();
    });

    test('500 auto is unconfirmed, single POST and actionable', () async {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': 'ses_one',
        'action': 'read',
        'resources': ['src/a.txt'],
      });
      server.replyStatus = 500;
      final policy = await defaultOnStore();
      final directory = createSessionLiveDirectory(permissionModes: policy)!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final view = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      final req = view.state!.interactions.single;
      await waitForReplies(1);
      expect(server.replies, hasLength(1));
      expect(
        a.replyState(req.id).phase,
        SessionPermissionReplyPhase.unconfirmed,
      );
      expect(a.canReply(req), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(server.replies, hasLength(1));
      a.close();
    });

    test(
      'an unconfirmed manual reply is never upgraded by a later frame',
      () async {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/a.txt'],
        });
        final policy = await defaultOnStore();
        await policy.setSessionMode(ref('ses_one'), PermissionMode.ask);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final a = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        final view = await until(
          a,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        final req = view.state!.interactions.single;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
        server.replyStatus = 500;
        await a.reply(
          request: req,
          response: ApprovalResponse('reject'),
          id: const CommandId('manual_reject'),
        );
        expect(
          a.replyState(req.id).phase,
          SessionPermissionReplyPhase.unconfirmed,
        );
        expect(server.replies.single, '{"decision":"reject"}');
        // Allow all arrives after the human decision: the latch keeps it.
        expect(
          await policy.setSessionMode(ref('ses_one'), PermissionMode.allowAll),
          isTrue,
        );
        await server.execution('ses_one', 'started');
        await until(
          a,
          (v) => v.state?.execution?.kind.known == ExecutionKind.running,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, hasLength(1));
        expect(server.replies, isNot(contains('{"decision":"once"}')));
        a.close();
      },
    );

    test('two resident permissions in one session each get one POST', () async {
      for (final id in ['per_1', 'per_2']) {
        server.permissions.add({
          'id': id,
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/$id.txt'],
        });
      }
      final policy = await defaultOnStore();
      final directory = createSessionLiveDirectory(permissionModes: policy)!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final view = await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      expect(view.state!.interactions, hasLength(2));
      await waitForReplies(2);
      expect(server.replies, hasLength(2));
      expect(server.replies.every((r) => r == '{"decision":"once"}'), isTrue);
      expect(
        server.paths.where((path) => path.endsWith('/reply')),
        containsAll([
          '/proxy/api/session/ses_one/permission/per_1/reply',
          '/proxy/api/session/ses_one/permission/per_2/reply',
        ]),
      );
      await server.execution('ses_one', 'started');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(server.replies, hasLength(2));
      a.close();
    });

    test(
      'reopening after the last close never replays an uncertain reply',
      () async {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/a.txt'],
        });
        server.replyStatus = 500;
        final policy = await defaultOnStore();
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final a = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        final view = await until(
          a,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        expect(view.state!.interactions.single.id.value, 'per_1');
        await waitForReplies(1);
        expect(server.replies, hasLength(1));
        a.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final b = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        await until(
          b,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, hasLength(1));
        b.close();
      },
    );

    test(
      'a human rejection survives closing and reopening the session',
      () async {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/a.txt'],
        });
        final policy = await defaultOnStore();
        await policy.setSessionMode(ref('ses_one'), PermissionMode.ask);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final a = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        final view = await until(
          a,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        final req = view.state!.interactions.single;
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
        server.replyStatus = 500;
        await a.reply(
          request: req,
          response: ApprovalResponse('reject'),
          id: const CommandId('manual_reject'),
        );
        expect(server.replies.single, '{"decision":"reject"}');
        expect(
          await policy.setSessionMode(ref('ses_one'), PermissionMode.allowAll),
          isTrue,
        );
        a.close();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final b = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        await until(
          b,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, hasLength(1));
        expect(server.replies, isNot(contains('{"decision":"once"}')));
        b.close();
      },
    );

    test(
      'switching to Allow all answers a resident request without a frame',
      () async {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/a.txt'],
        });
        final policy = await defaultOnStore();
        await policy.setSessionMode(ref('ses_one'), PermissionMode.ask);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final a = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        final view = await until(
          a,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        expect(view.state!.interactions.single.id.value, 'per_1');
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
        expect(
          await policy.setSessionMode(ref('ses_one'), PermissionMode.allowAll),
          isTrue,
        );
        await waitForReplies(1);
        expect(server.replies, hasLength(1));
        expect(server.replies.single, '{"decision":"once"}');
        // Back to Ask: a later policy notification never sends another reply.
        expect(
          await policy.setSessionMode(ref('ses_one'), PermissionMode.ask),
          isTrue,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, hasLength(1));
        a.close();
      },
    );

    test(
      'a policy change never answers a session whose lease was released',
      () async {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': 'ses_one',
          'action': 'read',
          'resources': ['src/a.txt'],
        });
        final policy = await defaultOnStore();
        await policy.setSessionMode(ref('ses_one'), PermissionMode.ask);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final a = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_one'),
        );
        await until(
          a,
          (v) => v.phase == SessionLivePhase.live && v.state != null,
        );
        a.close();
        expect(
          await policy.setSessionMode(ref('ses_one'), PermissionMode.allowAll),
          isTrue,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
      },
    );

    test('two sessions stay isolated, one auto each', () async {
      for (final session in ['ses_one', 'ses_two']) {
        server.permissions.add({
          'id': 'per_1',
          'sessionID': session,
          'action': 'read',
          'resources': ['src/a.txt'],
        });
      }
      final policy = await defaultOnStore();
      final directory = createSessionLiveDirectory(permissionModes: policy)!;
      addTearDown(directory.close);
      final a = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      final b = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_two'),
      );
      await until(
        a,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      await until(
        b,
        (v) => v.phase == SessionLivePhase.live && v.state != null,
      );
      await waitForReplies(2);
      expect(server.replies, hasLength(2));
      expect(server.replies.every((r) => r == '{"decision":"once"}'), isTrue);
      expect(
        server.paths,
        containsAll([
          '/proxy/api/session/ses_one/permission/per_1/reply',
          '/proxy/api/session/ses_two/permission/per_1/reply',
        ]),
      );
      a.close();
      b.close();
    });
  });

  group('Unrestricted session rule (V2-047B2)', () {
    const wildcard = {'action': '*', 'resource': '*', 'effect': 'allow'};
    const ask = {'action': 'bash', 'resource': '*', 'effect': 'ask'};
    late FakeMetadataBackend backend;

    Future<UnrestrictedOwnershipStore> ledger() async {
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await store.initialize();
      return store;
    }

    setUp(() => backend = FakeMetadataBackend());

    Future<(SessionLiveDirectory, SessionLiveHandle)> openLive(
      UnrestrictedOwnershipStore? store,
    ) async {
      final directory = createSessionLiveDirectory(
        unrestrictedOwnership: store,
      )!;
      addTearDown(directory.close);
      final handle = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      addTearDown(handle.close);
      await until(handle, (v) => v.phase == SessionLivePhase.live);
      return (directory, handle);
    }

    Future<SessionUnrestrictedState> settled(SessionLiveHandle handle) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        final state = handle.unrestrictedState;
        if (!state.busy && state.phase != SessionUnrestrictedPhase.unknown) {
          return state;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('Unrestricted state never settled');
    }

    List<Object?> sent(int index) =>
        (jsonDecode(server.patches[index]) as Map)['permissions'] as List;

    test('is absent without an ownership ledger', () async {
      final (_, handle) = await openLive(null);
      expect(handle.supportsUnrestricted, isFalse);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      expect(server.patches, isEmpty);
    });

    test(
      'enable appends to fresh rules and shows on only after a read',
      () async {
        server.sessionRules['ses_one'] = [ask];
        final store = await ledger();
        final (_, handle) = await openLive(store);
        expect((await settled(handle)).phase, SessionUnrestrictedPhase.off);
        expect(handle.canEnableUnrestricted, isTrue);
        await handle.enableUnrestricted(id: const CommandId('cmd_on'));
        final state = await settled(handle);
        expect(state.phase, SessionUnrestrictedPhase.on);
        expect(state.inEffect, isTrue);
        expect(server.patches, hasLength(1));
        expect(sent(0), [ask, wildcard]);
        expect(
          jsonDecode(server.patches.single) as Map,
          hasLength(1),
          reason: 'title and metadata are never sent',
        );
        expect(store.recordFor(ref('ses_one'))!.stage, UnrestrictedStage.owned);
      },
    );

    test(
      'a wildcard CodeWalk did not add is never claimed or removed',
      () async {
        server.sessionRules['ses_one'] = [ask, wildcard];
        final (_, handle) = await openLive(await ledger());
        final state = await settled(handle);
        expect(state.phase, SessionUnrestrictedPhase.elsewhere);
        expect(state.inEffect, isTrue);
        expect(handle.canEnableUnrestricted, isFalse);
        expect(handle.canDisableUnrestricted, isFalse);
        await handle.disableUnrestricted(id: const CommandId('cmd_off'));
        expect(server.patches, isEmpty);
      },
    );

    test('a ledger write failure sends nothing', () async {
      backend.failWrite = UnrestrictedOwnershipStore.key;
      final (_, handle) = await openLive(await ledger());
      await settled(handle);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      final state = await settled(handle);
      expect(state.notice, SessionUnrestrictedNotice.refused);
      expect(state.phase, SessionUnrestrictedPhase.off);
      expect(server.patches, isEmpty);
    });

    test('a refused write drops the pending record', () async {
      server.patchStatus = 400;
      final store = await ledger();
      final (_, handle) = await openLive(store);
      await settled(handle);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      final state = await settled(handle);
      expect(state.phase, SessionUnrestrictedPhase.off);
      expect(state.notice, SessionUnrestrictedNotice.refused);
      expect(server.patches, hasLength(1));
      expect(store.recordFor(ref('ses_one')), isNull);
    });

    test('an unknown outcome is checked by one read, never resent', () async {
      server
        ..patchStatus = 500
        ..patchApplies = true;
      final store = await ledger();
      final (_, handle) = await openLive(store);
      await settled(handle);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      final state = await settled(handle);
      expect(state.phase, SessionUnrestrictedPhase.on);
      expect(state.notice, SessionUnrestrictedNotice.unconfirmed);
      expect(server.patches, hasLength(1));
      expect(store.recordFor(ref('ses_one'))!.stage, UnrestrictedStage.owned);
    });

    test('disable restores exactly the preceding rules', () async {
      server.sessionRules['ses_one'] = [ask];
      final store = await ledger();
      final (_, handle) = await openLive(store);
      await settled(handle);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      await settled(handle);
      expect(handle.canDisableUnrestricted, isTrue);
      await handle.disableUnrestricted(id: const CommandId('cmd_off'));
      final state = await settled(handle);
      expect(state.phase, SessionUnrestrictedPhase.off);
      expect(state.inEffect, isFalse);
      expect(server.patches, hasLength(2));
      expect(sent(1), [ask]);
      expect(server.sessionRules['ses_one'], [ask]);
      expect(store.recordFor(ref('ses_one')), isNull);
    });

    test('rules changed by another client are never overwritten', () async {
      server.sessionRules['ses_one'] = [ask];
      final store = await ledger();
      final (_, handle) = await openLive(store);
      await settled(handle);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      await settled(handle);
      // Another client inserts a rule before CodeWalk's wildcard.
      const deny = {'action': 'edit', 'resource': '*', 'effect': 'deny'};
      server.sessionRules['ses_one'] = [ask, deny, wildcard];
      await handle.disableUnrestricted(id: const CommandId('cmd_off'));
      final state = await settled(handle);
      expect(state.phase, SessionUnrestrictedPhase.conflict);
      expect(state.notice, SessionUnrestrictedNotice.changedElsewhere);
      expect(state.inEffect, isTrue);
      expect(server.patches, hasLength(1));
      expect(server.sessionRules['ses_one'], [ask, deny, wildcard]);
      expect(store.recordFor(ref('ses_one')), isNotNull);
      expect(handle.canDisableUnrestricted, isFalse);
    });

    test('a reopened session recognizes CodeWalk\'s insertion', () async {
      final store = await ledger();
      final (directory, handle) = await openLive(store);
      await settled(handle);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      await settled(handle);
      handle.close();
      final again = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      addTearDown(again.close);
      await until(again, (v) => v.phase == SessionLivePhase.live);
      expect((await settled(again)).phase, SessionUnrestrictedPhase.on);
      expect(again.canDisableUnrestricted, isTrue);
    });

    test('the automatic responder never writes rules', () async {
      server.permissions.add({
        'id': 'per_1',
        'sessionID': 'ses_one',
        'action': 'read',
        'resources': ['src/a.txt'],
      });
      final policy = PermissionModeStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      );
      await policy.initialize();
      addTearDown(policy.dispose);
      final directory = createSessionLiveDirectory(
        permissionModes: policy,
        unrestrictedOwnership: await ledger(),
      )!;
      addTearDown(directory.close);
      final handle = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      addTearDown(handle.close);
      await until(handle, (v) => v.phase == SessionLivePhase.live);
      await settled(handle);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (server.replies.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(server.replies.single, '{"decision":"once"}');
      expect(server.patches, isEmpty);
    });
  });

  group('Unrestricted after review (V2-047B2)', () {
    const wildcard = {'action': '*', 'resource': '*', 'effect': 'allow'};
    const ask = {'action': 'bash', 'resource': '*', 'effect': 'ask'};
    late FakeMetadataBackend backend;
    setUp(() => backend = FakeMetadataBackend());

    Future<UnrestrictedOwnershipStore> ledger() async {
      final store = UnrestrictedOwnershipStore(
        store: V2MetadataStore(backend: backend),
      );
      await store.initialize();
      return store;
    }

    Future<SessionLiveHandle> openLive(UnrestrictedOwnershipStore store) async {
      final directory = createSessionLiveDirectory(
        unrestrictedOwnership: store,
      )!;
      addTearDown(directory.close);
      final handle = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      addTearDown(handle.close);
      await until(handle, (v) => v.phase == SessionLivePhase.live);
      return handle;
    }

    Future<SessionUnrestrictedState> settled(
      SessionLiveHandle handle, {
      bool Function(SessionUnrestrictedState)? until,
    }) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        final state = handle.unrestrictedState;
        if (!state.busy &&
            state.phase != SessionUnrestrictedPhase.unknown &&
            (until?.call(state) ?? true)) {
          return state;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('Unrestricted state never settled');
    }

    test('a failed read never hides a rule that is in effect', () async {
      server.sessionRules['ses_one'] = [ask];
      final handle = await openLive(await ledger());
      await settled(handle);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      expect((await settled(handle)).phase, SessionUnrestrictedPhase.on);
      server.failSessionReads.add(server.sessionReads + 1);
      await handle.disableUnrestricted(id: const CommandId('cmd_off'));
      final state = await settled(handle);
      expect(state.phase, SessionUnrestrictedPhase.unavailable);
      expect(state.inEffect, isTrue);
      expect(state.notice, SessionUnrestrictedNotice.none);
      expect(server.patches, hasLength(1));
    });

    test('a failed first read is retried once while live', () async {
      server.sessionRules['ses_one'] = [ask, wildcard];
      // Read 1 hydrates the session; read 2 is the first rules read.
      server.failSessionReads.add(2);
      final handle = await openLive(await ledger());
      final state = await settled(
        handle,
        until: (s) => s.phase != SessionUnrestrictedPhase.unavailable,
      );
      expect(state.phase, SessionUnrestrictedPhase.elsewhere);
    });

    test('an enable that may not write says why', () async {
      final handle = await openLive(await ledger());
      expect((await settled(handle)).phase, SessionUnrestrictedPhase.off);
      server.sessionRules['ses_one'] = [ask, wildcard];
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      final state = await settled(handle);
      expect(state.phase, SessionUnrestrictedPhase.elsewhere);
      expect(state.notice, SessionUnrestrictedNotice.changedElsewhere);
      expect(server.patches, isEmpty);
    });

    test('a full ruleset is never extended past what can be read', () async {
      server.sessionRules['ses_one'] = List.filled(1024, ask);
      final handle = await openLive(await ledger());
      expect((await settled(handle)).phase, SessionUnrestrictedPhase.off);
      await handle.enableUnrestricted(id: const CommandId('cmd_on'));
      expect((await settled(handle)).notice, SessionUnrestrictedNotice.refused);
      expect(server.patches, isEmpty);
    });

    test('an unpersisted promotion is reported and still removable', () async {
      server.sessionRules['ses_one'] = [ask, wildcard];
      final store = await ledger();
      await store.put(
        ref('ses_one'),
        UnrestrictedOwnership(
          stage: UnrestrictedStage.applying,
          base: unrestrictedFingerprint(OpenCodeSessionRules.parse([ask])),
          owned: unrestrictedFingerprint(
            OpenCodeSessionRules.parse([ask, wildcard]),
          ),
        ),
      );
      backend.failWrite = UnrestrictedOwnershipStore.key;
      final handle = await openLive(store);
      final state = await settled(handle);
      expect(state.phase, SessionUnrestrictedPhase.on);
      expect(state.notice, SessionUnrestrictedNotice.refused);
      expect(
        store.recordFor(ref('ses_one'))!.stage,
        UnrestrictedStage.applying,
      );
      backend.failWrite = null;
      await handle.disableUnrestricted(id: const CommandId('cmd_off'));
      expect((await settled(handle)).phase, SessionUnrestrictedPhase.off);
      expect(server.sessionRules['ses_one'], [ask]);
      expect(store.recordFor(ref('ses_one')), isNull);
    });

    test('live session.permissions frame reconciles unrestricted phase without a manual refresh', () async {
      server.sessionRules['ses_one'] = [ask];
      final store = await ledger();
      final handle = await openLive(store);
      expect((await settled(handle)).phase, SessionUnrestrictedPhase.off);
      expect((await settled(handle)).inEffect, isFalse);

      await server.emit('session.permissions', {
        'sessionID': 'ses_one',
        'permissions': [ask, wildcard],
      });

      await until(handle, (v) => handle.unrestrictedState.inEffect);
      expect(handle.unrestrictedState.phase, SessionUnrestrictedPhase.elsewhere);
      expect(handle.unrestrictedState.inEffect, isTrue);
    });
  });

  group('child requests in the parent (V2-047B3a)', () {
    Map<String, Object?> ask(String id, String session) => {
      'id': id,
      'sessionID': session,
      'action': 'read',
      'resources': ['src/a.txt'],
    };

    Future<SessionLiveHandle> openParent(SessionLiveDirectory directory) async {
      final handle = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      addTearDown(handle.close);
      await until(handle, (v) => v.phase == SessionLivePhase.live);
      return handle;
    }

    InteractionRequest? childRequest(SessionLiveHandle handle, String id) {
      for (final r in handle.current.state?.interactions ?? const []) {
        final owner = r.owner;
        if (r.id.value == id &&
            owner is SessionOwner &&
            owner.session == ref('ses_child')) {
          return r;
        }
      }
      return null;
    }

    Future<void> eventually(bool Function() test) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!test() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(test(), isTrue);
    }

    test('a child request pending before connecting is shown and answered '
        'on the child route', () async {
      server.children['ses_one'] = ['ses_child'];
      server.permissions.add(ask('per_c1', 'ses_child'));
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final handle = await openParent(directory);
      await eventually(() => childRequest(handle, 'per_c1') != null);
      final request = childRequest(handle, 'per_c1')!;
      expect((request.owner as SessionOwner).origin, ref('ses_one'));
      expect(handle.canReply(request), isTrue);
      await handle.reply(
        request: request,
        response: ApprovalResponse('once'),
        id: const CommandId('cmd_child'),
      );
      expect(server.replies, ['{"decision":"once"}']);
      expect(
        server.paths,
        contains('/proxy/api/session/ses_child/permission/per_c1/reply'),
      );
      expect(
        server.paths.where(
          (path) => path.endsWith('/ses_one/permission/per_c1/reply'),
        ),
        isEmpty,
      );
      expect(
        handle.replyState(request.id, owner: ref('ses_child')).phase,
        SessionPermissionReplyPhase.requested,
      );
    });

    test('live child frames open and settle the parent card', () async {
      server.children['ses_one'] = ['ses_child'];
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final handle = await openParent(directory);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await server.emit('permission.asked', ask('per_c2', 'ses_child'));
      await eventually(() => childRequest(handle, 'per_c2') != null);
      await server.emit('permission.replied', {
        'sessionID': 'ses_child',
        'requestID': 'per_c2',
        'reply': 'once',
      });
      await eventually(() => childRequest(handle, 'per_c2') == null);
      expect(server.replies, isEmpty);
    });

    test('a child created after the parent is live is followed', () async {
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final handle = await openParent(directory);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await server.emit('session.created', {
        'sessionID': 'ses_child',
        'parentID': 'ses_one',
      });
      await server.emit('permission.asked', ask('per_c3', 'ses_child'));
      await eventually(() => childRequest(handle, 'per_c3') != null);
    });

    test(
      'parent in Allow all auto-approves child requests when child has no override',
      () async {
        server.children['ses_one'] = ['ses_child'];
        server.permissions
          ..add(ask('per_own', 'ses_one'))
          ..add(ask('per_c4', 'ses_child'));
        final policy = PermissionModeStore(
          store: V2MetadataStore(backend: FakeMetadataBackend()),
        );
        await policy.initialize();
        addTearDown(policy.dispose);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final handle = await openParent(directory);
        await eventually(() => childRequest(handle, 'per_c4') != null);
        await eventually(() => server.replies.length >= 2);
        expect(
          server.paths,
          contains('/proxy/api/session/ses_one/permission/per_own/reply'),
        );
        expect(
          server.paths,
          contains('/proxy/api/session/ses_child/permission/per_c4/reply'),
        );
        expect(server.replies, ['{"decision":"once"}', '{"decision":"once"}']);
      },
    );

    test(
      'explicit Ask on parent vetoes child explicit Allow all override',
      () async {
        server.children['ses_one'] = ['ses_child'];
        server.permissions.add(ask('per_c_veto', 'ses_child'));
        final policy = PermissionModeStore(
          store: V2MetadataStore(backend: FakeMetadataBackend()),
        );
        await policy.initialize();
        addTearDown(policy.dispose);
        await policy.setSessionMode(ref('ses_one'), PermissionMode.ask);
        await policy.setSessionMode(ref('ses_child'), PermissionMode.allowAll);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final handle = await openParent(directory);
        await eventually(() => childRequest(handle, 'per_c_veto') != null);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
        expect(
          server.paths.where(
            (p) => p.contains('ses_child/permission/per_c_veto/reply'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'explicit Ask on child vetoes parent Allow all mode',
      () async {
        server.children['ses_one'] = ['ses_child'];
        server.permissions.add(ask('per_c_child_ask', 'ses_child'));
        final policy = PermissionModeStore(
          store: V2MetadataStore(backend: FakeMetadataBackend()),
        );
        await policy.initialize();
        addTearDown(policy.dispose);
        await policy.setSessionMode(ref('ses_child'), PermissionMode.ask);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final handle = await openParent(directory);
        await eventually(() => childRequest(handle, 'per_c_child_ask') != null);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
        expect(
          server.paths.where(
            (p) => p.contains('ses_child/permission/per_c_child_ask/reply'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'child explicit Allow all applies when parent has no override under global Ask',
      () async {
        server.children['ses_one'] = ['ses_child'];
        server.permissions.add(ask('per_c_allow', 'ses_child'));
        final policy = PermissionModeStore(
          store: V2MetadataStore(
            backend: FakeMetadataBackend()
              ..values[PermissionModeStore.globalKey] = 'ask',
          ),
        );
        await policy.initialize();
        addTearDown(policy.dispose);
        await policy.setSessionMode(ref('ses_child'), PermissionMode.allowAll);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);
        final handle = await openParent(directory);
        await eventually(() => childRequest(handle, 'per_c_allow') != null);
        await eventually(() => server.replies.isNotEmpty);
        expect(
          server.paths,
          contains('/proxy/api/session/ses_child/permission/per_c_allow/reply'),
        );
        expect(server.replies, ['{"decision":"once"}']);
      },
    );

    test(
      'multi-client deduplication: watching both parent and child sends only one reply',
      () async {
        server.children['ses_one'] = ['ses_child'];
        server.permissions.add(ask('per_c_dedupe', 'ses_child'));
        final policy = PermissionModeStore(
          store: V2MetadataStore(backend: FakeMetadataBackend()),
        );
        await policy.initialize();
        addTearDown(policy.dispose);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);

        final parentHandle = await openParent(directory);
        final childHandle = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_child'),
        );
        addTearDown(childHandle.close);
        await until(childHandle, (v) => v.phase == SessionLivePhase.live);

        await eventually(
          () => childRequest(parentHandle, 'per_c_dedupe') != null,
        );
        await eventually(() => server.replies.isNotEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(server.replies, ['{"decision":"once"}']);
        expect(
          server.paths.where(
            (p) => p.contains('ses_child/permission/per_c_dedupe/reply'),
          ),
          hasLength(1),
        );
      },
    );

    test(
      'directly watching a child session honors parent explicit Ask floor',
      () async {
        server.children['ses_one'] = ['ses_child'];
        server.permissions.add(ask('per_c_veto', 'ses_child'));
        final policy = PermissionModeStore(
          store: V2MetadataStore(
            backend: FakeMetadataBackend()
              ..values[PermissionModeStore.globalKey] = 'allowAll',
          ),
        );
        await policy.initialize();
        addTearDown(policy.dispose);
        await policy.setSessionMode(ref('ses_one'), PermissionMode.ask);
        final directory = createSessionLiveDirectory(permissionModes: policy)!;
        addTearDown(directory.close);

        final childHandle = await directory.open(
          profile: p,
          credential: credential,
          session: ref('ses_child'),
        );
        addTearDown(childHandle.close);
        await until(childHandle, (v) => v.phase == SessionLivePhase.live);

        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(server.replies, isEmpty);
      },
    );

    test(
      'a 404 reads as answered elsewhere and re-reads, never resends',
      () async {
        server
          ..children['ses_one'] = ['ses_child']
          ..replyStatus = 404;
        server.permissions.add(ask('per_c5', 'ses_child'));
        final directory = createSessionLiveDirectory()!;
        addTearDown(directory.close);
        final handle = await openParent(directory);
        await eventually(() => childRequest(handle, 'per_c5') != null);
        final childReads = server.paths
            .where((path) => path == '/proxy/api/session/ses_child/permission')
            .length;
        // Someone else answered: the native list no longer has it.
        server.permissions.clear();
        await handle.reply(
          request: childRequest(handle, 'per_c5')!,
          response: ApprovalResponse('once'),
          id: const CommandId('cmd_late'),
        );
        expect(
          handle
              .replyState(
                const InteractionId('per_c5'),
                owner: ref('ses_child'),
              )
              .receipt
              ?.error
              ?.rawType,
          'NotFoundError',
        );
        await eventually(() => childRequest(handle, 'per_c5') == null);
        expect(
          server.paths
              .where(
                (path) => path == '/proxy/api/session/ses_child/permission',
              )
              .length,
          greaterThan(childReads),
        );
        expect(server.replies, hasLength(1));
      },
    );
  });

  group('the catalog feed shares the endpoint stream', () {
    Future<void> eventually(bool Function() test) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!test() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(test(), isTrue);
    }

    test('the feed reports the lifecycle of a session nobody watches', () async {
      server.running.add('ses_one');
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final lease = await directory.catalogChanges(
        profile: p,
        credential: credential,
      );
      addTearDown(lease.close);
      final signals = <SessionCatalogSignal>[];
      lease.signals.listen(signals.add);
      await eventually(
        () => signals
            .whereType<SessionCatalogConnection>()
            .any((signal) => signal.connected),
      );
      // The endpoint keeps one stream: the feed opened no second one.
      expect(server.events, 1);
      server.streams.last.write(
        'data: ${jsonEncode({'type': 'session.created', 'data': {'sessionID': 'ses_two'}})}\n\n',
      );
      await server.streams.last.flush();
      await eventually(
        () => signals.whereType<SessionCatalogChanged>().isNotEmpty,
      );
    });

    test('the feed reports the current connection state to a late subscriber',
        () async {
      server.running.add('ses_one');
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final lease = await directory.catalogChanges(
        profile: p,
        credential: credential,
      );
      addTearDown(lease.close);
      final signals = <SessionCatalogSignal>[];
      lease.signals.listen(signals.add);
      await eventually(
        () => signals
            .whereType<SessionCatalogConnection>()
            .any((signal) => signal.connected),
      );
    });

    test('the profile stays open while the feed is held', () async {
      server.running.add('ses_one');
      final directory = createSessionLiveDirectory()!;
      addTearDown(directory.close);
      final lease = await directory.catalogChanges(
        profile: p,
        credential: credential,
      );
      addTearDown(lease.close);
      // No live session: the feed alone holds the profile's stream open.
      await eventually(() => server.events == 1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(server.events, 1);
      lease.close();
      // The profile closed with its last holder: the next live session
      // opens a new stream instead of reusing the closed one.
      final handle = await directory.open(
        profile: p,
        credential: credential,
        session: ref('ses_one'),
      );
      addTearDown(handle.close);
      await eventually(() => server.events == 2);
    });
  });
}
