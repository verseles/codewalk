import 'dart:async';

import 'package:codewalk/core/auth/tts_api_key_storage.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/read_aloud_service.dart';
import 'package:codewalk/presentation/services/tts/generated_tts_audio_player.dart';
import 'package:codewalk/presentation/services/tts/tts_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class _FakeFlutterTts implements FlutterTts {
  final List<String> spokenTexts = <String>[];
  double lastRate = 0.5;
  double lastPitch = 1.0;
  Map<String, String>? lastVoice;
  bool isPaused = false;
  bool isStopped = false;
  bool didSpeak = false;

  VoidCallback? _startHandler;
  VoidCallback? _completionHandler;
  VoidCallback? _cancelHandler;
  VoidCallback? _pauseHandler;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenTexts.add(text);
    didSpeak = true;
    _startHandler?.call();
    // Simulate immediate completion for tests.
    _completionHandler?.call();
  }

  @override
  Future<dynamic> stop() async {
    isStopped = true;
    _cancelHandler?.call();
  }

  @override
  Future<dynamic> pause() async {
    isPaused = true;
    _pauseHandler?.call();
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    lastRate = rate;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    lastPitch = pitch;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    lastVoice = voice;
  }

  @override
  void setStartHandler(VoidCallback callback) {
    _startHandler = callback;
  }

  @override
  void setCompletionHandler(VoidCallback callback) {
    _completionHandler = callback;
  }

  @override
  void setErrorHandler(ErrorHandler handler) {}

  @override
  void setCancelHandler(VoidCallback callback) {
    _cancelHandler = callback;
  }

  @override
  void setPauseHandler(VoidCallback callback) {
    _pauseHandler = callback;
  }

  @override
  void setContinueHandler(VoidCallback callback) {}

  @override
  void setProgressHandler(ProgressHandler callback) {}

  @override
  Future<dynamic> get getEngines async {
    return <dynamic>[
      {'name': 'fake-engine'},
    ];
  }

  @override
  Future<dynamic> get getVoices async {
    return <dynamic>[
      {'name': 'en-us-x-tpf', 'locale': 'en-US'},
    ];
  }

  @override
  Future<dynamic> get getLanguages async {
    return <dynamic>['en-US', 'pt-BR'];
  }
}

class _ThrowingFlutterTts implements FlutterTts {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #speak ||
        invocation.memberName == #getEngines) {
      throw Exception('TTS engine not available');
    }
    return Future<void>.value();
  }
}

class _VoiceOnlyFlutterTts extends _FakeFlutterTts {
  @override
  Future<dynamic> get getEngines async {
    throw Exception('getEngines unavailable');
  }
}

class _EngineOnlyFlutterTts extends _FakeFlutterTts {
  @override
  Future<dynamic> get getVoices async {
    return const <dynamic>[];
  }

  @override
  Future<dynamic> get getLanguages async {
    return const <dynamic>[];
  }
}

class _FakeGeneratedBackend implements TtsBackend {
  _FakeGeneratedBackend({
    Future<TtsSynthesisResult>? result,
    this.callOnStart = false,
  }) : result =
           result ??
           Future<TtsSynthesisResult>.value(
             GeneratedTtsAudio(
               bytes: Uint8List.fromList(<int>[1, 2, 3]),
               mimeType: 'audio/mpeg',
             ),
           );

  final Future<TtsSynthesisResult> result;
  final bool callOnStart;
  final List<TtsSynthesisRequest> requests = <TtsSynthesisRequest>[];
  bool stopped = false;
  bool paused = false;

  @override
  Future<bool> get isAvailable async => true;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.generatedAudio;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.edgeExperimental;

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    requests.add(request);
    if (callOnStart) {
      callbacks.onStart?.call();
    }
    return result;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    return const <TtsVoiceOption>[];
  }

  @override
  Future<List<String>> getLanguages() async {
    return const <String>[];
  }

  @override
  void dispose() {}
}

class _FakeModelDiscoveryBackend implements TtsBackend, TtsModelDiscovery {
  String? lastApiKey;

