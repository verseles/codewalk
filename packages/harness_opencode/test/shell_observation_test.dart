import 'dart:collection';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:harness_opencode/src/tool_metadata.dart';
import 'package:test/test.dart';

const _host = HostId('host');
const _instance = HarnessInstanceId('inst');
const _session = SessionRef(_host, _instance, 'ses_target');

StreamPosition _pos(int seq) =>
    StreamPosition(id: 'stream', epoch: 'e1', seq: BigInt.from(seq));

final class _PrivateMap extends MapBase<String, Object?> {
  _PrivateMap(this._inner, this._forbidden);
  final Map<String, Object?> _inner;
  final Set<String> _forbidden;

  @override
  Object? operator [](Object? key) {
    if (_forbidden.contains(key)) {
      throw StateError('Forbidden host-private field "$key" was read');
    }
    return _inner[key];
  }

  @override
  void operator []=(String key, Object? value) => _inner[key] = value;

  @override
  void clear() => _inner.clear();

  @override
  Iterable<String> get keys => {..._inner.keys, ..._forbidden};

  @override
  Object? remove(Object? key) => _inner.remove(key);
}

Map<String, Object?> _shellInfo({
  String id = 'sh_01abc',
  String status = 'running',
  String command = 'npm run dev',
  String? sessionId = 'ses_target',
  Object? exit,
  String? signal,
  num started = 1760000000000,
  num? completed,
}) => _PrivateMap(
  {
    'id': id,
    'status': status,
    'command': command,
    'exit': ?exit,
    'signal': ?signal,
    'metadata': {'sessionID': ?sessionId},
    'time': {'started': started, 'completed': ?completed},
  },
  {'file', 'cwd', 'pid', 'shell'},
);

