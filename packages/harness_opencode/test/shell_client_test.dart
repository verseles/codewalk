import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

const _harness = HarnessRef(HostId('host'), HarnessInstanceId('inst'));
const _session = SessionRef(HostId('host'), HarnessInstanceId('inst'), 'ses_a');
const _dir = '/workspace/app';

final class _FakeTransport implements EndpointHttpTransport {
  _FakeTransport(this.handler);
  final FutureOr<TransportResponse> Function(TransportRequest) handler;
  final requests = <TransportRequest>[];

  @override
  Uri endpoint = Uri.parse('http://127.0.0.1:4096/');

  @override
  bool isClosed = false;

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    return handler(request);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _jsonResponse(Object? body, {int status = 200}) =>
    TransportResponse(
      statusCode: status,
      headers: const {
        'content-type': ['application/json'],
      },
      body: status == 204
          ? const Stream.empty()
          : Stream.value(utf8.encode(jsonEncode(body))),
      cancel: () {},
    );

Map<String, Object?> _located(Object? data, {String directory = _dir}) => {
  'location': {'directory': directory},
  'data': data,
};

Map<String, Object?> _rawShell(
  String id, {
  String sessionId = 'ses_a',
  String command = 'make test',
  String status = 'running',
}) => {
  'id': id,
  'status': status,
  'command': command,
  'cwd': '/secret/host/path',
  'file': '/tmp/secret-shell.log',
  'pid': 98765,
  'shell': '/bin/bash',
  'metadata': {'sessionID': sessionId},
  'time': {'started': 1760000000000},
};

final class _FakeSse implements RecoveringSseConnection {
  final _controller = StreamController<SseRecoveryUpdate>.broadcast();
  @override
  Stream<SseRecoveryUpdate> get updates => _controller.stream;
  @override
  int generation = 0;
  bool released = false;
  bool closed = false;

  void connect(int next) {
    generation = next;
    _controller.add(
      SseConnected(
        next,
        firstFrame: SseFrame(
          data: jsonEncode(const {'type': 'server.connected'}),
        ),
      ),
    );
  }

  void send(Map<String, Object?> frame) => _controller.add(
    SseBatch(generation, [SseFrame(data: jsonEncode(frame))]),
  );

  @override
  void releaseGeneration(int generation) => released = true;

  @override
  void wake() {}

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }
}

