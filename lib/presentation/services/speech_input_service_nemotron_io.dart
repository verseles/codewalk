import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../core/logging/app_logger.dart';
import '../utils/speech_engine_platform_support.dart';
import 'nemotron_language.dart';
import 'nemotron_model_manager.dart';
import 'speech_audio_capture.dart';
import 'speech_model_residency_controller.dart';

class NemotronSpeechInputService with ResidentSpeechInputService {
  NemotronSpeechInputService(
    this._modelManager, {
    this.recognizerFactory,
    this.captureFactory = SpeechAudioCapture.new,
    this.initializeBindings,
  });

  final sherpa.OnlineRecognizer Function(sherpa.OnlineRecognizerConfig)?
  recognizerFactory;
  final SpeechAudioCapture Function() captureFactory;
  final void Function()? initializeBindings;

  final NemotronModelManager _modelManager;
  static const _requiredModelFiles = <String>[
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
  ];
  static const _defaultPauseFor = Duration(seconds: 5);
  static bool _bindingsInitialized = false;

  sherpa.OnlineRecognizer? _recognizer;
  String? _loadedModelDir;
  Duration? _loadedPauseFor;
  Future<void>? _finishInFlight;

  @override
  String? get residentModelPath => _loadedModelDir;

  @override
  void releaseResidentModel() {
    final recognizer = _recognizer;
    _recognizer = null;
    _loadedModelDir = null;
    _loadedPauseFor = null;
    recognizer?.free();
  }

  SpeechAudioCapture? _capture;
  StreamSubscription<Uint8List>? _audioSub;
  String? _activeModelDir;
  bool _isListening = false;
  bool _isAvailable = false;
  String? _unavailableReason;
  String? _unavailableReasonKey;
  Future<void> Function()? _finishOnStop;

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  String? get unavailableReason => _unavailableReason;

  @override
  String? get unavailableReasonKey => _unavailableReasonKey;

  @override
  Future<bool> initializeBackend() async {
    if (!SpeechEnginePlatformSupport.isNemotronSupported) {
      _unavailableReason = 'Nemotron is available on desktop only.';
      _unavailableReasonKey = 'desktopOnly';
      _isAvailable = false;
      return false;
    }
    try {
      _ensureBindingsInitialized();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Nemotron bindings initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      _unavailableReason = 'Nemotron runtime failed to initialize.';
      _unavailableReasonKey = 'runtimeFailed';
      _isAvailable = false;
      return false;
    }
    final preferred = _modelManager.getPreferredModelId();
    if (await _modelManager.hasModel(preferred)) {
      _activeModelDir = await _modelManager.getModelDir(preferred);
      _unavailableReason = null;
      _unavailableReasonKey = null;
      _isAvailable = true;
      return true;
    }
    final installed = await _modelManager.findInstalledModelId();
    if (installed != null) {
      _modelManager.setPreferredModelId(installed);
      _activeModelDir = await _modelManager.getModelDir(installed);
      _unavailableReason = null;
      _unavailableReasonKey = null;
      _isAvailable = true;
      return true;
    }
    _activeModelDir = null;
    releaseResidentModel();
    _isAvailable = false;
    return true;
  }

