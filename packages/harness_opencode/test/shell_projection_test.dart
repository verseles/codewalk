import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-derived synthetic shell inputs, not captures. The shapes follow the
// pinned schemas `plan/opencode-v2-src/schema/shell.ts` (Info, Output,
// Status), `schema/session-event.ts` (session.shell.started/ended, durable
// version 1) and `schema/session-message.ts` (Session.Message.Shell), which
// are byte-identical at OpenCode 2.0.22 commit
// 05018b8862a8fc198ec9810aafd397c96bb7d86e. The server's own reducer inserts
// the shell message on start with an event-derived message ID and updates it
// on end by shell ID (`client-solid-data.reference-reducer.ts:815-837`). No
// recorded 2.0.22 capture contains a shell message or shell event; the guard
// test below keeps that gap visible.

Matcher failsWith(OpenCodeShellProjectionFailure failure) => throwsA(
  isA<OpenCodeShellProjectionException>().having(
    (e) => e.failure,
    'failure',
    failure,
  ),
);

Map<String, Object?> shellInfo({
  String id = 'sh_one',
  String status = 'running',
  String command = 'ls -la',
  Object? exit,
}) => {
  'id': id,
  'status': status,
  'command': command,
  'cwd': '/fake-private-cwd',
  'shell': '/bin/sh',
  'file': '/fake-private-capture',
  'pid': 42,
  'exit': ?exit,
  'metadata': {'secret': 'fake-private-metadata'},
  'time': {'started': 1000, if (status != 'running') 'completed': 2000},
};

Map<String, Object?> shellFrame(
  String type, {
  String id = 'evt_shellstart',
  Map<String, Object?>? shell,
  Map<String, Object?>? output,
  int version = 1,
}) => {
  'id': id,
  'created': 1000,
  'type': type,
  'location': {'directory': '/fake-private-location'},
  'data': <String, Object?>{
    'sessionID': 'ses_a',
    'shell': shell ?? shellInfo(),
    if (type == 'session.shell.ended')
      'output':
          output ??
          {'output': 'total 0\n', 'cursor': 8, 'size': 8, 'truncated': false},
  },
  'durable': <String, Object?>{
    'aggregateID': 'ses_a',
    'seq': 3,
    'version': version,
  },
};

List<SessionEvent> projectShell(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String version = '2.0.22',
}) => projectOpenCodeShellEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 21),
);

ShellRun shellOf(List<SessionEvent> events) =>
    (events.single as ItemUpserted).item as ShellRun;

ShellRun history(Map<String, Object?> fields) =>
    projectOpenCodeHistory(
          [message('shell', 'shell', fields)],
          historyRef,
          sourceVersion: '2.0.22',
        ).single
        as ShellRun;

