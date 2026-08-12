import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'windows_microphone_service.dart';

// Audio capture abstraction for the on-device STT engines.
//
// On Windows the legacy `record` plugin (record_windows 1.0.7) can crash the
// host process with a MediaFoundation segfault (llfbandit/record#453), so this
// wrapper uses CodeWalk's runner-owned WASAPI bridge there. Other platforms keep
// using [AudioRecorder]. The wrapper owns the recorder lifecycle for the
// duration of a single session so [startPcmStream] and [stop] always reference
// the same instance.
class SpeechAudioCapture {
  SpeechAudioCapture({WindowsMicrophoneService? windowsMicrophoneService})
    : _windowsMicrophoneService =
          windowsMicrophoneService ?? const WindowsMicrophoneService();

  final WindowsMicrophoneService _windowsMicrophoneService;

  // On non-Windows, the wrapper owns the AudioRecorder for the duration of
  // a single capture session.
  AudioRecorder? _activeRecorder;
  WindowsMicrophoneAccessStatus? _lastWindowsAccessStatus;

  WindowsMicrophoneAccessStatus? get lastWindowsAccessStatus =>
      _lastWindowsAccessStatus;

  bool get isWindowsTarget {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<bool> hasPermission() async {
    if (isWindowsTarget) {
      final status = await _windowsMicrophoneService.probe();
      _lastWindowsAccessStatus = status;
      return status == WindowsMicrophoneAccessStatus.allowed;
    }
    _lastWindowsAccessStatus = null;
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
  return const SpeechAudioCaptureFailureInfo(
    reason: 'Windows microphone capture failed.',
    reasonKey: 'generic',
  );
}