void main() {
  test(
    'listRunning filters by sessionID, verifies location, and redacts command',
    () async {
      final transport = _FakeTransport(
        (_) => _jsonResponse(
          _located([
            _rawShell('sh_mine', command: 'deploy --token secretvalue12345'),
            _rawShell('sh_other', sessionId: 'ses_b', command: 'echo other'),
          ]),
        ),
      );
      final client = OpenCodeShellClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      final shells = await client.listRunning(
        session: _session,
        directory: _dir,
      );
      expect(shells, hasLength(1));
      expect(shells.single.id, 'sh_mine');
      expect(shells.single.command, isNot(contains('secretvalue12345')));
      expect(shells.single.command, contains('[redacted]'));
      expect(transport.requests.single.method, 'GET');
      expect(
        Uri.parse(
          transport.requests.single.path,
        ).queryParameters['location[directory]'],
        _dir,
      );
    },
  );

  test(
    'readOutput pages by cursor/limit, redacts credentials, and handles 404',
    () async {
      var status = 200;
      final transport = _FakeTransport(
        (_) => status == 404
            ? _jsonResponse({'error': 'not found'}, status: 404)
            : _jsonResponse(
                _located({
                  'output':
                      'Authorization: Bearer mysecretbearertoken99\nline 2\n',
                  'cursor': 48,
                  'size': 96,
                  'truncated': false,
                }),
              ),
      );
      final client = OpenCodeShellClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      final page = await client.readOutput(
        session: _session,
        shellId: 'sh_out1',
        directory: _dir,
        cursor: 0,
        limit: 4096,
      );
      expect(page, isNotNull);
      expect(page!.output, isNot(contains('mysecretbearertoken99')));
      expect(page.output, contains('[redacted]'));
      expect(page.cursor, 48);
      expect(page.size, 96);
      expect(page.hasMore, isTrue);

      status = 404;
      expect(
        await client.readOutput(
          session: _session,
          shellId: 'sh_out1',
          directory: _dir,
        ),
        isNull,
      );

      // Rejects non-sh_ ID before touching transport.
      final countBefore = transport.requests.length;
      await expectLater(
        () => client.readOutput(session: _session, shellId: 'bad_id'),
        throwsA(
          isA<OpenCodeSessionReadException>().having(
            (e) => e.failure,
            'failure',
            OpenCodeSessionReadFailure.invalidRequest,
          ),
        ),
      );
      expect(transport.requests.length, countBefore);
    },
  );

  test(
    'stop handles 204, 404, 401, and rejects invalid shellId without sending',
    () async {
      var status = 204;
      final transport = _FakeTransport(
        (_) => _jsonResponse(null, status: status),
      );
      final client = OpenCodeShellClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );

      final ok = await client.stop(
        session: _session,
        shellId: 'sh_stop1',
        id: const CommandId('c1'),
        directory: _dir,
      );
      expect(ok.receipt.state.known, ReceiptState.accepted);
      expect(ok.notFound, isFalse);
      expect(transport.requests.single.method, 'DELETE');

      status = 404;
      final gone = await client.stop(
        session: _session,
        shellId: 'sh_stop1',
        id: const CommandId('c2'),
        directory: _dir,
      );
      expect(gone.receipt.state.known, ReceiptState.accepted);
      expect(gone.notFound, isTrue);

      status = 401;
      final auth = await client.stop(
        session: _session,
        shellId: 'sh_stop1',
        id: const CommandId('c3'),
      );
      expect(auth.receipt.state.known, ReceiptState.rejected);

      final before = transport.requests.length;
      final invalid = await client.stop(
        session: _session,
        shellId: '../etc/passwd',
        id: const CommandId('c4'),
      );
      expect(invalid.receipt.state.known, ReceiptState.unavailable);
      expect(transport.requests.length, before);
    },
  );

  test(
    'OpenCodeStreamOwner routes shell.* SSE frames without top-level sessionID and hydrates shells gracefully',
    () async {
      var failShellList = false;
      final transport = _FakeTransport((req) {
        final path = Uri.parse(req.path).path;
        if (path == 'api/session/active') {
          return _jsonResponse({'data': <String, Object?>{}});
        }
        if (path == 'api/session/ses_a') {
          return _jsonResponse({
            'data': {
              'id': 'ses_a',
              'title': 'Demo',
              'directory': _dir,
              'projectID': 'prj_1',
              'time': {'created': 1760000000000, 'updated': 1760000000000},
            },
          });
        }
        if (path == 'api/session/ses_a/inbox' ||
            path == 'api/session/ses_a/permission' ||
            path == 'api/session/ses_a/form') {
          return _jsonResponse({'data': <Object?>[]});
        }
        if (path == 'api/session/ses_a/message') {
          return _jsonResponse({
            'data': <Object?>[],
            'cursor': {'previous': null, 'next': null},
          });
        }
        if (path == 'api/shell') {
          if (failShellList) {
            return _jsonResponse({'error': 'boom'}, status: 500);
          }
          return _jsonResponse(_located([_rawShell('sh_init')]));
        }
        return _jsonResponse({'error': 'unexpected $path'}, status: 404);
      });

      final sse = _FakeSse();
      final store = SessionStore(maxSessions: 4);
      final reader = OpenCodeSessionReader(transport, harness: _harness);
      final owner = OpenCodeStreamOwner(
        connection: sse,
        reader: reader,
        store: store,
        harness: _harness,
        sourceVersion: '2.0.22',
        observeShells: true,
      );
      addTearDown(() async {
        await owner.close();
        reader.dispose();
      });

      owner.start();
      owner.watch(_session);
      sse.connect(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.read(_session)?.shells.map((s) => s.id), ['sh_init']);

      // Emit shell.created with NO top-level data.sessionID.
      sse.send({
        'type': 'shell.created',
        'id': 'evt_s1',
        'data': {'info': _rawShell('sh_new', command: 'flutter test')},
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.read(_session)?.shells.map((s) => s.id), [
        'sh_init',
        'sh_new',
      ]);

      // Emit shell.exited with NO sessionID at all.
      sse.send({
        'type': 'shell.exited',
        'id': 'evt_s2',
        'created': 1760000009000,
        'data': {'id': 'sh_new', 'status': 'exited', 'exit': 0},
      });
      await Future<void>.delayed(Duration.zero);
      final exited = store
          .read(_session)!
          .shells
          .firstWhere((s) => s.id == 'sh_new');
      expect(exited.status.known, ShellStatus.exited);
      expect(exited.exitCode, 0);

      // Emit shell.deleted.
      sse.send({
        'type': 'shell.deleted',
        'id': 'evt_s3',
        'data': {'id': 'sh_new'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.read(_session)?.shells.map((s) => s.id), ['sh_init']);

      // A failing /api/shell list during re-hydration does not stall the session.
      failShellList = true;
      owner.refresh(_session);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(store.read(_session)?.connection.kind.known, ConnectionKind.live);
    },
  );

  test(
    'readOutput rejects surrogates/oversize/invalid cursor, and readBoundedPrefix redacts cross-boundary secrets and PEM blocks',
    () async {
      late Object? nextPayload;
      final transport = _FakeTransport((_) => _jsonResponse(nextPayload));
      final client = OpenCodeShellClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );

      // Unpaired UTF-16 surrogate in output is rejected.
      nextPayload = _located({
        'output': 'bad ${String.fromCharCode(0xd800)} text',
        'cursor': 10,
        'size': 10,
        'truncated': false,
      });
      await expectLater(
        () => client.readOutput(
          session: _session,
          shellId: 'sh_1',
          directory: _dir,
          limit: 64,
        ),
        throwsA(
          isA<OpenCodeSessionReadException>().having(
            (e) => e.failure,
            'failure',
            OpenCodeSessionReadFailure.incompatibleResponse,
          ),
        ),
      );

      // Output exceeding requested limit (+ redaction margin) is rejected.
      nextPayload = _located({
        'output': 'x' * (64 + 4096 + 1),
        'cursor': 64 + 4096 + 1,
        'size': 64 + 4096 + 1,
        'truncated': false,
      });
      await expectLater(
        () => client.readOutput(
          session: _session,
          shellId: 'sh_1',
          directory: _dir,
          limit: 64,
        ),
        throwsA(
          isA<OpenCodeSessionReadException>().having(
            (e) => e.failure,
            'failure',
            OpenCodeSessionReadFailure.incompatibleResponse,
          ),
        ),
      );

      // cursor > size is rejected.
      nextPayload = _located({
        'output': 'ok',
        'cursor': 20,
        'size': 10,
        'truncated': false,
      });
      await expectLater(
        () => client.readOutput(
          session: _session,
          shellId: 'sh_1',
          directory: _dir,
          limit: 64,
        ),
        throwsA(
          isA<OpenCodeSessionReadException>().having(
            (e) => e.failure,
            'failure',
            OpenCodeSessionReadFailure.incompatibleResponse,
          ),
        ),
      );

      // Cross-boundary Bearer token spanning maxBytes is redacted whole via
      // lookahead margin and clipped cleanly within cap.
      final prefix = 'a' * (16 * 1024 - 34);
      final crossBearer =
          '${prefix}Authorization: Bearer super_split_secret_token_999\ntail\n';
      nextPayload = _located({
        'output': crossBearer,
        'cursor': crossBearer.length,
        'size': crossBearer.length + 100,
        'truncated': false,
      });
      final page = await client.readBoundedPrefix(
        session: _session,
        shellId: 'sh_1',
        directory: _dir,
        maxBytes: 16 * 1024,
      );
      expect(page, isNotNull);
      expect(utf8.encode(page!.output).length, lessThanOrEqualTo(16 * 1024));
      expect(page.output, isNot(contains('super_split_secret_token_999')));
      expect(page.output, contains('[redacted]'));
      // Requested limit includes the 4 KiB lookahead margin.
      expect(
        Uri.parse(transport.requests.last.path).queryParameters['limit'],
        '${16 * 1024 + 4096}',
      );

      // Multi-line PEM private key block spanning the 16 KiB boundary is
      // redacted whole so no PEM body bytes leak across the boundary.
      final pemPrefix = 'b' * (16 * 1024 - 32);
      final crossPem =
          '$pemPrefix-----BEGIN PRIVATE KEY-----\n'
          'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC\n'
          '-----END PRIVATE KEY-----\n'
          'after-pem\n';
      nextPayload = _located({
        'output': crossPem,
        'cursor': crossPem.length,
        'size': crossPem.length + 100,
        'truncated': false,
      });
      final pemPage = await client.readBoundedPrefix(
        session: _session,
        shellId: 'sh_1',
        directory: _dir,
        maxBytes: 16 * 1024,
      );
      expect(pemPage, isNotNull);
      expect(utf8.encode(pemPage!.output).length, lessThanOrEqualTo(16 * 1024));
      expect(pemPage.output, isNot(contains('MIIEvQIBADAN')));
      expect(pemPage.output, isNot(contains('BEGIN PRIVATE KEY')));
      expect(pemPage.output, contains('[redacted]'));
      expect(pemPage.hasMore, isTrue);

      // Nonzero cursor paging (cursor=16384) carries prior context from byte 0
      // so the tail of the split PEM block NEVER leaks on page 2, and advances
      // an honest raw source cursor.
      final page2 = await client.readOutput(
        session: _session,
        shellId: 'sh_1',
        directory: _dir,
        cursor: 16 * 1024,
        limit: 16 * 1024,
      );
      expect(page2, isNotNull);
      expect(page2!.output, isNot(contains('MIIEvQIBADAN')));
      expect(page2.output, isNot(contains('END PRIVATE KEY')));
      expect(page2.output, contains('after-pem'));
      expect(page2.cursor, crossPem.length);

      // Multi-byte UTF-8 boundary alignment: page cursor lands on exact rune
      // boundary (never mid-emoji), and expanding redaction does not drop text.
      const emojiText = 'token=a 😀tail\n';
      nextPayload = _located({
        'output': emojiText,
        'cursor': utf8.encode(emojiText).length,
        'size': utf8.encode(emojiText).length,
        'truncated': false,
      });
      final aligned = await client.readOutput(
        session: _session,
        shellId: 'sh_1',
        directory: _dir,
        cursor: 0,
        limit: 10, // 'token=a ' is 8 bytes, '😀' is 4 bytes (bytes 8..12)
      );
      expect(aligned, isNotNull);
      // Expanding 'token=a' -> 'token=[redacted]' (16 bytes > limit 10) is NOT clipped!
      expect(aligned!.output, 'token=[redacted] ');
      // Raw cursor lands cleanly at byte 8 (before '😀'), never at byte 10!
      expect(aligned.cursor, 8);
    },
  );

  test(
    'reconcileHydration runs GETs concurrently, drops confirmed 404, and preserves transient error as unconfirmed',
    () async {
      var inFlightGets = 0;
      var maxConcurrentGets = 0;
      final bothStarted = Completer<void>();
      final transport = _FakeTransport((req) async {
        final uri = Uri.parse(req.path);
        final dir = uri.queryParameters['location[directory]'] ?? _dir;
        if (uri.path == 'api/shell') {
          return _jsonResponse(
            _located([_rawShell('sh_still_running')], directory: dir),
          );
        }
        if (uri.path == 'api/shell/sh_finished' ||
            uri.path == 'api/shell/sh_flaky') {
          inFlightGets++;
          if (inFlightGets > maxConcurrentGets) {
            maxConcurrentGets = inFlightGets;
          }
          if (inFlightGets >= 2 && !bothStarted.isCompleted) {
            bothStarted.complete();
          }
          await bothStarted.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () {},
          );
          inFlightGets--;
          if (uri.path == 'api/shell/sh_finished') {
            return _jsonResponse(
              _located({
                ..._rawShell('sh_finished', status: 'exited'),
                'exit': 0,
                'time': {'started': 1760000000000, 'completed': 1760000005000},
              }, directory: dir),
            );
          }
          return _jsonResponse({'error': 'temporary 503'}, status: 503);
        }
        return _jsonResponse({'error': 'not found'}, status: 404);
      });
      final client = OpenCodeShellClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
      );
      ShellWork prior(String id) => ShellWork(
        id: id,
        owner: const SessionOwner(_session),
        command: 'echo $id',
        status: const OpenValue.known(ShellStatus.running),
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          1760000000000,
          isUtc: true,
        ),
      );
      final res = await client.reconcileHydration(
        session: _session,
        directory: _dir,
        residentShells: [
          prior('sh_finished'),
          prior('sh_flaky'),
          prior('sh_gone_404'),
        ],
        knownLocations: const {
          'sh_finished': '/workspace/sub',
          'sh_flaky': '/workspace/other',
        },
      );
      expect(maxConcurrentGets, greaterThanOrEqualTo(2));
      expect(res.shells.map((s) => s.id), [
        'sh_finished',
        'sh_flaky',
        'sh_still_running',
      ]);
      expect(
        res.shells.firstWhere((s) => s.id == 'sh_finished').status.known,
        ShellStatus.exited,
      );
      // Transient 503 preserves sh_flaky as unconfirmed and keeps its location!
      expect(
        res.shells.firstWhere((s) => s.id == 'sh_flaky').status.known,
        isNull,
      );
      expect(res.locations['sh_flaky'], '/workspace/other');
      // Confirmed 404 removes sh_gone_404.
      expect(res.shells.any((s) => s.id == 'sh_gone_404'), isFalse);
      expect(res.locations['sh_finished'], '/workspace/sub');
      expect(res.locations['sh_still_running'], _dir);
    },
  );

  test(
    'OpenCodeStreamOwner handles post-release hydrating terminal burst, 1-time shell retry, concurrent refreshShells mutations, and dropShell guards',
    () async {
      const session2 = SessionRef(
        HostId('host'),
        HarnessInstanceId('inst'),
        'ses_b',
      );
      final hydrateGate2 = Completer<void>();
      final refreshGate = Completer<void>();
      var holdNextShellList = false;
      var shellListCallsSesA = 0;
      var fullHydrateCallsSesA = 0;
      final transport = _FakeTransport((req) async {
        final uri = Uri.parse(req.path);
        final path = uri.path;
        if (path == 'api/session/active') {
          return _jsonResponse({'data': <String, Object?>{}});
        }
        if (path == 'api/session/ses_a') {
          fullHydrateCallsSesA++;
          return _jsonResponse({
            'data': {
              'id': 'ses_a',
              'title': 'Demo A',
              'directory': _dir,
              'projectID': 'prj_1',
              'time': {'created': 1760000000000, 'updated': 1760000000000},
            },
          });
        }
        if (path == 'api/session/ses_b') {
          await hydrateGate2.future;
          return _jsonResponse({
            'data': {
              'id': 'ses_b',
              'title': 'Demo B',
              'directory': _dir,
              'projectID': 'prj_1',
              'time': {'created': 1760000000000, 'updated': 1760000000000},
            },
          });
        }
        if (path.endsWith('/inbox') ||
            path.endsWith('/permission') ||
            path.endsWith('/form')) {
          return _jsonResponse({'data': <Object?>[]});
        }
        if (path.endsWith('/message')) {
          return _jsonResponse({
            'data': <Object?>[],
            'cursor': {'previous': null, 'next': null},
          });
        }
        if (path == 'api/shell') {
          shellListCallsSesA++;
          if (shellListCallsSesA == 1) {
            return _jsonResponse({'error': 'transient'}, status: 503);
          }
          if (holdNextShellList) {
            holdNextShellList = false;
            await refreshGate.future;
            // Stale list still thinks sh_recovered & sh_to_stop are running,
            // and does NOT know about sh_live_created yet.
            return _jsonResponse(
              _located([_rawShell('sh_recovered'), _rawShell('sh_to_stop')]),
            );
          }
          return _jsonResponse(
            _located([_rawShell('sh_recovered'), _rawShell('sh_to_stop')]),
          );
        }
        return _jsonResponse({'error': 'not found'}, status: 404);
      });

      final sse = _FakeSse();
      final store = SessionStore(maxSessions: 4);
      final reader = OpenCodeSessionReader(transport, harness: _harness);
      final owner = OpenCodeStreamOwner(
        connection: sse,
        reader: reader,
        store: store,
        harness: _harness,
        sourceVersion: '2.0.22',
        observeShells: true,
        maxHeldFrames: 4,
        delay: (_) async {},
      );
      addTearDown(() async {
        await owner.close();
        reader.dispose();
      });

      owner.start();
      owner.watch(_session);
      // dropShell before connected (_generation == null) is safely ignored.
      owner.dropShell(_session, 'sh_none');

      // Connect and release generation 1 on ses_a (first /api/shell 503 ->
      // 1-time shell retry recovers sh_recovered & sh_to_stop).
      sse.connect(1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(store.read(_session)?.connection.kind.known, ConnectionKind.live);
      expect(
        store.read(_session)!.shells.map((s) => s.id),
        containsAll(['sh_recovered', 'sh_to_stop']),
      );

      // Now watch ses_b AFTER generation 1 is released (_released == true)
      // while ses_b is genuinely hydrating (!watch2.ready), so SseBatch frames
      // actually traverse _onFrame -> _routeShell -> watch2.heldShellTerminals!
      owner.watch(session2);
      await Future<void>.delayed(Duration.zero);

      // 1) Unsafe shell ID rejected before queueing.
      sse.send({
        'type': 'shell.exited',
        'id': 'evt_bad',
        'data': {'id': 'sh_a/b', 'status': 'exited', 'exit': 0},
      });
      // 2) Flood 80 foreign shell.deleted frames — isolated from maxHeldFrames=4!
      for (var i = 0; i < 80; i++) {
        sse.send({
          'type': 'shell.deleted',
          'id': 'evt_f_$i',
          'data': {'id': 'sh_foreign_$i'},
        });
      }
      // 3) Interleave shell.created(sh_inter), shell.exited(sh_inter), and
      //    shell.created(sh_after) for ses_b while hydrating.
      sse.send({
        'type': 'shell.created',
        'id': 'evt_c1',
        'location': {'directory': '/workspace/sub'},
        'data': {'info': _rawShell('sh_inter', sessionId: 'ses_b')},
      });
      sse.send({
        'type': 'shell.exited',
        'id': 'evt_e1',
        'created': 1760000005000,
        'data': {'id': 'sh_inter', 'status': 'exited', 'exit': 0},
      });
      sse.send({
        'type': 'shell.created',
        'id': 'evt_c2',
        'location': {'directory': '/workspace/other'},
        'data': {'info': _rawShell('sh_after', sessionId: 'ses_b')},
      });
      // dropShell during hydration marks dirty without crashing or emitting null epoch.
      owner.dropShell(session2, 'sh_while_hydrating');

      hydrateGate2.complete();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(store.read(session2)?.connection.kind.known, ConnectionKind.live);
      final bShells = store.read(session2)!.shells;
      expect(
        bShells.firstWhere((s) => s.id == 'sh_inter').status.known,
        ShellStatus.exited,
      );
      expect(bShells.any((s) => s.id == 'sh_after'), isTrue);
      expect(owner.shellDirectoryOf('sh_inter'), '/workspace/sub');
      expect(owner.shellDirectoryOf('sh_after'), '/workspace/other');

      // Concurrent refreshShells race protection on ses_a:
      // While refreshShells is awaiting a stale list, concurrently:
      // - sh_to_stop is stopped via dropShell
      // - sh_recovered exits via SSE
      // - sh_live_created is created via SSE
      final hydratesBefore = fullHydrateCallsSesA;
      holdNextShellList = true;
      final refreshing = owner.refreshShells(_session);
      await Future<void>.delayed(Duration.zero);

      owner.dropShell(_session, 'sh_to_stop');
      sse.send({
        'type': 'shell.exited',
        'id': 'evt_race_exit',
        'created': 1760000008000,
        'data': {'id': 'sh_recovered', 'status': 'exited', 'exit': 0},
      });
      sse.send({
        'type': 'shell.created',
        'id': 'evt_race_new',
        'data': {'info': _rawShell('sh_live_created')},
      });
      await Future<void>.delayed(Duration.zero);

      refreshGate.complete();
      await refreshing;

      // No full re-hydration occurred; stale refresh neither resurrected
      // sh_to_stop, reverted sh_recovered to running, nor erased sh_live_created!
      expect(fullHydrateCallsSesA, hydratesBefore);
      final afterRace = store.read(_session)!.shells;
      expect(afterRace.any((s) => s.id == 'sh_to_stop'), isFalse);
      expect(
        afterRace.firstWhere((s) => s.id == 'sh_recovered').status.known,
        ShellStatus.exited,
      );
      expect(afterRace.any((s) => s.id == 'sh_live_created'), isTrue);

      // shell.deleted clears adapter-private location tracking.
      sse.send({
        'type': 'shell.deleted',
        'id': 'evt_del_inter',
        'data': {'id': 'sh_inter'},
      });
      await Future<void>.delayed(Duration.zero);
      expect(owner.shellDirectoryOf('sh_inter'), isNull);
    },
  );
}