void main() {
  test(
    'openCodeShellId validates prefix, UTF-8 bounds, surrogates, and path safety',
    () {
      expect(openCodeShellId('sh_abc123'), 'sh_abc123');
      for (final bad in [
        null,
        '',
        'sh_',
        'abc_123',
        'sh_a/b',
        'sh_a\\b',
        'sh_a\nb',
        'sh_${String.fromCharCode(0xd800)}',
      ]) {
        expect(
          () => openCodeShellId(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(() => openCodeShellId('sh_${'€' * 2000}'), throwsRangeError);
    },
  );

  test(
    'openCodeShellInfoToWork filters strictly by session, redacts command, and ignores host-private fields',
    () {
      final matched = openCodeShellInfoToWork(
        _shellInfo(
          command: 'curl --token supersecret123456 https://example.com',
        ),
        session: _session,
        sourceVersion: '2.0.22',
      );
      expect(matched, isNotNull);
      expect(matched!.id, 'sh_01abc');
      expect(matched.status.known, ShellStatus.running);
      expect(matched.command, isNot(contains('supersecret123456')));
      expect(matched.command, contains('[redacted]'));
      expect(
        matched.startedAt,
        DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true),
      );

      // Foreign or untagged shells return null without touching private keys.
      expect(
        openCodeShellInfoToWork(
          _shellInfo(sessionId: 'ses_other'),
          session: _session,
          sourceVersion: '2.0.22',
        ),
        isNull,
      );
      expect(
        openCodeShellInfoToWork(
          _shellInfo(sessionId: null),
          session: _session,
          sourceVersion: '2.0.22',
        ),
        isNull,
      );
    },
  );

  test(
    'projectOpenCodeShellLifecycleEvent projects created, exited, and deleted isolated from work',
    () {
      var state = SessionState(_session, streamPosition: _pos(0));

      // Foreign shell.created is ignored.
      expect(
        projectOpenCodeShellLifecycleEvent(
          {
            'type': 'shell.created',
            'id': 'evt_f',
            'data': {
              'info': _shellInfo(id: 'sh_foreign', sessionId: 'ses_other'),
            },
          },
          state,
          sourceVersion: '2.0.22',
          position: _pos(1),
          receivedAt: DateTime.utc(2026, 11, 19),
        ),
        isNull,
      );

      // Matching shell.created adds the running ShellWork.
      final created = projectOpenCodeShellLifecycleEvent(
        {
          'type': 'shell.created',
          'id': 'evt_1',
          'data': {'info': _shellInfo(id: 'sh_live1')},
        },
        state,
        sourceVersion: '2.0.22',
        position: _pos(2),
        receivedAt: DateTime.utc(2026, 11, 19),
      )!;
      state = reduce(state, created).state;
      expect(state.shells, hasLength(1));
      expect(state.shells.single.id, 'sh_live1');
      expect(state.shells.single.isRunning, isTrue);

      // Exited for untracked ID is ignored.
      expect(
        projectOpenCodeShellLifecycleEvent(
          {
            'type': 'shell.exited',
            'id': 'evt_u',
            'data': {'id': 'sh_unknown', 'status': 'exited', 'exit': 0},
          },
          state,
          sourceVersion: '2.0.22',
          position: _pos(3),
          receivedAt: DateTime.utc(2026, 11, 19),
        ),
        isNull,
      );

      // Exited for tracked ID transitions status and exitCode.
      final exited = projectOpenCodeShellLifecycleEvent(
        {
          'type': 'shell.exited',
          'id': 'evt_2',
          'created': 1760000005000,
          'data': {'id': 'sh_live1', 'status': 'exited', 'exit': 2},
        },
        state,
        sourceVersion: '2.0.22',
        position: _pos(4),
        receivedAt: DateTime.utc(2026, 11, 19),
      )!;
      state = reduce(state, exited).state;
      expect(state.shells.single.status.known, ShellStatus.exited);
      expect(state.shells.single.exitCode, 2);
      expect(
        state.shells.single.completedAt,
        DateTime.fromMillisecondsSinceEpoch(1760000005000, isUtc: true),
      );

      // Deleted removes the tracked ID.
      final deleted = projectOpenCodeShellLifecycleEvent(
        {
          'type': 'shell.deleted',
          'id': 'evt_3',
          'data': {'id': 'sh_live1'},
        },
        state,
        sourceVersion: '2.0.22',
        position: _pos(5),
        receivedAt: DateTime.utc(2026, 11, 19),
      )!;
      state = reduce(state, deleted).state;
      expect(state.shells, isEmpty);
    },
  );

  test('openCodeShellCapabilities verifies v2 versions only', () {
    final v2 = openCodeShellCapabilities('2.0.22');
    expect(v2[ShellCapabilities.observe]?.isAvailable, isTrue);
    expect(v2[ShellCapabilities.stop]?.isAvailable, isTrue);

    final v1 = openCodeShellCapabilities('1.9.0');
    expect(v1[ShellCapabilities.observe]?.isAvailable, isFalse);
    expect(v1[ShellCapabilities.stop]?.isAvailable, isFalse);
  });

  test(
    'openCodeCheckedShellText, 64 KiB command limit, openCodeShellFrameDirectory, and ShellRun.shellId projection',
    () {
      // Surrogates and byte-cap checks.
      expect(openCodeCheckedShellText('ok 😀', 16), 'ok 😀');
      expect(
        () => openCodeCheckedShellText(String.fromCharCode(0xd800), 16),
        throwsFormatException,
      );
      expect(
        () => openCodeCheckedShellText(String.fromCharCode(0xdc00), 16),
        throwsFormatException,
      );
      expect(() => openCodeCheckedShellText('€€€', 5), throwsRangeError);

      // 64 KiB command accepted; > 64 KiB rejected.
      final cmd64k = 'a' * (64 * 1024);
      final ok = openCodeShellInfoToWork(
        _shellInfo(command: cmd64k),
        session: _session,
        sourceVersion: '2.0.22',
      );
      expect(ok?.command.length, 64 * 1024);
      expect(
        () => openCodeShellInfoToWork(
          _shellInfo(command: '${cmd64k}x'),
          session: _session,
          sourceVersion: '2.0.22',
        ),
        throwsRangeError,
      );

      // Frame directory extraction validates text and ignores malformed values.
      expect(
        openCodeShellFrameDirectory({
          'location': {'directory': '/workspace/sub'},
        }),
        '/workspace/sub',
      );
      expect(openCodeShellFrameDirectory({'location': {}}), isNull);
      expect(
        openCodeShellFrameDirectory({
          'location': {'directory': ''},
        }),
        isNull,
      );
      expect(
        openCodeShellFrameDirectory({
          'location': {'directory': String.fromCharCode(0xd800)},
        }),
        isNull,
      );

      // Durable shell projection populates canonical ShellRun.shellId.
      final state = SessionState(_session, streamPosition: _pos(0));
      final events = projectOpenCodeShellEvent(
        {
          'type': 'session.shell.started',
          'id': 'evt_1',
          'created': 1760000000000,
          'durable': {'aggregateID': 'ses_target', 'version': 1, 'seq': 1},
          'data': {
            'sessionID': 'ses_target',
            'shell': {
              'id': 'sh_proj1',
              'status': 'running',
              'command': 'echo hi',
              'cwd': '/tmp',
              'shell': '/bin/sh',
              'file': '/tmp/out.log',
              'metadata': {'sessionID': 'ses_target'},
              'time': {'started': 1760000000000},
            },
          },
        },
        state,
        sourceVersion: '2.0.22',
        position: _pos(1),
        receivedAt: DateTime.utc(2026, 11, 19),
      );
      final run = (events.single as ItemUpserted).item as ShellRun;
      expect(run.shellId, 'sh_proj1');

      // Shell background tool output strips OpenCode's host capture-file path
      // in both live tool projection and history projection.
      const bgText =
          'Command moved to the background (shell ID: sh_bg1).\n'
          'Output is streaming to: /tmp/opencode-secret-capture/sh_bg1.log';
      expect(
        openCodeSanitizeShellToolOutputText(bgText),
        'Command moved to the background (shell ID: sh_bg1).',
      );
      // Ordinary user shell output mentioning the phrase is left intact.
      const userText = 'log\nOutput is streaming to: stdout\n';
      expect(openCodeSanitizeShellToolOutputText(userText), userText);
      final hist = projectOpenCodeHistory(
        [
          {
            'id': 'msg_1',
            'type': 'assistant',
            'time': {'created': 1760000000000, 'completed': 1760000001000},
            'content': [
              {
                'type': 'tool',
                'id': 'call_1',
                'name': 'shell',
                'time': {'created': 1760000000000},
                'state': {
                  'status': 'completed',
                  'input': {'command': 'tail -f log', 'background': true},
                  'content': [
                    {'type': 'text', 'text': bgText},
                  ],
                  'metadata': {
                    'shellID': 'sh_bg1',
                    'status': 'running',
                    'truncated': false,
                  },
                },
              },
            ],
          },
        ],
        _session,
        sourceVersion: '2.0.22',
      );
      final histTool = hist.whereType<ToolCall>().single;
      final outJson = histTool.output?.toJson().toString() ?? '';
      expect(outJson, contains('sh_bg1'));
      expect(outJson, isNot(contains('opencode-secret-capture')));
      expect(outJson, isNot(contains('Output is streaming to:')));

      // v2.3+ PID line + interrupted capture path stripping.
      const bgWithPid =
          'Command moved to the background (shell ID: sh_bg2).\n'
          'PID: 4242\n'
          'Output is streaming to: /tmp/opencode/sh_bg2.log';
      expect(
        openCodeSanitizeShellToolOutputText(bgWithPid),
        'Command moved to the background (shell ID: sh_bg2).',
      );
      expect(
        openCodeSanitizeShellToolOutputText(
          'partial\n[full output saved to /tmp/opencode/cap.log]',
        ),
        'partial',
      );
      expect(
        openCodeSanitizeShellToolOutputText(
          '[no output; output file: /tmp/opencode/cap.log]',
        ),
        '',
      );

      // Legacy v1-migrated tool aliases and killed/signal shell tool facts.
      expect(openCodeToolKind('bash'), ToolKind.shell);
      expect(openCodeToolKind('apply_patch'), ToolKind.edit);
      expect(openCodeToolKind('task'), ToolKind.subagent);

      final killedFacts = openCodeShellToolRunFacts(
        const {'killed': true, 'signal': 'SIGKILL', 'exit': 137},
      );
      expect(killedFacts?.shellStatus?.known, ShellStatus.killed);
      expect(killedFacts?.exitCode, 137);
    },
  );
}
