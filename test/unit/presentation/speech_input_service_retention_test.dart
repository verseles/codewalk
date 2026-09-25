import 'dart:async';
import 'dart:io';

import 'package:codewalk/presentation/services/moonshine_model_manager.dart';
import 'package:codewalk/presentation/services/nemotron_model_manager.dart';
import 'package:codewalk/presentation/services/parakeet_model_manager.dart';
import 'package:codewalk/presentation/services/sensevoice_model_manager.dart';
import 'package:codewalk/presentation/services/sherpa_model_manager.dart';
import 'package:codewalk/presentation/services/speech_audio_capture.dart';
import 'package:codewalk/presentation/services/speech_input_service_moonshine_io.dart';
import 'package:codewalk/presentation/services/speech_input_service_nemotron_io.dart';
import 'package:codewalk/presentation/services/speech_input_service_parakeet_io.dart';
import 'package:codewalk/presentation/services/speech_input_service_sensevoice_io.dart';
import 'package:codewalk/presentation/services/speech_input_service_sherpa_io.dart';
import 'package:codewalk/presentation/services/speech_model_residency_controller.dart';
import 'package:codewalk/presentation/services/windows_microphone_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class _Parakeet extends ParakeetModelManager {
  _Parakeet(this.path);
  final String path;
  @override
  Future<String> getModelDir(String id) async => path;
}

class _Moonshine extends MoonshineModelManager {
  _Moonshine(this.path);
  final String path;
  @override
  Future<String> getModelDir(String id) async => path;
}

class _SenseVoice extends SenseVoiceModelManager {
  _SenseVoice(this.path);
  final String path;
  @override
  Future<String> getModelDir(String id) async => path;
}

class _Sherpa extends SherpaModelManager {
  _Sherpa(this.path);
  final String path;
  @override
  Future<String> getModelDir(String id) async => path;
}

class _Nemotron extends NemotronModelManager {
  _Nemotron(this.path);
  final String path;
  @override
  Future<String> getModelDir(String id) async => path;
}

class _Capture extends Fake implements SpeechAudioCapture {
  final audio = StreamController<Uint8List>();
  bool permitted = true;
  bool startFails = false;
  bool stopped = false;
  @override
  Future<bool> hasPermission() async => permitted;
  @override
  SpeechAudioCaptureFailureInfo? get lastFailureInfo => null;
  @override
  WindowsMicrophoneAccessStatus? get lastWindowsAccessStatus => null;
  @override
  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    if (startFails) throw StateError('capture');
    return audio.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    unawaited(audio.close());
  }
}

class _Resources {
  int created = 0;
  int freed = 0;
  int streams = 0;
  int liveStreams = 0;
  bool constructionFails = false;
  bool decodeFails = false;
  final languages = <String>[];
  sherpa.OfflineRecognizer offline(sherpa.OfflineRecognizerConfig config) {
    if (constructionFails) throw StateError('construct');
    created++;
    return _Offline(this);
  }

  sherpa.OnlineRecognizer online(sherpa.OnlineRecognizerConfig config) {
    if (constructionFails) throw StateError('construct');
    created++;
    return _Online(this);
  }

  void free() {
    expect(liveStreams, 0, reason: 'streams must be freed before weights');
    freed++;
  }
}

class _Offline extends Fake implements sherpa.OfflineRecognizer {
  _Offline(this.resources);
  final _Resources resources;
  @override
  sherpa.OfflineStream createStream() => _OfflineStream(resources);
  @override
  void decode(sherpa.OfflineStream stream) {
    if (resources.decodeFails) throw StateError('decode');
  }

  @override
  sherpa.OfflineRecognizerResult getResult(sherpa.OfflineStream stream) =>
      sherpa.OfflineRecognizerResult.fromJson({
        'text': 'recording ${resources.streams}',
      });
  @override
  void free() => resources.free();
}

class _OfflineStream extends Fake implements sherpa.OfflineStream {
  _OfflineStream(this.resources) {
    resources.streams++;
    resources.liveStreams++;
  }
  final _Resources resources;
  @override
  void acceptWaveform({
    required Float32List samples,
    required int sampleRate,
  }) {}
  @override
  void free() => resources.liveStreams--;
}

class _Online extends Fake implements sherpa.OnlineRecognizer {
  _Online(this.resources);
  final _Resources resources;
  @override
  sherpa.OnlineStream createStream({String hotwords = ''}) =>
      _OnlineStream(resources);
  @override
  bool isReady(sherpa.OnlineStream stream) {
    if (resources.decodeFails) throw StateError('decode');
    return false;
  }

  @override
  bool isEndpoint(sherpa.OnlineStream stream) => false;
  @override
  sherpa.OnlineRecognizerResult getResult(sherpa.OnlineStream stream) =>
      sherpa.OnlineRecognizerResult(
        text: 'recording ${resources.streams}',
        tokens: [],
        timestamps: [],
      );
  @override
  void free() => resources.free();
}

class _OnlineStream extends Fake implements sherpa.OnlineStream {
  _OnlineStream(this.resources) {
    resources.streams++;
    resources.liveStreams++;
  }
  final _Resources resources;
  @override
  void acceptWaveform({
    required Float32List samples,
    required int sampleRate,
  }) {}
  @override
  void inputFinished() {}
  @override
  void setOption({required String key, required String value}) =>
      resources.languages.add(value);
  @override
  void free() => resources.liveStreams--;
}

