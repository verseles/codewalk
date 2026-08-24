import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'linux_microphone_capture.dart';
import 'linux_microphone_capture_types.dart';
import 'windows_microphone_service.dart';

// Audio capture abstraction for the on-device STT engines.
//
// On Windows the legacy `record` plugin (record_windows 1.0.7) can crash the
// host process with a MediaFoundation segfault (llfbandit/record#453), so this
// wrapper uses CodeWalk's runner-owned WASAPI bridge there. On Linux the
// record_linux plugin shells out to an external `parecord` binary and fails
// with a raw ProcessException when it is missing (issue #158), so this wrapper
// routes Linux through CodeWalk's process-backed multi-backend capture
// (parecord -> pw-record -> arecord). Other platforms keep using
// [AudioRecorder]. The wrapper owns the recorder lifecycle for the duration of
// a single session so [startPcmStream] and [stop] always reference the same
// instance.
class SpeechAudioCapture {
  SpeechAudioCapture({
    WindowsMicrophoneService? windowsMicrophoneService,
    LinuxMicrophoneCaptureService? linuxMicrophoneCapture,
  }) : _windowsMicrophoneService =
           windowsMicrophoneService ?? const WindowsMicrophoneService(),
       _linuxMicrophoneCapture =
           linuxMicrophoneCapture ?? LinuxMicrophoneCapture();

  final WindowsMicrophoneService _windowsMicrophoneService;
  final LinuxMicrophoneCaptureService _linuxMicrophoneCapture;

  // On non-Windows, the wrapper owns the AudioRecorder for the duration of
  // a single capture session.
  AudioRecorder? _activeRecorder;
  WindowsMicrophoneAccessStatus? _lastWindowsAccessStatus;
  SpeechAudioCaptureFailureInfo? _lastFailureInfo;

  WindowsMicrophoneAccessStatus? get lastWindowsAccessStatus =>
      _lastWindowsAccessStatus;

  // Typed failure info for the most recent capture attempt on platforms that
  // bypass AudioRecorder (Linux). Null unless that attempt failed, so callers
  // can prefer it over the Windows-only status mapping.
  SpeechAudioCaptureFailureInfo? get lastFailureInfo => _lastFailureInfo;

  bool get isWindowsTarget {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  bool get isLinuxTarget {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.linux;
  }

  Future<bool> hasPermission() async {
    if (isWindowsTarget) {
      final status = await _windowsMicrophoneService.probe();
      _lastWindowsAccessStatus = status;
      _lastFailureInfo = null;
      return status == WindowsMicrophoneAccessStatus.allowed;
    }
    if (isLinuxTarget) {
      final status = await _linuxMicrophoneCapture.probe();
      if (status == LinuxMicrophoneProbeStatus.ready) {
        _lastFailureInfo = null;
        return true;
      }
      // No usable capture tool was found on PATH; surface the install hint
      // instead of pretending permission was denied.
      _lastFailureInfo = const SpeechAudioCaptureFailureInfo(
        reason:
            'No Linux audio capture tool was found (parecord, pw-record or '
            'arecord).',
        reasonKey: 'linuxMicBackendMissing',
      );
      return false;
    }
    _lastWindowsAccessStatus = null;
    _lastFailureInfo = null;
    final recorder = AudioRecorder();
    try {
      return await recorder.hasPermission();
    } catch (_) {
      return false;
    } finally {
      // The probe recorder is only used to query permission; dispose it
      // unconditionally so we never leak a plugin instance.
      try {
        await recorder.dispose();
      } catch (_) {
        // Ignore dispose errors during cleanup.
      }
    }
  }

  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    if (isWindowsTarget) {
      if (sampleRate != 16000 || numChannels != 1) {
        throw StateError(
          'Windows WASAPI speech capture supports PCM16 mono 16 kHz only.',
        );
      }
      return _windowsMicrophoneService.pcmStream();
    }
    if (isLinuxTarget) {
      try {
        return await _linuxMicrophoneCapture.startPcmStream(
          sampleRate: sampleRate,
          numChannels: numChannels,
        );
      } on LinuxMicrophoneCaptureException catch (error) {
        _lastFailureInfo = speechAudioCaptureFailureInfoForError(error);
        rethrow;
      } catch (error) {
        _lastFailureInfo = speechAudioCaptureFailureInfoForError(error);
        rethrow;
      }
    }
    final recorder = AudioRecorder();
    _activeRecorder = recorder;
    try {
      return recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: numChannels,
        ),
      );
    } catch (error) {
      // startStream failed before returning a live stream; ensure the
      // recorder is cleaned up so we do not leak the underlying
      // record_windows / record_linux / record_macos plugin instance.
      _activeRecorder = null;
      try {
        await recorder.stop();
      } catch (_) {
        // Ignore stop errors during cleanup.
      }
      try {
        await recorder.dispose();
      } catch (_) {
        // Ignore dispose errors during cleanup.
      }
      rethrow;
    }
  }

  Future<void> stop() async {
    if (isWindowsTarget) {
      await _windowsMicrophoneService.stopStream();
      return;
    }
    if (isLinuxTarget) {
      await _linuxMicrophoneCapture.stop();
      return;
    }
    final recorder = _activeRecorder;
    _activeRecorder = null;
    if (recorder == null) {
      return;
    }
    try {
      await recorder.stop();
    } catch (_) {
      // Ignore stop errors so callers can always safely stop().
    }
    try {
      await recorder.dispose();
    } catch (_) {
      // Ignore dispose errors.
    }
  }
}

