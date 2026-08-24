import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'linux_microphone_capture_types.dart';

// Process-backed microphone capture for Linux desktop.
//
// The `record` plugin (record_linux) shells out to the external `parecord`
// binary and hard-fails with a raw ProcessException when it is absent
// (issue #158). This service owns the capture process directly instead and
// tries the same CLI backends in a deterministic order — parecord first to
// preserve record_linux parity for setups that already work, then the
// PipeWire-native pw-record, then ALSA's arecord as a last resort.
//
// A backend is accepted only after its process spawns AND produces its first
// PCM bytes within a short handshake window. Failures before the first byte
// advance to the next candidate; once audio is flowing the backend never
// changes mid-session.
typedef LinuxProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

class LinuxMicrophoneCapture implements LinuxMicrophoneCaptureService {
  LinuxMicrophoneCapture({
    String? pathEnv,
    LinuxProcessStarter? processStarter,
    Duration handshakeTimeout = const Duration(seconds: 2),
    int stderrTailLimit = 4096,
  }) : _pathEnvOverride = pathEnv,
       _processStarter = processStarter ?? Process.start,
       _handshakeTimeout = handshakeTimeout,
       _stderrTailLimit = stderrTailLimit;

  static const List<LinuxCaptureBackend> _priorityOrder = [
    LinuxCaptureBackend.parecord,
    LinuxCaptureBackend.pwRecord,
    LinuxCaptureBackend.arecord,
  ];

  final String? _pathEnvOverride;
  final LinuxProcessStarter _processStarter;
  final Duration _handshakeTimeout;
  final int _stderrTailLimit;

  // Only one capture session may be active per instance.
  _LinuxCaptureSession? _activeSession;

  String get _pathEnv => _pathEnvOverride ?? Platform.environment['PATH'] ?? '';

  /// Lightweight availability probe: resolves backend executables on PATH
  /// without spawning anything. Never throws.
  @override
  Future<LinuxMicrophoneProbeStatus> probe() async {
    return _resolveCandidates().isEmpty
        ? LinuxMicrophoneProbeStatus.backendMissing
        : LinuxMicrophoneProbeStatus.ready;
  }

  @override
  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    final candidates = _resolveCandidates();
    if (candidates.isEmpty) {
      throw const LinuxMicrophoneCaptureException(
        code: 'backendMissing',
        message:
            'No Linux audio capture tool found (parecord, pw-record, arecord).',
      );
    }

    _PreAudioFailure? lastFailure;
    for (final candidate in candidates) {
      if (_activeSession != null) {
        break;
      }
      final (backend, executable) = candidate;
      Process? process;
      try {
        process = await _processStarter(
          executable,
          linuxCaptureArgs(
            backend,
            sampleRate: sampleRate,
            numChannels: numChannels,
          ),
        );
      } on ProcessException catch (error) {
        lastFailure = _PreAudioFailure(
          code: classifyLinuxPreAudioFailure(spawnErrorCode: error.errorCode),
          message: error.message,
          backend: backend,
        );
        continue;
      }

      final session = _LinuxCaptureSession(
        process: process,
        backend: backend,
        stderrTailLimit: _stderrTailLimit,
      );
      Object? firstByte;
      var timedOut = false;
      try {
        firstByte = await session.firstByteResult.timeout(_handshakeTimeout);
      } on TimeoutException {
        timedOut = true;
      } catch (_) {
        // Stdout ended or errored before producing audio.
      }
      if (_activeSession != null) {
        await session.kill();
        throw const LinuxMicrophoneCaptureException(code: 'captureFailed');
      }
      if (timedOut || firstByte is! Uint8List) {
        lastFailure = timedOut
            ? _PreAudioFailure(
                code: 'captureFailed',
                message: 'No audio received from ${backend.executableName}.',
                backend: backend,
              )
            : _PreAudioFailure(
                code: classifyLinuxPreAudioFailure(
                  exitCode: await _boundedExitCode(process),
                  stderrTail: session.stderrTail,
                ),
                backend: backend,
              );
        await session.kill();
        continue;
      }

      _activeSession = session..beginAudio();
      return session.output;
    }