void main() {
  final coordinator = SpeechModelResidencyController.instance;
  late Directory dir;
  late _Resources resources;
  late _Capture capture;
  late ResidentSpeechInputService backend;
  var errors = 0;
  var permitted = true;
  var captureStartFails = false;
  final results = <String>[];
  Future<void> start({int seconds = 5, String locale = 'en'}) =>
      backend.startListening(
        onResult: (text, finalResult) {
          if (finalResult) results.add(text);
        },
        onStatus: (_) {},
        onError: () => errors++,
        pauseFor: Duration(seconds: seconds),
        localeId: locale,
      );
  Future<void> speech() async {
    capture.audio.add(
      Uint8List.fromList(List<int>.generate(3200, (i) => i.isEven ? 0 : 64)),
    );
    await Future<void>.delayed(Duration.zero);
  }

  for (final engine in [
    'parakeet',
    'moonshine',
    'sensevoice',
    'sherpa',
    'nemotron',
  ]) {
    group(engine, () {
      setUp(() async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        coordinator.setKeepInMemory(true);
        dir = await Directory.systemTemp.createTemp('speech-retention-');
        for (final file in [
          'encoder.int8.onnx',
          'decoder.int8.onnx',
          'joiner.int8.onnx',
          'tokens.txt',
          'model.int8.onnx',
          'preprocess.onnx',
          'encode.int8.onnx',
          'uncached_decode.int8.onnx',
          'cached_decode.int8.onnx',
          'silero_vad.onnx',
        ]) {
          await File('${dir.path}/$file').writeAsString('fake');
        }
        resources = _Resources();
        errors = 0;
        permitted = true;
        captureStartFails = false;
        results.clear();
        _Capture newCapture() => capture = (_Capture()
          ..permitted = permitted
          ..startFails = captureStartFails);
        backend = switch (engine) {
          'parakeet' => ParakeetSpeechInputService(
            _Parakeet(dir.path),
            recognizerFactory: resources.offline,
            captureFactory: newCapture,
            initializeBindings: () {},
          ),
          'moonshine' => MoonshineSpeechInputService(
            _Moonshine(dir.path),
            recognizerFactory: resources.offline,
            captureFactory: newCapture,
            initializeBindings: () {},
          ),
          'sensevoice' => SenseVoiceSpeechInputService(
            _SenseVoice(dir.path),
            recognizerFactory: resources.offline,
            captureFactory: newCapture,
            initializeBindings: () {},
          ),
          'sherpa' => SherpaSpeechInputService(
            _Sherpa(dir.path),
            recognizerFactory: resources.online,
            captureFactory: newCapture,
            initializeBindings: () {},
          ),
          _ => NemotronSpeechInputService(
            _Nemotron(dir.path),
            recognizerFactory: resources.online,
            captureFactory: newCapture,
            initializeBindings: () {},
          ),
        };
      });
      tearDown(() async {
        await coordinator.dispose();
        await dir.delete(recursive: true);
        debugDefaultTargetPlatformOverride = null;
      });

      test(
        'ten recordings reuse weights with fresh streams and final text before stop',
        () async {
          for (var i = 1; i <= 10; i++) {
            await backend.initialize();
            await start();
            await speech();
            await Future.wait([
              backend.stopListening(),
              backend.stopListening(),
            ]);
            expect(results.last, 'recording $i');
            expect(resources.liveStreams, 0);
            expect(capture.stopped, isTrue);
          }
          expect(resources.created, 1);
          expect(resources.streams, 10);
          expect(resources.freed, 0);
          expect(errors, 0);
        },
      );

      test('opt-out and model replacement release weights', () async {
        await start();
        coordinator.setKeepInMemory(false);
        expect(resources.freed, 0);
        await backend.stopListening();
        expect(resources.freed, 1);
        await start();
        await backend.stopListening();
        expect(resources.created, 2);
        expect(resources.freed, 2);
        coordinator.setKeepInMemory(true);
        await start();
        await backend.stopListening();
        await coordinator.mutateModel(dir.path, () async {});
        await start();
        expect(resources.created, 4);
      });

      test(
        'construction failure leaves no loaded identity and permits next attempt',
        () async {
          resources.constructionFails = true;
          await start();
          expect(backend.residentModelPath, isNull);
          expect(errors, 1);
          resources.constructionFails = false;
          await start();
          expect(backend.isListening, isTrue);
        },
      );

      test(
        'permission denial and capture startup failure release failed resources',
        () async {
          permitted = false;
          await start();
          expect(errors, 1);
          expect(capture.stopped, isTrue);
          expect(resources.freed, 1);
          permitted = true;
          captureStartFails = true;
          await start();
          expect(errors, 2);
          expect(capture.stopped, isTrue);
          expect(resources.freed, 2);
          expect(resources.liveStreams, 0);
        },
      );

      test(
        'decode failure frees streams before invalidating recognizer',
        () async {
          await start();
          resources.decodeFails = true;
          await speech();
          await backend.stopListening();
          await coordinator.stop(null);
          expect(errors, greaterThan(0));
          expect(resources.liveStreams, 0);
          expect(resources.freed, 1);
        },
      );

      if (engine == 'sherpa' || engine == 'nemotron') {
        test('endpoint configuration is part of loaded identity', () async {
          await start(seconds: 2);
          await backend.stopListening();
          await start(seconds: 8);
          expect(resources.created, 2);
          expect(resources.freed, 1);
        });
      }
      if (engine == 'nemotron') {
        test(
          'language belongs to each fresh stream, not the resident weights',
          () async {
            await start(locale: 'en');
            await backend.stopListening();
            await start(locale: 'pt');
            expect(resources.created, 1);
            expect(resources.languages, ['en', 'pt']);
          },
        );
      }
    });
  }
}
