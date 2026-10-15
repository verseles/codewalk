@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:codewalk/platform/sessions/session_live_factory_io.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
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
        'active' => {'data': <String, Object?>{}},
        'inbox' || 'permission' || 'form' => {'data': <Object?>[]},
        'message' => {
          'data': [
            {
              'id': 'msg_1',
              'type': 'user',
              'time': {'created': 1000},
              'text': 'hello from $session',
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