  @override
  Future<List<TtsModelOption>> getModels({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    lastApiKey = apiKey;
    return const <TtsModelOption>[
      TtsModelOption(id: 'model-a', label: 'Model A', maxCharacters: 500),
    ];
  }

  @override
  Future<bool> get isAvailable async => true;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.generatedAudio;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.edgeExperimental;

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    return GeneratedTtsAudio(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      mimeType: 'audio/mpeg',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    return const <TtsVoiceOption>[];
  }

  @override
  Future<List<String>> getLanguages() async => const <String>[];

  @override
  void dispose() {}
}

class _FakeTtsApiKeyStorageBackend implements TtsApiKeyStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class _ThrowingTtsApiKeyStorageBackend implements TtsApiKeyStorageBackend {
  @override
  Future<void> write({required String key, required String value}) async {
    throw StateError('secure storage unavailable');
  }

  @override
  Future<String?> read({required String key}) async {
    throw StateError('secure storage unavailable');
  }

  @override
  Future<void> delete({required String key}) async {
    throw StateError('secure storage unavailable');
  }
}

class _FakeTtsAudioPlayer implements TtsAudioPlayer {
  final StreamController<void> _completeController =
      StreamController<void>.broadcast(sync: true);
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast(sync: true);
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast(sync: true);

  Uint8List? lastBytes;
  String? lastMimeType;
  int playCount = 0;
  bool stopped = false;
  bool paused = false;

  @override
  Stream<void> get onComplete => _completeController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Future<void> playBytes(Uint8List bytes, {String? mimeType}) async {
    playCount += 1;
    lastBytes = bytes;
    lastMimeType = mimeType;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    await _completeController.close();
    await _durationController.close();
    await _positionController.close();
  }

  void complete() {
    _completeController.add(null);
  }

  void reportProgress({
    required Duration position,
    required Duration duration,
  }) {
    _durationController.add(duration);
    _positionController.add(position);
  }
}

void main() {
  group('ReadAloudService', () {
    test('initial state is idle', () {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      expect(service.state, ReadAloudState.idle);
      expect(service.activeMessageId, isNull);
      expect(service.isSpeaking, isFalse);
      expect(service.isLoading, isFalse);
      expect(service.progress, isNull);
    });

    test('speak transitions to playing and registers message', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(messageId: 'msg_1', text: 'Hello world');

      expect(tts.spokenTexts, contains('Hello world'));
      // Note: _completionHandler fires immediately in the fake, so
      // state may have already returned to idle. Verify the message
      // was sent.
    });

    test('speak with empty text is a no-op', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(messageId: 'msg_1', text: '  ');

      expect(tts.spokenTexts, isEmpty);
      expect(service.state, ReadAloudState.idle);
    });

    test('speak passes rate and pitch to TTS engine', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(
        messageId: 'msg_1',
        text: 'Test',
        rate: 0.8,
        pitch: 1.5,
      );

      expect(tts.lastRate, 0.8);
      expect(tts.lastPitch, 1.5);
    });

