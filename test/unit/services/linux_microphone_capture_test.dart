import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:codewalk/presentation/services/linux_microphone_capture_io.dart';
import 'package:codewalk/presentation/services/linux_microphone_capture_types.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProcess implements Process {
  _FakeProcess({
    StreamController<List<int>>? stdout,
    StreamController<List<int>>? stderr,
    Completer<int>? exitCode,
  }) : stdoutController = stdout ?? StreamController<List<int>>(),
       stderrController = stderr ?? StreamController<List<int>>(),
       exitCodeCompleter = exitCode ?? Completer<int>();

  final StreamController<List<int>> stdoutController;
  final StreamController<List<int>> stderrController;
  final Completer<int> exitCodeCompleter;

  int killCount = 0;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  Future<int> get exitCode => exitCodeCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCount += 1;
    if (!exitCodeCompleter.isCompleted) {
      exitCodeCompleter.complete(-15);
    }
    return true;
  }

  void emit(List<int> bytes) {
    stdoutController.add(bytes);
  }

  void failPreAudio({required int exitCode, String stderr = ''}) {
    if (stderr.isNotEmpty) {
      stderrController.add(stderr.codeUnits);
    }
    unawaited(stdoutController.close());
    unawaited(stderrController.close());
    if (!exitCodeCompleter.isCompleted) {
      exitCodeCompleter.complete(exitCode);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StartedCall {
  _StartedCall(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}

void main() {
  late Directory tempDir;
  late String binDir;

  Future<void> writeExecutable(String name) async {
    final file = File('$binDir/$name');
    await file.writeAsBytes([1]);
    await Process.run('chmod', ['+x', file.path]);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cw_linux_mic_test');
    binDir = '${tempDir.path}/bin';
    await Directory(binDir).create(recursive: true);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  LinuxMicrophoneCapture buildCapture({
    required List<_FakeProcess> processes,
    required List<_StartedCall> calls,
    List<ProcessException>? spawnErrors,
    Duration handshakeTimeout = const Duration(milliseconds: 250),
  }) {
    var index = 0;
    return LinuxMicrophoneCapture(
      pathEnv: binDir,
      handshakeTimeout: handshakeTimeout,
      processStarter: (executable, arguments) async {
        calls.add(_StartedCall(executable, arguments));
        final hasError = spawnErrors != null && index < spawnErrors.length;
        final error = hasError ? spawnErrors[index] : null;
        index += 1;
        if (error != null) {
          throw error;
        }
        return processes.removeAt(0);
      },
    );
  }

  group('probe', () {
    test('reports ready when at least one backend exists on PATH', () async {
      await writeExecutable('arecord');
      final capture = LinuxMicrophoneCapture(pathEnv: binDir);
      expect(await capture.probe(), LinuxMicrophoneProbeStatus.ready);
    });

    test('reports backendMissing when PATH has no backends', () async {
      final capture = LinuxMicrophoneCapture(pathEnv: binDir);
      expect(await capture.probe(), LinuxMicrophoneProbeStatus.backendMissing);
    });
  });

  group('startPcmStream', () {
    test('throws typed backendMissing when no tool exists', () async {
      final capture = LinuxMicrophoneCapture(pathEnv: binDir);
      await expectLater(
        capture.startPcmStream(),
        throwsA(
          isA<LinuxMicrophoneCaptureException>().having(
            (error) => error.code,
            'code',
            'backendMissing',
          ),
        ),
      );
    });

    test('resolves candidates in priority order and pins argv', () async {
      await writeExecutable('parecord');
      await writeExecutable('pw-record');
      await writeExecutable('arecord');
      final calls = <_StartedCall>[];
      final first = _FakeProcess()..emit([1, 2]);
      final capture = buildCapture(processes: [first], calls: calls);

      final chunks = await capture
          .startPcmStream(sampleRate: 16000)
          .then((stream) => stream.take(1).toList());

      expect(calls, hasLength(1));
      expect(calls.single.executable, endsWith('/parecord'));
      expect(calls.single.arguments, [
        '--raw',
        '--format=s16le',
        '--rate=16000',
        '--channels=1',
        '--latency-msec=100',
      ]);
      expect(chunks.single, orderedEquals([1, 2]));
    });

    test(
      'falls back to pw-record with pinned argv when parecord spawn fails',
      () async {
        await writeExecutable('parecord');
        await writeExecutable('pw-record');
        final calls = <_StartedCall>[];
        final working = _FakeProcess()..emit([3, 4]);
        final capture = LinuxMicrophoneCapture(
          pathEnv: binDir,
          handshakeTimeout: const Duration(milliseconds: 250),
          processStarter: (executable, arguments) async {
            calls.add(_StartedCall(executable, arguments));
            if (executable.endsWith('parecord')) {
              // Simulate the binary vanishing between lookup and spawn.
              throw ProcessException(executable, arguments, 'No such file', 2);
            }
            return working;
          },
        );

        final stream = await capture.startPcmStream();
        final chunks = await stream.take(1).toList();

        expect(calls, hasLength(2));
        expect(calls[0].executable, endsWith('/parecord'));
        expect(calls[1].executable, endsWith('/pw-record'));
        expect(calls[1].arguments, [
          '--raw',
          '--format=s16',
          '--rate',
          '16000',
          '--channels',
          '1',
          '-',
        ]);
        expect(chunks.single, orderedEquals([3, 4]));
        expect(working.killCount, 0);
      },
    );

    test('pins arecord argv when it is the only backend', () async {
      await writeExecutable('arecord');
      final calls = <_StartedCall>[];
      final process = _FakeProcess()..emit([5, 6]);
      final capture = buildCapture(processes: [process], calls: calls);

      await capture.startPcmStream();

      expect(calls.single.executable, endsWith('/arecord'));
      expect(calls.single.arguments, [
        '-q',
        '-t',
        'raw',
        '-f',
        'S16_LE',
        '-r',
        '16000',
        '-c',
        '1',
      ]);
    });

    test('advances to next backend when one exits before audio', () async {
      await writeExecutable('parecord');
      await writeExecutable('pw-record');
      final calls = <_StartedCall>[];
      final deadParecord = _FakeProcess()
        ..failPreAudio(exitCode: 1, stderr: 'Connection refused');
      final working = _FakeProcess()
        ..emit([7, 8])
        ..emit([9, 10]);
      final capture = buildCapture(
        processes: [deadParecord, working],
        calls: calls,
      );

      final stream = await capture.startPcmStream();
      final chunks = await stream.take(2).toList();

      expect(calls.map((call) => call.executable.lastSegment()), [
        endsWith('parecord'),
        endsWith('pw-record'),
      ]);
      expect(chunks[0], orderedEquals([7, 8]));
      expect(chunks[1], orderedEquals([9, 10]));
    });

    test(
      'surfaces audioServerUnavailable after all candidates fail pre-audio',
      () async {
        await writeExecutable('parecord');
        await writeExecutable('pw-record');
        await writeExecutable('arecord');
        final calls = <_StartedCall>[];
        final capture = buildCapture(
          processes: [
            _FakeProcess()
              ..failPreAudio(exitCode: 1, stderr: 'pa_context_connect()'),
            _FakeProcess()
              ..failPreAudio(exitCode: 1, stderr: 'pw_context_connect'),
            _FakeProcess()
              ..failPreAudio(exitCode: 1, stderr: 'Connection refused'),
          ],
          calls: calls,
        );

        await expectLater(
          capture.startPcmStream(),
          throwsA(
            isA<LinuxMicrophoneCaptureException>()
                .having((e) => e.code, 'code', 'audioServerUnavailable')
                .having(
                  (e) => e.backend,
                  'backend',
                  LinuxCaptureBackend.arecord,
                ),
          ),
        );
        expect(calls, hasLength(3));
      },
    );

    test(
      'kills and advances on handshake timeout without any audio byte',
      () async {
        await writeExecutable('parecord');
        await writeExecutable('pw-record');
        final calls = <_StartedCall>[];
        final silentForever = _FakeProcess(); // never emits, never exits
        final working = _FakeProcess()..emit([11]);
        final capture = buildCapture(
          processes: [silentForever, working],
          calls: calls,
          handshakeTimeout: const Duration(milliseconds: 40),
        );

        final stream = await capture.startPcmStream();
        final chunk = await stream.first;

        expect(silentForever.killCount, greaterThanOrEqualTo(1));
        expect(chunk, orderedEquals([11]));
      },
    );

    test('maps permission-denied stderr to the denied code', () async {
      await writeExecutable('parecord');
      final capture = buildCapture(
        processes: [
          _FakeProcess()
            ..failPreAudio(exitCode: 1, stderr: 'Permission denied'),
        ],
        calls: [],
      );

      await expectLater(
        capture.startPcmStream(),
        throwsA(
          isA<LinuxMicrophoneCaptureException>().having(
            (error) => error.code,
            'code',
            'denied',
          ),
        ),
      );
    });

    test(
      'emits a typed stream error when the backend dies mid-stream',
      () async {
        await writeExecutable('parecord');
        final process = _FakeProcess()..emit([1, 1]);
        final capture = buildCapture(processes: [process], calls: []);

        final stream = await capture.startPcmStream();
        final received = <Uint8List>[];
        final errors = <Object>[];
        final done = Completer<void>();
        final subscription = stream.listen(
          received.add,
          onError: errors.add,
          onDone: done.complete,
        );

        await Future<void>.delayed(Duration.zero);
        expect(received, hasLength(1));
        expect(received.single, orderedEquals([1, 1]));

        process.failPreAudio(exitCode: 2, stderr: 'boom');
        await done.future;

        expect(errors, hasLength(1));
        expect(
          errors.single,
          isA<LinuxMicrophoneCaptureException>().having(
            (error) => error.code,
            'code',
            'captureFailed',
          ),
        );
        expect(process.killCount, 0);
        await subscription.cancel();
      },
    );

    test(
      'stop during probing cancels the request and prevents acceptance',
      () async {
        await writeExecutable('parecord');
        await writeExecutable('pw-record');
        final calls = <_StartedCall>[];
        final silentForever = _FakeProcess(); // never emits, never exits
        final working = _FakeProcess()..emit([21]);
        final capture = buildCapture(
          processes: [silentForever, working],
          calls: calls,
          handshakeTimeout: const Duration(milliseconds: 60),
        );

        final pending = capture.startPcmStream();
        // Cancel while the first candidate is still inside its handshake
        // window; the probe must never publish or spawn afterwards.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await capture.stop();

        await expectLater(
          pending,
          throwsA(
            isA<LinuxMicrophoneCaptureException>().having(
              (error) => error.code,
              'code',
              'captureFailed',
            ),
          ),
        );
        expect(calls, hasLength(1));
        expect(silentForever.killCount, greaterThanOrEqualTo(1));
        expect(working.killCount, 0);
      },
    );

    test(
      'stop kills the active capture exactly once and ends the stream',
      () async {
        await writeExecutable('parecord');
        final process = _FakeProcess()..emit([1, 2]);
        final capture = buildCapture(processes: [process], calls: []);

        final stream = await capture.startPcmStream();
        await capture.stop();
        await capture.stop();

        expect(process.killCount, 1);
        await expectLater(
          stream,
          emitsInOrder([
            orderedEquals([1, 2]),
            emitsDone,
          ]),
        );
      },
    );
  });

  group('classifyLinuxPreAudioFailure', () {
    test('uses locale-independent errno for spawn failures', () {
      expect(classifyLinuxPreAudioFailure(spawnErrorCode: 2), 'backendMissing');
      expect(classifyLinuxPreAudioFailure(spawnErrorCode: 13), 'denied');
      expect(classifyLinuxPreAudioFailure(spawnErrorCode: 5), 'captureFailed');
    });

    test('classifies localized-independent daemon errors from stderr', () {
      expect(
        classifyLinuxPreAudioFailure(
          exitCode: 1,
          stderrTail: 'pa_context_connect() falhou: Conexão recusada',
        ),
        'audioServerUnavailable',
      );
      expect(
        classifyLinuxPreAudioFailure(
          exitCode: 1,
          stderrTail: 'Device or resource busy',
        ),
        'deviceBusy',
      );
      expect(
        classifyLinuxPreAudioFailure(
          exitCode: 1,
          stderrTail: 'no soundcards found',
        ),
        'noInputDevice',
      );
      expect(
        classifyLinuxPreAudioFailure(exitCode: 1, stderrTail: '???'),
        'captureFailed',
      );
    });
  });
}

extension on String {
  // Small helper so expectations read like the executable names under test.
  String lastSegment() => split('/').last;
}
