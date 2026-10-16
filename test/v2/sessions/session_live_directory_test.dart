@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:codewalk/platform/sessions/session_live_factory_io.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_stop.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

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
        'inbox' || 'permission' || 'form' => {'data': <Object?>[]},
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
}