  @override
  Future<void> startBackend({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) async {
    final modelDir = _activeModelDir;
    if (modelDir == null || !_isAvailable) {
      onStatus('model_required');
      return;
    }
    if (_requiredModelFiles.any(
      (file) => !File('$modelDir/$file').existsSync(),
    )) {
      _isAvailable = false;
      onStatus('model_required');
      return;
    }
    final silenceTimeout = _normalizePauseFor(pauseFor ?? _defaultPauseFor);
    final language = nemotronLanguageForLocale(localeId);
    try {
      _recreateRecognizer(modelDir: modelDir, pauseFor: silenceTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Nemotron recognizer initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isAvailable = false;
      _unavailableReason = 'Nemotron model files are incomplete.';
      _unavailableReasonKey = 'modelIncomplete';
      onError();
      return;
    }
    final recognizer = _recognizer;
    if (recognizer == null) {
      onError();
      return;
    }
    final capture = captureFactory();
    _capture = capture;
    if (!await capture.hasPermission()) {
      _applyCaptureFailure(
        capture.lastFailureInfo ??
            speechAudioCaptureFailureInfoForStatus(
              capture.lastWindowsAccessStatus,
            ),
      );
      onError();
      return;
    }
    late final sherpa.OnlineStream stream;
    var streamCreated = false;
    try {
      stream = recognizer.createStream();
      streamCreated = true;
      stream.setOption(key: 'language', value: language);
    } catch (error, stackTrace) {
      if (streamCreated) {
        stream.free();
      }
      AppLogger.error(
        'Nemotron stream creation failed',
        error: error,
        stackTrace: stackTrace,
      );
      onError();
      return;
    }
    _isListening = true;
    onStatus('listening');
    Timer? silenceTimer;
    var streamFreed = false;
    var doneEmitted = false;
    void freeStreamOnce() {
      if (streamFreed) return;
      streamFreed = true;
      stream.free();
    }

    void flushFinalText() {
      try {
        stream.inputFinished();
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
        }
        final text = recognizer.getResult(stream).text.trim();
        if (text.isNotEmpty) {
          onResult(text, true);
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'Nemotron final flush failed',
          error: error,
          stackTrace: stackTrace,
        );
        onError();
      }
    }

    Future<void> completeListeningSession() async {
      final inFlight = _finishInFlight;
      if (inFlight != null) {
        await inFlight;
        return;
      }
      if (doneEmitted) return;
      doneEmitted = true;
      _finishOnStop = null;
      silenceTimer?.cancel();
      final done = () async {
        try {
          await _releaseCapture();
          flushFinalText();
        } finally {
          freeStreamOnce();
        }
        onStatus('done');
      }();
      _finishInFlight = done;
      try {
        await done;
      } finally {
        _finishInFlight = null;
      }
    }

    _finishOnStop = completeListeningSession;

    void armSilenceTimer() {
      silenceTimer?.cancel();
      silenceTimer = Timer(silenceTimeout, () {
        if (!_isListening) return;
        unawaited(completeListeningSession());
      });
    }

    Stream<Uint8List> audioStream;
    try {
      audioStream = await capture.startPcmStream(
        sampleRate: 16000,
        numChannels: 1,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Nemotron recorder stream start failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isListening = false;
      doneEmitted = true;
      silenceTimer?.cancel();
      _finishOnStop = null;
      freeStreamOnce();
      _applyCaptureFailure(
        speechAudioCaptureFailureInfoForError(error),
        fallback: 'Microphone recording failed.',
      );
      onError();
      return;
    }
    armSilenceTimer();
    _audioSub = audioStream.listen(
      (chunk) {
        if (!_isListening) return;
        try {
          final samples = _pcm16ToFloat32(chunk);
          stream.acceptWaveform(samples: samples, sampleRate: 16000);
          while (recognizer.isReady(stream)) {
            recognizer.decode(stream);
          }
          final partial = recognizer.getResult(stream).text.trim();
          if (partial.isNotEmpty) {
            onResult(partial, false);
            armSilenceTimer();
          }
          if (recognizer.isEndpoint(stream)) {
            unawaited(completeListeningSession());
          }
        } catch (error, stackTrace) {
          AppLogger.error(
            'Nemotron decode failed',
            error: error,
            stackTrace: stackTrace,
          );
          onError();
        }
      },
      onError: (error) {
        silenceTimer?.cancel();
        freeStreamOnce();
        if (doneEmitted) return;
        doneEmitted = true;
        _finishOnStop = null;
        _isListening = false;
        _applyCaptureFailure(
          speechAudioCaptureFailureInfoForError(error),
          fallback: 'Microphone recording failed.',
        );
        unawaited(stopListening());
        onError();
      },
      onDone: () {
        if (!doneEmitted) unawaited(completeListeningSession());
      },
    );
  }

  void _recreateRecognizer({
    required String modelDir,
    required Duration pauseFor,
  }) {
    _ensureBindingsInitialized();
    if (_recognizer != null &&
        _loadedModelDir == modelDir &&
        _loadedPauseFor == pauseFor) {
      return;
    }
    releaseResidentModel();
    final pauseSeconds = pauseFor.inMilliseconds / 1000.0;
    _recognizer = (recognizerFactory ?? sherpa.OnlineRecognizer.new)(
      sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: '$modelDir/encoder.int8.onnx',
            decoder: '$modelDir/decoder.int8.onnx',
            joiner: '$modelDir/joiner.int8.onnx',
          ),
          tokens: '$modelDir/tokens.txt',
          numThreads: 2,
          provider: 'cpu',
          debug: false,
        ),
        decodingMethod: 'greedy_search',
        enableEndpoint: true,
        rule1MinTrailingSilence: pauseSeconds,
        rule2MinTrailingSilence: math.max(0.3, pauseSeconds / 2.0),
        rule3MinUtteranceLength: 20.0,
        maxActivePaths: 4,
      ),
    );
    _loadedModelDir = modelDir;
    _loadedPauseFor = pauseFor;
  }

  Duration _normalizePauseFor(Duration pauseFor) {
    return Duration(milliseconds: pauseFor.inMilliseconds.clamp(500, 10000));
  }

  void _ensureBindingsInitialized() {
    if (initializeBindings != null) {
      initializeBindings!();
      return;
    }
    if (_bindingsInitialized) return;
    sherpa.initBindings();
    _bindingsInitialized = true;
  }

  void _applyCaptureFailure(
    SpeechAudioCaptureFailureInfo info, {
    String fallback = 'Microphone permission is disabled.',
    String fallbackKey = 'microphoneDenied',
  }) {
    _unavailableReason = info.reason ?? fallback;
    _unavailableReasonKey = info.reasonKey ?? fallbackKey;
  }

  @override
  Future<void> stopBackend() async {
    final inFlight = _finishInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final finish = _finishOnStop;
    if (finish != null) {
      _finishOnStop = null;
      await finish();
      return;
    }
    await _releaseCapture();
  }

  Future<void> _releaseCapture() async {
    _isListening = false;
    await _audioSub?.cancel();
    _audioSub = null;
    final capture = _capture;
    _capture = null;
    if (capture != null) {
      await capture.stop();
    }
  }

  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    final samples = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