void main() {
  test('a start inserts a running row and its end completes it', () {
    final started = projectShell(shellFrame('session.shell.started'));
    final running = shellOf(started);
    expect(running.command, 'ls -la');
    expect(running.shellStatus!.known, ShellStatus.running);
    expect(running.status.known, ItemStatus.streaming);
    expect(running.outputText, isNull);
    expect(running.output!.id, 'sh_one');
    final state = reduce(SessionState(historyRef), started.single).state;

    final ended = projectShell(
      shellFrame(
        'session.shell.ended',
        id: 'evt_shellend',
        shell: shellInfo(status: 'exited', exit: 0),
      ),
      current: state,
      seq: 2,
    );
    final done = shellOf(ended);
    expect(done.id, running.id);
    expect(done.status.known, ItemStatus.completed);
    expect(done.exitCode, 0);
    expect(done.outputText, 'total 0\n');
    expect(done.output!.sizeBytes, 8);
    expect(done.output!.truncated, isFalse);
    final extra = ended.single.meta.source.extra!.value! as Map;
    expect(extra['nativeMessageId'], 'msg_shellstart');
    expect(extra['nativeShellId'], 'sh_one');
    final manifest = ended.single.meta.source.extra.toString();
    expect(manifest, isNot(contains('fake-private')));
  });

  test('the live row has the identity of the history row', () {
    final live = shellOf(projectShell(shellFrame('session.shell.started')));
    final row = history({
      'shellID': 'sh_one',
      'command': 'ls -la',
      'status': 'running',
      'time': {'created': 1000},
    });
    // The message ID the server derives from the start event.
    expect(
      projectOpenCodeHistory(
        [
          {
            ...message('shellstart', 'shell'),
            'shellID': 'sh_one',
            'command': 'ls -la',
            'status': 'running',
          },
        ],
        historyRef,
        sourceVersion: '2.0.22',
      ).single.id,
      live.id,
    );
    expect(row.command, live.command);
  });

  test('an end without its start asks for a re-read', () {
    expect(
      () => projectShell(
        shellFrame(
          'session.shell.ended',
          shell: shellInfo(status: 'exited', exit: 0),
        ),
      ),
      failsWith(OpenCodeShellProjectionFailure.missingStart),
    );
  });

  test('an unknown durable version or status fails closed', () {
    expect(
      () => projectShell(shellFrame('session.shell.started', version: 2)),
      failsWith(OpenCodeShellProjectionFailure.unsupportedVersion),
    );
    expect(
      () => projectShell(
        shellFrame('session.shell.started', shell: shellInfo(status: 'paused')),
      ),
      failsWith(OpenCodeShellProjectionFailure.malformed),
    );
    expect(
      () => projectShell(
        shellFrame(
          'session.shell.started',
          shell: {...shellInfo(), 'exit': 'NaN'},
        ),
      ),
      failsWith(OpenCodeShellProjectionFailure.malformed),
    );
    expect(
      () =>
          projectShell(shellFrame('session.shell.started'), version: '2.0.21'),
      failsWith(OpenCodeShellProjectionFailure.unsupportedVersion),
    );
  });

  test('history keeps the outcome, the exit token and a bounded output', () {
    final failed = history({
      'shellID': 'sh_a',
      'command': 'make',
      'status': 'exited',
      'exit': 2,
      'output': {
        'output': 'error\n',
        'cursor': 6,
        'size': 6,
        'truncated': false,
      },
      'time': {'created': 1000, 'completed': 2000},
    });
    expect(failed.status.known, ItemStatus.failed);
    expect(failed.exitCode, 2);
    expect(failed.outputText, 'error\n');

    final timeout = history({
      'shellID': 'sh_b',
      'command': 'sleep 99',
      'status': 'timeout',
      'exit': 'NaN',
      'output': {
        'output': 'partial',
        'cursor': 7,
        'size': 4096,
        'truncated': true,
      },
      'time': {'created': 1000, 'completed': 2000},
    });
    expect(timeout.status.known, ItemStatus.failed);
    expect(timeout.exitCode, isNull);
    expect(timeout.exitToken, 'NaN');
    expect(timeout.output!.truncated, isTrue);
    expect(timeout.output!.sizeBytes, 4096);

    final killed = history({
      'shellID': 'sh_c',
      'command': 'yes',
      'status': 'killed',
      'time': {'created': 1000},
    });
    expect(killed.status.known, ItemStatus.interrupted);
    expect(killed.outputText, isNull);

    final big = history({
      'shellID': 'sh_d',
      'command': 'cat big',
      'status': 'exited',
      'exit': 0,
      'output': {
        'output': 'x' * (openCodeShellOutputLimit + 10),
        'cursor': openCodeShellOutputLimit + 10,
        'size': openCodeShellOutputLimit + 10,
        'truncated': false,
      },
      'time': {'created': 1000, 'completed': 2000},
    });
    expect(big.outputText!.length, openCodeShellOutputLimit);
    expect(big.output!.truncated, isTrue);
  });

  test('a shell row never keeps a credential', () {
    final row = history({
      'shellID': 'sh_e',
      'command': 'curl -H "Authorization: Bearer abcdefgh12345678" x',
      'status': 'exited',
      'exit': 0,
      'output': {
        'output': 'password=hunter2\nok\n',
        'cursor': 20,
        'size': 20,
        'truncated': false,
      },
      'time': {'created': 1000, 'completed': 2000},
    });
    expect(row.command, isNot(contains('abcdefgh12345678')));
    expect(row.outputText, 'password=[redacted]\nok\n');
    final extra = row.meta.source.extra!.value! as Map;
    expect(extra['commandRedacted'], isTrue);
    expect(extra['outputRedacted'], isTrue);
  });

  test('no recorded 2.0.22 capture contains a shell message or event', () {
    // The shell rows rest on the synthetic inputs above. When a capture
    // records one, replace this guard with a replay of it.
    final root = Directory('../../test/contract/fixtures/opencode/2.0.22');
    expect(root.existsSync(), isTrue);
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final text = file.readAsStringSync();
      expect(text, isNot(contains('session.shell.started')), reason: file.path);
      expect(text, isNot(contains('session.shell.ended')), reason: file.path);
      expect(text, isNot(contains(r'"type": "shell"')), reason: file.path);
      expect(text, isNot(contains(r'\"type\": \"shell\"')), reason: file.path);
    }
  });
}
