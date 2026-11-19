import 'dart:async';
import 'dart:convert';

import 'package:codewalk/platform/sessions/opencode_shell_lane.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_shells.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

const _harness = HarnessRef(HostId('h'), HarnessInstanceId('inst'));
const _session = SessionRef(HostId('h'), HarnessInstanceId('inst'), 'ses_1');
const _dir = '/workspace/demo';

final class _FakeTransport implements EndpointHttpTransport {
  _FakeTransport(this.handler);
  final FutureOr<TransportResponse> Function(
    TransportRequest,
    RequestCancellation?,
  )
  handler;
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
    return handler(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _resp(Object? body, {int status = 200}) => TransportResponse(
  statusCode: status,
  headers: const {
    'content-type': ['application/json'],
  },
  body: status == 204
      ? const Stream.empty()
      : Stream.value(utf8.encode(jsonEncode(body))),
  cancel: () {},
);

SessionLiveView _liveView({
  bool live = true,
  List<ShellWork> shells = const [],
}) => SessionLiveView(
  session: _session,
  phase: live ? SessionLivePhase.live : SessionLivePhase.reconnecting,
  state: hydrate(
    beginHydration(
      SessionState(
        _session,
        streamPosition: StreamPosition(id: 's', epoch: 'e', seq: BigInt.zero),
      ),
      generation: 'g1',
      readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
    ),
    SessionSnapshot(
      ref: _session,
      hydrationGeneration: 'g1',
      info: SnapshotValue(
        value: SessionInfo(
          ref: _session,
          title: 'Demo',
          ownership: OwnershipInfo.known(
            OwnershipKind.liveShared,
            proof: OwnershipProof(
              source: 'test',
              observedAt: DateTime.utc(2026, 11, 19),
            ),
          ),
          project: ProjectRef(_harness.host, _dir),
        ),
        boundary: SnapshotBoundary(
          owner: const SessionOwner(_session),
          hydrationGeneration: 'g1',
          readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
          readStartedAt: DateTime.utc(2026, 11, 19),
          authority: const OpenValue.known(SnapshotAuthority.authoritative),
        ),
      ),
      shells: SnapshotCollection(
        values: shells,
        boundary: SnapshotBoundary(
          owner: const SessionOwner(_session),
          hydrationGeneration: 'g1',
          readStart: StreamPosition(id: 's', epoch: 'e', seq: BigInt.one),
          readStartedAt: DateTime.utc(2026, 11, 19),
          readCompletedAt: DateTime.utc(2026, 11, 19, 0, 0, 1),
          authority: const OpenValue.known(SnapshotAuthority.authoritative),
        ),
        complete: true,
      ),
    ),
  ).state,
);

ShellWork _shell(String id) => ShellWork(
  id: id,
  owner: const SessionOwner(_session),
  command: 'npm test',
  status: const OpenValue.known(ShellStatus.running),
  startedAt: DateTime.utc(2026, 11, 19),
  source: SourceProvenance(
    harness: _harness,
    version: '2.0.22',
    nativeType: 'shell.list',
  ),
);

void main() {
  test(
    'OpenCodeShellLane enforces single-flight stop, drops on 204/404, and forwards output cancellation',
    () async {
      final gate = Completer<void>();
      var stopStatus = 204;
      var outputStatus = 200;
      final cancelledTokens = <bool>[];
      final transport = _FakeTransport((req, cancel) async {
        if (req.method == 'DELETE') {
          await gate.future;
          return _resp(null, status: stopStatus);
        }
        if (cancel != null) {
          cancel.onCancel.listen((_) => cancelledTokens.add(true));
        }
        if (outputStatus == 404) return _resp({'error': 'gone'}, status: 404);
        return _resp({
          'location': {'directory': _dir},
          'data': {
            'output': 'hello\n',
            'cursor': 6,
            'size': 12,
            'truncated': false,
          },
        });
      });

      var publishes = 0;
      var refreshes = 0;
      final dropped = <String>[];
      var seq = 0;
      final lane = OpenCodeShellLane(
        client: OpenCodeShellClient(
          transport,
          harness: _harness,
          connectedVersion: '2.0.22',
        ),
        connectedVersion: '2.0.22',
        commandIds: () => CommandId('cmd_${++seq}'),
        view: (_) => _liveView(shells: [_shell('sh_1'), _shell('sh_2')]),
        publish: (_) => publishes++,
        refreshShells: (_) async => refreshes++,
        dropLocalShell: (_, id) => dropped.add(id),
        currentBinding: () => true,
      );
      final port = lane.port(_session, () => true);
      expect(port.canObserve, isTrue);
      expect(port.canStop, isTrue);

      await port.refresh();
      expect(refreshes, 1);

      // Output paging succeeds and respects cancellation / 404.
      final page = await port.readOutput('sh_1', cursor: 0);
      expect(page?.output, 'hello\n');
      expect(page?.hasMore, isTrue);

      final preCancelled = SessionShellCancellation()..cancel();
      expect(await port.readOutput('sh_1', cancellation: preCancelled), isNull);

      outputStatus = 404;
      expect(await port.readOutput('sh_1'), isNull);

      // Single-flight stop fence: second concurrent call returns unavailable
      // without issuing a second DELETE request.
      final first = port.stop('sh_1');
      expect(port.isStopping('sh_1'), isTrue);
      final second = await port.stop('sh_1');
      expect(second, SessionShellStopOutcome.unavailable);
      expect(
        transport.requests.where((r) => r.method == 'DELETE'),
        hasLength(1),
      );
      gate.complete();
      expect(await first, SessionShellStopOutcome.accepted);
      expect(port.isStopping('sh_1'), isFalse);
      expect(dropped, ['sh_1']);
      expect(publishes, greaterThanOrEqualTo(2));

      // 404 also drops the stale shell cleanly.
      stopStatus = 404;
      expect(await port.stop('sh_2'), SessionShellStopOutcome.notFound);
      expect(dropped, ['sh_1', 'sh_2']);

      lane.release(_session);
      lane.close();
      expect(port.canObserve, isFalse);
      expect(port.canStop, isFalse);
    },
  );

  test(
    'OpenCodeShellLane disables observe/stop on unverified versions',
    () async {
      final transport = _FakeTransport((_, _) => _resp(null, status: 204));
      final lane = OpenCodeShellLane(
        client: OpenCodeShellClient(
          transport,
          harness: _harness,
          connectedVersion: '1.9.0',
        ),
        connectedVersion: '1.9.0',
        commandIds: () => const CommandId('c1'),
        view: (_) => _liveView(),
        publish: (_) {},
        refreshShells: (_) async {},
        dropLocalShell: (_, _) {},
        currentBinding: () => true,
      );
      final port = lane.port(_session, () => true);
      expect(port.canObserve, isFalse);
      expect(port.canStop, isFalse);
      expect(await port.readOutput('sh_1'), isNull);
      expect(await port.stop('sh_1'), SessionShellStopOutcome.unavailable);
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'OpenCodeShellLane verifies session ownership before output/DELETE, routes per-shell directory, and maps rejected/uncertain stop outcomes',
    () async {
      var stopStatus = 401;
      final transport = _FakeTransport((req, _) {
        final uri = Uri.parse(req.path);
        final dir = uri.queryParameters['location[directory]'] ?? _dir;
        if (req.method == 'GET' && uri.path == 'api/shell/sh_foreign') {
          return _resp({
            'location': {'directory': dir},
            'data': {
              'id': 'sh_foreign',
              'status': 'running',
              'command': 'echo foreign',
              'metadata': {'sessionID': 'ses_other'},
              'time': {'started': 1760000000000},
            },
          });
        }
        if (req.method == 'GET' && uri.path == 'api/shell/sh_verified') {
          return _resp({
            'location': {'directory': dir},
            'data': {
              'id': 'sh_verified',
              'status': 'running',
              'command': 'echo mine',
              'metadata': {'sessionID': 'ses_1'},
              'time': {'started': 1760000000000},
            },
          });
        }
        if (req.method == 'GET' && uri.path == 'api/shell/sh_verified/output') {
          return _resp({
            'location': {'directory': dir},
            'data': {
              'output': 'mine\n',
              'cursor': 5,
              'size': 5,
              'truncated': false,
            },
          });
        }
        if (req.method == 'DELETE') {
          return _resp(null, status: stopStatus);
        }
        return _resp({'error': 'not found'}, status: 404);
      });

      final dropped = <String>[];
      final lane = OpenCodeShellLane(
        client: OpenCodeShellClient(
          transport,
          harness: _harness,
          connectedVersion: '2.0.22',
        ),
        connectedVersion: '2.0.22',
        commandIds: () => const CommandId('c_own'),
        view: (_) =>
            _liveView(), // Empty resident shells -> must verify via GET
        publish: (_) {},
        refreshShells: (_) async {},
        dropLocalShell: (_, id) => dropped.add(id),
        currentBinding: () => true,
        shellDirectory: (id) =>
            id == 'sh_verified' ? '/workspace/subrepo' : null,
      );
      final port = lane.port(_session, () => true);

      // Foreign shell fails GET ownership check: neither /output nor DELETE is sent.
      expect(await port.readOutput('sh_foreign'), isNull);
      expect(
        await port.stop('sh_foreign'),
        SessionShellStopOutcome.unavailable,
      );
      expect(
        transport.requests.where(
          (r) => r.method == 'DELETE' || r.path.contains('/output'),
        ),
        isEmpty,
      );

      // Matching shell passes GET ownership check and uses per-shell directory
      // + contiguous readBoundedPrefix (limit = 16KiB + 4KiB).
      final page = await port.readOutput('sh_verified', cursor: 0);
      expect(page?.output, 'mine\n');
      final outReq = Uri.parse(
        transport.requests.lastWhere((r) => r.path.contains('/output')).path,
      );
      expect(
        outReq.queryParameters['location[directory]'],
        '/workspace/subrepo',
      );
      expect(outReq.queryParameters['limit'], '${16 * 1024 + 4096}');

      // 401 -> rejected, 500 -> uncertain; neither drops local shell.
      expect(await port.stop('sh_verified'), SessionShellStopOutcome.rejected);
      stopStatus = 500;
      expect(await port.stop('sh_verified'), SessionShellStopOutcome.uncertain);
      expect(dropped, isEmpty);

      // Transient 503 during unresident ownership check rethrows from readOutput
      // (never masquerading as 404 null) and maps stop to uncertain.
      final flakyTransport = _FakeTransport(
        (_, _) => _resp({'error': 'busy'}, status: 503),
      );
      final flakyLane = OpenCodeShellLane(
        client: OpenCodeShellClient(
          flakyTransport,
          harness: _harness,
          connectedVersion: '2.0.22',
        ),
        connectedVersion: '2.0.22',
        commandIds: () => const CommandId('c_flaky'),
        view: (_) => _liveView(),
        publish: (_) {},
        refreshShells: (_) async {},
        dropLocalShell: (_, _) {},
        currentBinding: () => true,
      );
      final flakyPort = flakyLane.port(_session, () => true);
      await expectLater(
        () => flakyPort.readOutput('sh_unknown'),
        throwsA(isA<OpenCodeSessionReadException>()),
      );
      expect(
        await flakyPort.stop('sh_unknown'),
        SessionShellStopOutcome.uncertain,
      );
    },
  );
}