class SpeechAudioCaptureFailureInfo {
  const SpeechAudioCaptureFailureInfo({this.reason, this.reasonKey});

  final String? reason;
  final String? reasonKey;
}

SpeechAudioCaptureFailureInfo speechAudioCaptureFailureInfoForStatus(
  WindowsMicrophoneAccessStatus? status,
) {
  switch (status) {
    case WindowsMicrophoneAccessStatus.denied:
      return const SpeechAudioCaptureFailureInfo(
        reason: 'Microphone access is blocked by Windows privacy settings.',
        reasonKey: 'microphoneDenied',
      );
    case WindowsMicrophoneAccessStatus.noInputDevice:
      return const SpeechAudioCaptureFailureInfo(
        reason: 'No microphone input device is available.',
        reasonKey: 'noInputDevice',
      );
    case WindowsMicrophoneAccessStatus.deviceBusy:
      return const SpeechAudioCaptureFailureInfo(
        reason: 'The default microphone is currently in use by another app.',
        reasonKey: 'deviceBusy',
      );
    case WindowsMicrophoneAccessStatus.unsupportedFormat:
      return const SpeechAudioCaptureFailureInfo(
        reason: 'The default microphone format is not supported.',
        reasonKey: 'unsupportedFormat',
      );
    case WindowsMicrophoneAccessStatus.notSupported:
      return const SpeechAudioCaptureFailureInfo(
        reason:
            'The Windows microphone backend is not available in this build.',
        reasonKey: 'backendUnavailable',
      );
    case WindowsMicrophoneAccessStatus.unknown:
      return const SpeechAudioCaptureFailureInfo(
        reason: 'Windows microphone capture is unavailable.',
        reasonKey: 'generic',
      );
    case WindowsMicrophoneAccessStatus.allowed:
      return const SpeechAudioCaptureFailureInfo();
    case null:
      // Non-Windows permission denial has no Windows status; keep the typed
      // code consistent so the UI maps it to the localized mic-permission copy.
      return const SpeechAudioCaptureFailureInfo(
        reason: 'Microphone permission is disabled.',
        reasonKey: 'microphoneDenied',
      );
  }
}

SpeechAudioCaptureFailureInfo speechAudioCaptureFailureInfoForError(
  Object? error,
) {
  if (error is MicrophoneBackendUnavailableException) {
    switch (error.code) {
      case 'denied':
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.denied,
        );
      case 'noInputDevice':
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.noInputDevice,
        );
      case 'deviceBusy':
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.deviceBusy,
        );
      case 'unsupportedFormat':
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.unsupportedFormat,
        );
      case 'notSupported':
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.notSupported,
        );
      case 'unknown':
      default:
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.unknown,
        );
    }
  }
  if (error is LinuxMicrophoneCaptureException) {
    switch (error.code) {
      case 'backendMissing':
        return const SpeechAudioCaptureFailureInfo(
          reason:
              'No microphone recording tool was found on this system. Install '
              'PulseAudio tools (parecord), PipeWire tools (pw-record) or ALSA '
              'utilities (arecord), then try again.',
          reasonKey: 'linuxMicBackendMissing',
        );
      case 'audioServerUnavailable':
        return const SpeechAudioCaptureFailureInfo(
          reason:
              'A microphone tool was found, but the Linux audio server could '
              'not be reached. Make sure PipeWire or PulseAudio is running.',
          reasonKey: 'linuxAudioServerUnavailable',
        );
      case 'denied':
        return const SpeechAudioCaptureFailureInfo(
          reason: 'Microphone access was denied by the system.',
          reasonKey: 'microphoneDenied',
        );
      case 'deviceBusy':
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.deviceBusy,
        );
      case 'noInputDevice':
        return speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.noInputDevice,
        );
      case 'captureFailed':
      default:
        break;
    }
  }
  return const SpeechAudioCaptureFailureInfo(
    reason: 'Microphone capture failed.',
    reasonKey: 'generic',
  );
}
