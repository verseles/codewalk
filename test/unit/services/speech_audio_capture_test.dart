import 'dart:async';

import 'package:codewalk/presentation/services/linux_microphone_capture_types.dart';
import 'package:codewalk/presentation/services/speech_audio_capture.dart';
import 'package:codewalk/presentation/services/windows_microphone_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLinuxMicrophoneCapture implements LinuxMicrophoneCaptureService {
  _FakeLinuxMicrophoneCapture({
    this.probeStatus = LinuxMicrophoneProbeStatus.ready,
    this.stream,
    this.startError,
  });

  final LinuxMicrophoneProbeStatus probeStatus;
  final Stream<Uint8List>? stream;
  final Object? startError;

  int probeCount = 0;
  int streamCount = 0;
  int stopCount = 0;

  @override
  Future<LinuxMicrophoneProbeStatus> probe() async {
    probeCount += 1;
    return probeStatus;
  }

  @override
  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    streamCount += 1;
    final error = startError;
    if (error != null) {
      throw error;
    }
    return stream ?? const Stream<Uint8List>.empty();
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}

class _FakeWindowsMicrophoneService extends WindowsMicrophoneService {
  _FakeWindowsMicrophoneService({
    required this.status,
    Stream<Uint8List>? stream,
  }) : stream = stream ?? Stream<Uint8List>.value(Uint8List.fromList([1, 2]));

  final WindowsMicrophoneAccessStatus status;
  final Stream<Uint8List> stream;
  int probeCount = 0;
  int streamCount = 0;
  int stopCount = 0;

  @override
  Future<WindowsMicrophoneAccessStatus> probe() async {
    probeCount += 1;
    return status;
  }

  @override
  Stream<Uint8List> pcmStream() {
    streamCount += 1;
    return stream;
  }

  @override
  Future<void> stopStream() async {
    stopCount += 1;
  }
}

