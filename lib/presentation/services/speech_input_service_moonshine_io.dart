import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../core/logging/app_logger.dart';
import '../utils/speech_engine_platform_support.dart';
import 'moonshine_model_manager.dart';
import 'speech_audio_capture.dart';
import 'speech_input_service.dart';

@visibleForTesting
class MoonshineAudioBuffer {
  final List<double> _samples = <double>[];

  void add(Float32List chunk) {
    _samples.addAll(chunk);
  }

  Float32List takeAll() {
    final data = Float32List.fromList(_samples);
    _samples.clear();
    return data;
  }

  bool get isEmpty => _samples.isEmpty;
}

@visibleForTesting
bool moonshineChunkHasSpeech(Float32List samples, {double threshold = 0.015}) {
  if (samples.isEmpty) {
    return false;
  }
  var sum = 0.0;
  for (final sample in samples) {
    sum += sample.abs();
  }
  return (sum / samples.length) >= threshold;
}

// Moonshine desktop backend using sherpa_onnx OfflineRecognizer.
// Linux/macOS microphone capture uses `record`; Windows uses CodeWalk WASAPI.
class MoonshineSpeechInputService implements SpeechInputService {
  MoonshineSpeechInputService(this._modelManager);

  final MoonshineModelManager _modelManager;
  static const _sampleRate = 16000;
  static bool _bindingsInitialized = false;

  sherpa.OfflineRecognizer? _recognizer;
  SpeechAudioCapture? _capture;
  StreamSubscription<Uint8List>? _audioSub;
  String? _activeModelDir;
  bool _isListening = false;
  bool _isAvailable = false;
  String? _unavailableReason;
  String? _unavailableReasonKey;

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  String? get unavailableReason => _unavailableReason;

  @override
  String? get unavailableReasonKey => _unavailableReasonKey;

  bool get _isDesktopSupported {
    return SpeechEnginePlatformSupport.isMoonshineSupported;
  }

  @override
  Future<bool> initialize() async {
    if (!_isDesktopSupported) {
      _unavailableReason = 'Moonshine is available on desktop only.';
      _unavailableReasonKey = 'desktopOnly';
      _isAvailable = false;
      return false;
    }

    try {
      _ensureBindingsInitialized();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Moonshine bindings initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      _unavailableReason = 'Moonshine runtime failed to initialize.';
      _unavailableReasonKey = 'runtimeFailed';
      _isAvailable = false;
      return false;
    }

    final preferred = _modelManager.getPreferredModelId();
    if (await _modelManager.hasModel(preferred)) {
      await _setActiveModel(preferred);
      return true;
    }

    final installed = await _modelManager.findInstalledModelId();
    if (installed != null) {
      await _setActiveModel(installed);
      return true;
    }

    _activeModelDir = null;
    _recognizer?.free();
    _recognizer = null;
    _unavailableReason = null;
    _isAvailable = false;
    return true;
  }

