import 'dart:typed_data';

// Shared, web-safe declarations for the Linux microphone capture backend.
//
// The concrete service lives behind a conditional export
// (linux_microphone_capture.dart): a process-backed implementation on IO
// platforms and a no-op stub on web. See ADR-039 for the Windows counterpart
// pattern this mirrors.

/// Ordered capture backends tried by the Linux microphone service.
enum LinuxCaptureBackend { parecord, pwRecord, arecord }

extension LinuxCaptureBackendLabel on LinuxCaptureBackend {
  String get executableName {
    switch (this) {
      case LinuxCaptureBackend.parecord:
        return 'parecord';
      case LinuxCaptureBackend.pwRecord:
        return 'pw-record';
      case LinuxCaptureBackend.arecord:
        return 'arecord';
    }
  }
}

/// Result of a lightweight availability probe (PATH resolution only).
enum LinuxMicrophoneProbeStatus { ready, backendMissing, notSupported }

/// Web-safe contract used to inject the platform implementation into speech
/// capture without exposing either conditional-export branch as the type.
abstract interface class LinuxMicrophoneCaptureService {
  Future<LinuxMicrophoneProbeStatus> probe();

  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  });

  Future<void> stop();
}

/// Typed failure raised by the Linux microphone capture backend.
///
/// [code] is a stable machine key mapped to localized UI copy:
/// `backendMissing`, `audioServerUnavailable`, `denied`, `noInputDevice`,
/// `deviceBusy`, `captureFailed`.
class LinuxMicrophoneCaptureException implements Exception {
  const LinuxMicrophoneCaptureException({
    required this.code,
    this.message,
    this.backend,
  });

  final String code;
  final String? message;
  final LinuxCaptureBackend? backend;

  @override
  String toString() =>
      'LinuxMicrophoneCaptureException(code: $code, backend: $backend, '
      'message: $message)';
}

/// Raw PCM16 argument vectors for each supported CLI backend.
///
/// Kept pure so unit tests can pin the exact command lines against the
/// live-verified contracts:
///   - parecord --raw --format=s16le --rate=N --channels=n --latency-msec=100
///     (same flags record_linux uses)
///   - pw-record --raw --format=s16 --rate N --channels n -   (trailing `-`
///     operand is required)
///   - arecord -q -t raw -f S16_LE -r N -c n
List<String> linuxCaptureArgs(
  LinuxCaptureBackend backend, {
  required int sampleRate,
  required int numChannels,
}) {
  switch (backend) {
    case LinuxCaptureBackend.parecord:
      return [
        '--raw',
        '--format=s16le',
        '--rate=$sampleRate',
        '--channels=$numChannels',
        '--latency-msec=100',
      ];
    case LinuxCaptureBackend.pwRecord:
      return [
        '--raw',
        '--format=s16',
        '--rate',
        '$sampleRate',
        '--channels',
        '$numChannels',
        '-',
      ];
    case LinuxCaptureBackend.arecord:
      return [
        '-q',
        '-t',
        'raw',
        '-f',
        'S16_LE',
        '-r',
        '$sampleRate',
        '-c',
        '$numChannels',
      ];
  }
}

/// Classifies why a backend failed before producing any audio byte.
///
/// Pure so tests can pin the mapping without spawning processes.
String classifyLinuxPreAudioFailure({
  int? exitCode,
  String? stderrTail,
  int? spawnErrorCode,
}) {
  // Spawn failures are classified from the errno value so localized OS
  // message text never affects the outcome.
  if (spawnErrorCode != null) {
    if (spawnErrorCode == 2 || spawnErrorCode == 8) {
      // ENOENT / ENOEXEC-style: the binary disappeared between PATH lookup
      // and spawn.
      return 'backendMissing';
    }
    if (spawnErrorCode == 13) {
      return 'denied';
    }
    return 'captureFailed';
  }

  final stderr = (stderrTail ?? '').toLowerCase();
  bool containsAny(List<String> needles) => needles.any(stderr.contains);

  if (containsAny([
    'pa_context_connect',
    'pw_context_connect',
    'connection refused',
    'connection terminated',
    'host is down',
    'no such process',
    'xdg_runtime_dir',
  ])) {
    return 'audioServerUnavailable';
  }
  if (containsAny(['permission denied', 'access denied'])) {
    return 'denied';
  }
  if (containsAny(['device or resource busy', 'ebusy'])) {
    return 'deviceBusy';
  }
  if (containsAny([
    'no soundcards found',
    'no such device',
    'no default device',
  ])) {
    return 'noInputDevice';
  }
  return 'captureFailed';
}