void main() {
  group('SpeechAudioCapture Windows', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('uses Windows probe for permission', () async {
      final allowed = _FakeWindowsMicrophoneService(
        status: WindowsMicrophoneAccessStatus.allowed,
      );
      final denied = _FakeWindowsMicrophoneService(
        status: WindowsMicrophoneAccessStatus.denied,
      );

      expect(
        await SpeechAudioCapture(
          windowsMicrophoneService: allowed,
        ).hasPermission(),
        isTrue,
      );
      expect(
        await SpeechAudioCapture(
          windowsMicrophoneService: denied,
        ).hasPermission(),
        isFalse,
      );
      expect(allowed.probeCount, 1);
      expect(denied.probeCount, 1);
    });

    test('returns the Windows PCM stream for the supported format', () async {
      final service = _FakeWindowsMicrophoneService(
        status: WindowsMicrophoneAccessStatus.allowed,
      );
      final capture = SpeechAudioCapture(windowsMicrophoneService: service);

      final stream = await capture.startPcmStream(
        sampleRate: 16000,
        numChannels: 1,
      );

      expect(await stream.first, orderedEquals([1, 2]));
      expect(service.streamCount, 1);
    });

    test(
      'rejects unsupported Windows stream format before native call',
      () async {
        final service = _FakeWindowsMicrophoneService(
          status: WindowsMicrophoneAccessStatus.allowed,
        );
        final capture = SpeechAudioCapture(windowsMicrophoneService: service);

        expect(
          capture.startPcmStream(sampleRate: 44100, numChannels: 2),
          throwsStateError,
        );
        expect(service.streamCount, 0);
      },
    );

    test('stops the Windows stream through the bridge', () async {
      final service = _FakeWindowsMicrophoneService(
        status: WindowsMicrophoneAccessStatus.allowed,
      );
      final capture = SpeechAudioCapture(windowsMicrophoneService: service);

      await capture.stop();

      expect(service.stopCount, 1);
    });

    test('maps Windows microphone statuses to stable reason keys', () {
      expect(
        speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.denied,
        ).reasonKey,
        'microphoneDenied',
      );
      expect(
        speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.noInputDevice,
        ).reasonKey,
        'noInputDevice',
      );
      expect(
        speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.deviceBusy,
        ).reasonKey,
        'deviceBusy',
      );
      expect(
        speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.unsupportedFormat,
        ).reasonKey,
        'unsupportedFormat',
      );
      expect(
        speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.notSupported,
        ).reasonKey,
        'backendUnavailable',
      );
      expect(
        speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.unknown,
        ).reasonKey,
        'generic',
      );
      expect(
        speechAudioCaptureFailureInfoForStatus(
          WindowsMicrophoneAccessStatus.allowed,
        ).reasonKey,
        isNull,
      );
    });

    test('maps Windows microphone stream errors to stable reason keys', () {
      expect(
        speechAudioCaptureFailureInfoForError(
          const MicrophoneBackendUnavailableException(code: 'denied'),
        ).reasonKey,
        'microphoneDenied',
      );
      expect(
        speechAudioCaptureFailureInfoForError(
          const MicrophoneBackendUnavailableException(
            code: 'unsupportedFormat',
          ),
        ).reasonKey,
        'unsupportedFormat',
      );
      expect(
        speechAudioCaptureFailureInfoForError(
          const MicrophoneBackendUnavailableException(code: 'notSupported'),
        ).reasonKey,
        'backendUnavailable',
      );
      expect(
        speechAudioCaptureFailureInfoForError(StateError('boom')).reasonKey,
        'generic',
      );
      expect(
        speechAudioCaptureFailureInfoForError(StateError('boom')).reason,
        'Microphone capture failed.',
      );
    });
  });

  group('SpeechAudioCapture Linux', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('routes permission through the Linux probe availability', () async {
      final ready = _FakeLinuxMicrophoneCapture();
      final missing = _FakeLinuxMicrophoneCapture(
        probeStatus: LinuxMicrophoneProbeStatus.backendMissing,
      );
      final readyCapture = SpeechAudioCapture(linuxMicrophoneCapture: ready);

      expect(await readyCapture.hasPermission(), isTrue);
      expect(ready.probeCount, 1);
      expect(readyCapture.lastFailureInfo, isNull);

      final missingCapture = SpeechAudioCapture(
        linuxMicrophoneCapture: missing,
      );
      expect(await missingCapture.hasPermission(), isFalse);
      expect(missing.probeCount, 1);
      expect(
        missingCapture.lastFailureInfo?.reasonKey,
        'linuxMicBackendMissing',
      );
    });

    test('routes the PCM stream and stop through the Linux service', () async {
      final service = _FakeLinuxMicrophoneCapture(
        stream: Stream<Uint8List>.fromIterable([
          Uint8List.fromList([4, 5]),
        ]),
      );
      final capture = SpeechAudioCapture(linuxMicrophoneCapture: service);

      final audio = await capture.startPcmStream();
      expect(await audio.first, orderedEquals([4, 5]));
      await capture.stop();

      expect(service.streamCount, 1);
      expect(service.stopCount, 1);
    });

    test(
      'exposes typed failure info when the Linux backend is missing',
      () async {
        final service = _FakeLinuxMicrophoneCapture(
          startError: const LinuxMicrophoneCaptureException(
            code: 'backendMissing',
          ),
        );
        final capture = SpeechAudioCapture(linuxMicrophoneCapture: service);

        await expectLater(capture.startPcmStream(), throwsException);
        expect(capture.lastFailureInfo?.reasonKey, 'linuxMicBackendMissing');
        expect(
          speechAudioCaptureFailureInfoForError(service.startError).reasonKey,
          'linuxMicBackendMissing',
        );
      },
    );

    test('maps Linux capture exception codes to stable reason keys', () {
      expect(
        speechAudioCaptureFailureInfoForError(
          const LinuxMicrophoneCaptureException(code: 'audioServerUnavailable'),
        ).reasonKey,
        'linuxAudioServerUnavailable',
      );
      expect(
        speechAudioCaptureFailureInfoForError(
          const LinuxMicrophoneCaptureException(code: 'denied'),
        ).reasonKey,
        'microphoneDenied',
      );
      expect(
        speechAudioCaptureFailureInfoForError(
          const LinuxMicrophoneCaptureException(code: 'deviceBusy'),
        ).reasonKey,
        'deviceBusy',
      );
      expect(
        speechAudioCaptureFailureInfoForError(
          const LinuxMicrophoneCaptureException(code: 'noInputDevice'),
        ).reasonKey,
        'noInputDevice',
      );
      expect(
        speechAudioCaptureFailureInfoForError(
          const LinuxMicrophoneCaptureException(code: 'captureFailed'),
        ).reasonKey,
        'generic',
      );
    });
  });
}
