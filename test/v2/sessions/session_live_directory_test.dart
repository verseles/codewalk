@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/sessions/session_live_factory_io.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_permission_reply.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final session = segments.length > 3 ? segments[3] : 'ses_one';
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
          'cursor': {'previous': null, 'next': null},
        },
        _ => {
          'data': {
            'id': session,
            'title': 'Session',
            'projectID': 'prj_a',
            'location': {'directory': '/workspace'},
            'time': {'created': 1, 'updated': 2},
          },
        },
      }),
    );
    await r.response.close();
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
}