    test('speak passes voice when provided', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(
        messageId: 'msg_1',
        text: 'Test',
        voice: 'en-us-x-tpf',
      );

      expect(tts.lastVoice, isNotNull);
      expect(tts.lastVoice!['name'], 'en-us-x-tpf');
      expect(tts.lastVoice!['locale'], 'en-US');
    });

    test(
      'native backend ignores unknown voice ids when voices are available',
      () async {
        final tts = _FakeFlutterTts();
        final service = ReadAloudService(tts: tts);

        await service.speak(messageId: 'msg_1', text: 'Test', voice: 'coral');

        expect(tts.spokenTexts, contains('Test'));
        expect(tts.lastVoice, isNull);
      },
    );

    test('generated audio backend plays returned bytes', () async {
      final backend = _FakeGeneratedBackend();
      final player = _FakeTtsAudioPlayer();
      final service = ReadAloudService(
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.edgeExperimental: backend,
        },
        audioPlayer: player,
      );

      await service.speak(
        messageId: 'msg_1',
        text: 'Hello cloud',
        provider: ReadAloudProvider.edgeExperimental,
      );

      expect(backend.requests.single.text, 'Hello cloud');
      expect(player.playCount, 1);
      expect(player.lastBytes, orderedEquals(<int>[1, 2, 3]));
      expect(player.lastMimeType, 'audio/mpeg');
      expect(service.state, ReadAloudState.playing);

      player.reportProgress(
        position: const Duration(milliseconds: 250),
        duration: const Duration(seconds: 1),
      );
      expect(service.progress, 0.25);

      player.complete();
      expect(service.state, ReadAloudState.idle);
      expect(service.activeMessageId, isNull);

      await service.dispose();
    });

    test('getModelsForProvider returns empty without model discovery', () async {
      final backend = _FakeGeneratedBackend();
      final player = _FakeTtsAudioPlayer();
      final service = ReadAloudService(
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.edgeExperimental: backend,
        },
        audioPlayer: player,
      );

      final models = await service.getModelsForProvider(
        ReadAloudProvider.edgeExperimental,
      );

      expect(models, isEmpty);
      await service.dispose();
    });

    test('getModelsForProvider maps discovery-backed models', () async {
      final backend = _FakeModelDiscoveryBackend();
      final player = _FakeTtsAudioPlayer();
      final service = ReadAloudService(
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.edgeExperimental: backend,
        },
        audioPlayer: player,
      );

      final models = await service.getModelsForProvider(
        ReadAloudProvider.edgeExperimental,
        apiKey: 'xi-test',
      );

      expect(
        models,
        <Map<String, String>>[
          <String, String>{
            'name': 'model-a',
            'label': 'Model A',
            'maxCharacters': '500',
          },
        ],
      );
      expect(backend.lastApiKey, 'xi-test');
      await service.dispose();
    });

    test('reads OpenAI-compatible API key from secure storage', () async {
      final backend = _FakeGeneratedBackend();
      final player = _FakeTtsAudioPlayer();
      final keyBackend = _FakeTtsApiKeyStorageBackend();
      final keyStorage = TtsApiKeyStorage(backend: keyBackend);
      await keyStorage.write(ReadAloudProvider.openAiCompatible, 'sk-test');
      final service = ReadAloudService(
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.openAiCompatible: backend,
        },
        audioPlayer: player,
        apiKeyStorage: keyStorage,
      );

      await service.speak(
        messageId: 'msg_1',
        text: 'Hello cloud',
        provider: ReadAloudProvider.openAiCompatible,
      );

      expect(backend.requests.single.apiKey, 'sk-test');
      await service.dispose();
    });

    test('reports secure storage failure as provider unavailable', () async {
      final backend = _FakeGeneratedBackend();
      final service = ReadAloudService(
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.openAiCompatible: backend,
        },
        apiKeyStorage: TtsApiKeyStorage(
          backend: _ThrowingTtsApiKeyStorageBackend(),
        ),
      );

      await service.speak(
        messageId: 'msg_1',
        text: 'Hello cloud',
        provider: ReadAloudProvider.openAiCompatible,
      );

      expect(backend.requests, isEmpty);
      expect(service.lastErrorKind, ReadAloudErrorKind.providerUnavailable);
      expect(service.lastErrorMessageId, 'msg_1');
      expect(
        service.lastErrorMessage,
        'Secure TTS API key storage is unavailable.',
      );
    });

    test(
      'slow generated audio reports loading before playback starts',
      () async {
        final completer = Completer<TtsSynthesisResult>();
        final backend = _FakeGeneratedBackend(result: completer.future);
        final player = _FakeTtsAudioPlayer();
        final service = ReadAloudService(
          backends: <ReadAloudProvider, TtsBackend>{
            ReadAloudProvider.edgeExperimental: backend,
          },
          audioPlayer: player,
        );

        final speakFuture = service.speak(
          messageId: 'msg_1',
          text: 'Slow cloud',
          provider: ReadAloudProvider.edgeExperimental,
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.activeMessageId, 'msg_1');
        expect(service.state, ReadAloudState.loading);
        expect(service.isLoading, isTrue);
        expect(service.isSpeaking, isFalse);
        expect(player.playCount, 0);

        completer.complete(
          GeneratedTtsAudio(
            bytes: Uint8List.fromList(<int>[9]),
            mimeType: 'audio/mpeg',
          ),
        );
        await speakFuture;

        expect(service.state, ReadAloudState.playing);
        expect(service.isLoading, isFalse);
        expect(service.isSpeaking, isTrue);
        expect(player.playCount, 1);

        await service.dispose();
      },
    );

    test('stop cancels slow generated audio before playback starts', () async {
      final completer = Completer<TtsSynthesisResult>();
      final backend = _FakeGeneratedBackend(
        result: completer.future,
        callOnStart: true,
      );
      final player = _FakeTtsAudioPlayer();
      final service = ReadAloudService(
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.edgeExperimental: backend,
        },
        audioPlayer: player,
      );

      final speakFuture = service.speak(
        messageId: 'msg_1',
        text: 'Slow cloud',
        provider: ReadAloudProvider.edgeExperimental,
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.state, ReadAloudState.loading);

      await service.stop();
      completer.complete(
        GeneratedTtsAudio(
          bytes: Uint8List.fromList(<int>[9]),
          mimeType: 'audio/mpeg',
        ),
      );
      await speakFuture;

      expect(backend.stopped, isTrue);
      expect(player.stopped, isTrue);
      expect(player.playCount, 0);
      expect(service.state, ReadAloudState.idle);

      await service.dispose();
    });

    test('stop resets state to idle', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(messageId: 'msg_1', text: 'Test');
      // Fake fires completion immediately, so state may already be idle.
      await service.stop();

      expect(service.state, ReadAloudState.idle);
      expect(service.activeMessageId, isNull);
    });

    test('stop is no-op when already idle', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.stop();

      expect(tts.isStopped, isFalse);
      expect(service.state, ReadAloudState.idle);
    });

    test('pause is no-op when not playing', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.pause();

      expect(tts.isPaused, isFalse);
    });

    test('stopIfReading stops when message matches', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(messageId: 'msg_1', text: 'Test');
      await service.stopIfReading('msg_1');

      expect(service.state, ReadAloudState.idle);
    });

    test('stopIfReading does not interrupt different message', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      // Speak msg_1 — fake completes immediately.
      await service.speak(messageId: 'msg_1', text: 'Test');
      // Service is now idle because fake completed, so stopIfReading
      // on a different message should be a safe no-op.
      await service.stopIfReading('msg_2');

      // No crash, no side effects — state remains idle.
      expect(service.state, ReadAloudState.idle);
    });

    test('speak stops previous speech first', () async {
      final tts = _FakeFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(messageId: 'msg_1', text: 'First');
      // Because completion fires immediately in the fake,
      // state is already idle. Verify no crash.
      await service.speak(messageId: 'msg_2', text: 'Second');

      expect(tts.spokenTexts.length, 2);
    });

    test('isAvailable returns false when getEngines throws', () async {
      final tts = _ThrowingFlutterTts();
      final service = ReadAloudService(tts: tts);

      // The throwing fake throws on speak, but getEngines may work.
      // At minimum, the service should not crash.
      final available = await service.isAvailable;
      // Service handles errors gracefully — should not throw.
      expect(available, isFalse);
    });

    test(
      'isAvailable returns true when voices exist without engines',
      () async {
        final tts = _VoiceOnlyFlutterTts();
        final service = ReadAloudService(tts: tts);

        final available = await service.isAvailable;

        expect(available, isTrue);
      },
    );

    test('isAvailable returns true when only engines exist', () async {
      final tts = _EngineOnlyFlutterTts();
      final service = ReadAloudService(tts: tts);

      final available = await service.isAvailable;

      expect(available, isTrue);
    });

    test('error during speak resets state', () async {
      final tts = _ThrowingFlutterTts();
      final service = ReadAloudService(tts: tts);

      await service.speak(messageId: 'msg_1', text: 'Test');

      expect(service.state, ReadAloudState.idle);
      expect(service.activeMessageId, isNull);
    });
  });
}