  @override
  Future<void> startListening({
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

    try {
      _recreateRecognizer(modelDir);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Moonshine recognizer initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isAvailable = false;
      _unavailableReason = 'Moonshine model files are incomplete.';
      _unavailableReasonKey = 'modelIncomplete';
      onError();
      return;
    }

    final recognizer = _recognizer;
    if (recognizer == null) {
      onError();
      return;
    }

    final capture = SpeechAudioCapture();
    _capture = capture;
    final hasPermission = await capture.hasPermission();
    if (!hasPermission) {
      _capture = null;
      _applyCaptureFailure(
        capture.lastFailureInfo ??
            speechAudioCaptureFailureInfoForStatus(
              capture.lastWindowsAccessStatus,
            ),
      );
      onError();
      return;
    }

    _isListening = true;
    onStatus('listening');

    final timeout = pauseFor ?? const Duration(seconds: 5);
    const maxUtteranceDuration = Duration(seconds: 15);
    final buffer = MoonshineAudioBuffer();
    Timer? silenceTimer;
    Timer? maxDurationTimer;
    var completed = false;

    Future<void> finishSession() async {
      if (completed) {
        return;
      }
      completed = true;
      silenceTimer?.cancel();
      maxDurationTimer?.cancel();
      final utterance = buffer.takeAll();
      await stopListening();
      if (utterance.isNotEmpty) {
        final stream = recognizer.createStream();
        try {
          stream.acceptWaveform(samples: utterance, sampleRate: _sampleRate);
          recognizer.decode(stream);
          final text = recognizer.getResult(stream).text.trim();
          if (text.isNotEmpty) {
            onResult(text, true);
          }
        } catch (error, stackTrace) {
          AppLogger.error(
            'Moonshine offline decode failed',
            error: error,
            stackTrace: stackTrace,
          );
          onError();
          return;
        } finally {
          stream.free();
        }
      }
      onStatus('done');
    }

    void armSilenceTimer() {
      silenceTimer?.cancel();
      silenceTimer = Timer(timeout, () {
        if (!_isListening) {
          return;
        }
        unawaited(finishSession());
      });
    }

    Stream<Uint8List> audioStream;
    try {
      audioStream = await capture.startPcmStream(
        sampleRate: _sampleRate,
        numChannels: 1,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Moonshine recorder stream start failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isListening = false;
      _capture = null;
      _applyCaptureFailure(
        speechAudioCaptureFailureInfoForError(error),
        fallback: 'Microphone recording failed.',
      );
      onError();
      return;
    }

    maxDurationTimer = Timer(maxUtteranceDuration, () {
      if (!_isListening) {
        return;
      }
      unawaited(finishSession());
    });
    armSilenceTimer();

    _audioSub = audioStream.listen(
      (chunk) {
        if (!_isListening) {
          return;
        }
        final samples = _pcm16ToFloat32(chunk);
        buffer.add(samples);
        if (moonshineChunkHasSpeech(samples)) {
          armSilenceTimer();
        }
      },
      onError: (error) {
        silenceTimer?.cancel();
        maxDurationTimer?.cancel();
        if (completed) {
          return;
        }
        completed = true;
        _isListening = false;
        _applyCaptureFailure(
          speechAudioCaptureFailureInfoForError(error),
          fallback: 'Microphone recording failed.',
        );
        unawaited(stopListening());
        onError();
      },
      onDone: () {
        if (!completed) {
          unawaited(finishSession());
        }
      },
    );
  }

  Future<void> _setActiveModel(String modelId) async {
    _modelManager.setPreferredModelId(modelId);
    _activeModelDir = await _modelManager.getModelDir(modelId);
    _unavailableReason = null;
    _unavailableReasonKey = null;
    _isAvailable = true;
  }

  void _applyCaptureFailure(
    SpeechAudioCaptureFailureInfo info, {
    String fallback = 'Microphone permission is disabled.',
    String fallbackKey = 'microphoneDenied',
  }) {
    _unavailableReason = info.reason ?? fallback;
    _unavailableReasonKey = info.reasonKey ?? fallbackKey;
  }

  void _recreateRecognizer(String modelDir) {
    _recognizer?.free();
    _recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          moonshine: sherpa.OfflineMoonshineModelConfig(
            preprocessor: '$modelDir/preprocess.onnx',
            encoder: '$modelDir/encode.int8.onnx',
            uncachedDecoder: '$modelDir/uncached_decode.int8.onnx',
            cachedDecoder: '$modelDir/cached_decode.int8.onnx',
          ),
          tokens: '$modelDir/tokens.txt',
          numThreads: 1,
          provider: 'cpu',
          debug: false,
        ),
      ),
    );
  }

  void _ensureBindingsInitialized() {
    if (_bindingsInitialized) {
      return;
    }
    sherpa.initBindings();
    _bindingsInitialized = true;
  }

  @override
  Future<void> stopListening() async {
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
