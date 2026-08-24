import 'dart:typed_data';

import 'linux_microphone_capture_types.dart';

// Web stub for the Linux microphone capture backend. The real process-backed
// implementation only exists on IO platforms (see the conditional export in
// linux_microphone_capture.dart); voice input never routes here because the
// Linux branch in SpeechAudioCapture is unreachable on web.
class LinuxMicrophoneCapture implements LinuxMicrophoneCaptureService {
  // Non-const to mirror the IO implementation's constructor surface so
  // consumers can use the same invocation on either conditional-export
  // branch without triggering prefer_const lints.
  LinuxMicrophoneCapture();

  @override
  Future<LinuxMicrophoneProbeStatus> probe() async {
    return LinuxMicrophoneProbeStatus.notSupported;
  }

  @override
  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    throw const LinuxMicrophoneCaptureException(
      code: 'backendMissing',
      message: 'Linux microphone capture is not supported on this platform.',
    );
  }

  @override
  Future<void> stop() async {}
}