    if (lastFailure != null) {
      throw LinuxMicrophoneCaptureException(
        code: lastFailure.code,
        message: lastFailure.message,
        backend: lastFailure.backend,
      );
    }
    throw const LinuxMicrophoneCaptureException(code: 'captureFailed');
  }

  @override
  Future<void> stop() async {
    final session = _activeSession;
    _activeSession = null;
    await session?.kill();
  }

  List<(LinuxCaptureBackend, String)> _resolveCandidates() {
    final directories = _pathEnv
        .split(':')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    final resolved = <(LinuxCaptureBackend, String)>[];
    for (final backend in _priorityOrder) {
      for (final directory in directories) {
        final path = '$directory/${backend.executableName}';
        if (_isExecutableFile(path)) {
          resolved.add((backend, path));
          break;
        }
      }
    }
    return resolved;
  }

  bool _isExecutableFile(String path) {
    try {
      final stat = FileStat.statSync(path);
      // Any execute bit set (owner/group/other => 0b001001001).
      return stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0;
    } catch (_) {
      return false;
    }
  }

  Future<int?> _boundedExitCode(Process process) async {
    try {
      return await process.exitCode.timeout(const Duration(milliseconds: 500));
    } on TimeoutException {
      return null;
    }
  }
}

class _PreAudioFailure {
  const _PreAudioFailure({required this.code, this.message, this.backend});

  final String code;
  final String? message;
  final LinuxCaptureBackend? backend;
}

class _LinuxCaptureSession {
  _LinuxCaptureSession({
    required Process process,
    required LinuxCaptureBackend backend,
    required int stderrTailLimit,
  }) : _process = process,
       _backend = backend,
       _stderrTailLimit = stderrTailLimit {
    _outputController = StreamController<Uint8List>(sync: true);
    _firstByteCompleter = Completer<Object?>();
    _stdoutSubscription = process.stdout.listen(
      (data) {
        final bytes = data is Uint8List ? data : Uint8List.fromList(data);
        if (!_audioBegun) {
          if (!_firstByteCompleter.isCompleted) {
            _firstByteCompleter.complete(bytes);
          }
          // Held back until the backend is accepted; beginAudio re-emits the
          // buffered chunks so consumers see every PCM byte exactly once.
          _pending.add(bytes);
          return;
        }
        if (!_outputController.isClosed) {
          _outputController.add(bytes);
        }
      },
      onError: (Object error) {
        if (!_audioBegun && !_firstByteCompleter.isCompleted) {
          _firstByteCompleter.complete(error);
        }
        if (!_outputController.isClosed) {
          _outputController.addError(error);
        }
      },
      onDone: _handleStdoutDone,
      cancelOnError: false,
    );
    _stderrSubscription = process.stderr.listen((data) {
      _stderrTail += utf8.decode(data, allowMalformed: true);
      if (_stderrTail.length > _stderrTailLimit) {
        _stderrTail = _stderrTail.substring(
          _stderrTail.length - _stderrTailLimit,
        );
      }
    }, cancelOnError: true);
  }

  final Process _process;
  final LinuxCaptureBackend _backend;
  final int _stderrTailLimit;

  late final StreamController<Uint8List> _outputController;
  late final Completer<Object?> _firstByteCompleter;
  late final StreamSubscription<List<int>> _stdoutSubscription;
  late final StreamSubscription<List<int>> _stderrSubscription;
  final List<Uint8List> _pending = <Uint8List>[];
  bool _audioBegun = false;
  bool _stoppedByUs = false;
  String _stderrTail = '';

  Stream<Uint8List> get output => _outputController.stream;

  Future<Object?> get firstByteResult => _firstByteCompleter.future;

  String get stderrTail => _stderrTail;

  void beginAudio() {
    _audioBegun = true;
    if (_outputController.isClosed) {
      return;
    }
    for (final chunk in _pending) {
      _outputController.add(chunk);
    }
    _pending.clear();
  }

  void _handleStdoutDone() {
    if (!_audioBegun && !_firstByteCompleter.isCompleted) {
      _firstByteCompleter.completeError(StateError('stdout ended'));
    }
    unawaited(
      _process.exitCode.then((exitCode) {
        if (_outputController.isClosed) {
          return;
        }
        if (_audioBegun && exitCode != 0 && !_stoppedByUs) {
          _outputController.addError(
            LinuxMicrophoneCaptureException(
              code: 'captureFailed',
              backend: _backend,
              message: 'Capture process exited with code $exitCode.',
            ),
          );
        }
        unawaited(_outputController.close());
      }),
    );
  }

  Future<void> kill() async {
    if (_stoppedByUs) {
      return;
    }
    _stoppedByUs = true;
    _process.kill();
    try {
      await _process.exitCode.timeout(const Duration(milliseconds: 500));
    } on TimeoutException {
      _process.kill(ProcessSignal.sigkill);
      try {
        await _process.exitCode.timeout(const Duration(milliseconds: 250));
      } on TimeoutException {
        // Best-effort reap.
      }
    }
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    // A single-subscription controller's close future waits for an eventual
    // listener to consume done. Fallback sessions are never exposed, so do
    // not deadlock cleanup while waiting for a listener that cannot exist.
    unawaited(_outputController.close());
  }
}
