import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../core/logging/app_logger.dart';
import '../utils/speech_engine_platform_support.dart';
import 'sherpa_model_manager.dart';
import 'speech_audio_capture.dart';
import 'speech_input_service.dart';

// Sherpa STT backend using sherpa_onnx OnlineRecognizer with Kroko streaming
// transducer models and SpeechAudioCapture for microphone capture.
// Audio pipeline: AudioRecorder (PCM 16-bit 16kHz mono) → int16→float32
// conversion → sherpa_onnx OnlineStream → partial/final text results.
class SherpaSpeechInputService implements SpeechInputService {
  SherpaSpeechInputService(this._modelManager);

  final SherpaModelManager _modelManager;
  static const _defaultPauseFor = Duration(seconds: 5);
  static const _requiredModelFiles = [
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
  ];
  static bool _bindingsInitialized = false;

  sherpa.OnlineRecognizer? _recognizer;
  SpeechAudioCapture? _capture;
  StreamSubscription<Uint8List>? _audioSub;
  String? _activeLanguage;
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

  @override
  Future<bool> initialize() async {
    if (!SpeechEnginePlatformSupport.isSherpaSupported) {
      _isAvailable = false;
      _unavailableReason = 'Sherpa is unavailable on this platform.';
      _unavailableReasonKey = 'platformUnavailable';
      return false;
    }

    try {
      _ensureBindingsInitialized();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Sherpa bindings initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isAvailable = false;
      _unavailableReason = 'Sherpa runtime failed to initialize.';
      _unavailableReasonKey = 'runtimeFailed';
      return false;
    }

    final preferredLang = _modelManager.getPreferredLanguage();
    if (await _modelManager.hasModel(preferredLang)) {
      await _setActiveLanguage(preferredLang);
      return true;
    }

    final installedLang = await _modelManager.findInstalledLanguage();
    if (installedLang != null) {
      await _setActiveLanguage(installedLang);
      return true;
    }

    _activeLanguage = null;
    _activeModelDir = null;
    _recognizer?.free();
    _recognizer = null;
    // Service is supported on this platform, but no model is installed yet.
    // startListening() will emit `model_required` so the UI can offer download.
    AppLogger.info('Sherpa model unavailable; waiting for user download');
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
    if (localeId != null && localeId.trim().isNotEmpty) {
      final requestedLang = _modelManager.normalizeLanguageCode(localeId);
      if (requestedLang != _activeLanguage) {
        if (await _modelManager.hasModel(requestedLang)) {
          await _setActiveLanguage(requestedLang);
        } else {
          AppLogger.info(
            'Sherpa requested language model missing: $requestedLang',
          );
          _modelManager.setPreferredLanguage(requestedLang);
          _activeLanguage = null;
          _activeModelDir = null;
          _isAvailable = false;
          _recognizer?.free();
          _recognizer = null;
          onStatus('model_required');
          return;
        }
      }
    }

    final modelDir = _activeModelDir;
    if (modelDir == null || !_isAvailable) {
      AppLogger.info('Sherpa listening requested without installed model');
      onStatus('model_required');
      return;
    }

    final missingFiles = _missingModelFiles(modelDir);
    if (missingFiles.isNotEmpty) {
      AppLogger.warn(
        'Sherpa model files missing in $modelDir: ${missingFiles.join(', ')}',
      );
      _isAvailable = false;
      onStatus('model_required');
      return;
    }

    final silenceTimeout = _normalizePauseFor(pauseFor ?? _defaultPauseFor);

    try {
      await _recreateRecognizer(modelDir: modelDir, pauseFor: silenceTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Sherpa recognizer initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isAvailable = false;
      _unavailableReason = 'Sherpa model files are incomplete.';
      _unavailableReasonKey = 'modelIncomplete';
      onError();
      return;
    }

    final recognizer = _recognizer;
    if (recognizer == null) {
      _isAvailable = false;
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

    late final sherpa.OnlineStream stream;
    try {
      stream = recognizer.createStream();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Sherpa stream creation failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isAvailable = false;
      onError();
      return;
    }

    _isListening = true;
    onStatus('listening');

    Timer? silenceTimer;
    var streamFreed = false;
    var doneEmitted = false;

    void freeStreamOnce() {
      if (streamFreed) {
        return;
      }
      streamFreed = true;
      stream.free();
    }

    Future<void> completeListeningSession() async {
      if (doneEmitted) {
        return;
      }
      doneEmitted = true;
      silenceTimer?.cancel();
      freeStreamOnce();
      await stopListening();
      onStatus('done');
    }

    void armSilenceTimer() {
      silenceTimer?.cancel();
      silenceTimer = Timer(silenceTimeout, () {
        if (!_isListening) {
          return;
        }
        unawaited(completeListeningSession());
      });
    }

    armSilenceTimer();

    Stream<Uint8List> audioStream;
    try {
      audioStream = await capture.startPcmStream(
        sampleRate: 16000,
        numChannels: 1,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Sherpa recorder stream start failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isListening = false;
      stream.free();
      _capture = null;
      _applyCaptureFailure(
        speechAudioCaptureFailureInfoForError(error),
        fallback: 'Microphone recording failed.',
      );
      onError();
      return;
    }

    _audioSub = audioStream.listen(
      (chunk) {
        if (!_isListening) return;
        // Convert Int16 PCM bytes to normalized Float32 samples for sherpa.
        final samples = _pcm16ToFloat32(chunk);
        stream.acceptWaveform(samples: samples, sampleRate: 16000);

        // Process all buffered frames.
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
        }

        // Emit partial transcript for live feedback.
        final partial = recognizer.getResult(stream).text.trim();
        if (partial.isNotEmpty) {
          onResult(partial, false);
          armSilenceTimer();
        }

        // Detect utterance endpoint and stop after silence timeout.
        if (recognizer.isEndpoint(stream)) {
          final finalText = recognizer.getResult(stream).text.trim();
          if (finalText.isNotEmpty) {
            onResult(finalText, true);
          }
          unawaited(completeListeningSession());
        }
      },
      onError: (error) {
        silenceTimer?.cancel();
        freeStreamOnce();
        if (doneEmitted) {
          return;
        }
        doneEmitted = true;
        _isListening = false;
        AppLogger.warn('Sherpa audio stream reported an error');
        _applyCaptureFailure(
          speechAudioCaptureFailureInfoForError(error),
          fallback: 'Microphone recording failed.',
        );
        unawaited(stopListening());
        onError();
      },
      onDone: () {
        silenceTimer?.cancel();
        if (doneEmitted) {
          freeStreamOnce();
          return;
        }
        // Flush any remaining frames after the recorder closes.
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
        }
        final finalText = recognizer.getResult(stream).text.trim();
        if (finalText.isNotEmpty) {
          onResult(finalText, true);
        }
        freeStreamOnce();
        doneEmitted = true;
        _isListening = false;
        onStatus('done');
      },
    );
  }

  Future<void> _setActiveLanguage(String lang) async {
    _modelManager.setPreferredLanguage(lang);
    _activeLanguage = lang;
    _activeModelDir = await _modelManager.getModelDir(lang);
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

  Future<void> _recreateRecognizer({
    required String modelDir,
    required Duration pauseFor,
  }) async {
    _ensureBindingsInitialized();
    _recognizer?.free();

    final pauseSeconds = pauseFor.inMilliseconds / 1000.0;
    final rule2TrailingSilence = math.max(0.3, pauseSeconds / 2.0);

    _recognizer = sherpa.OnlineRecognizer(
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
        rule2MinTrailingSilence: rule2TrailingSilence,
        rule3MinUtteranceLength: 20.0,
        maxActivePaths: 4,
      ),
    );
  }

  Duration _normalizePauseFor(Duration pauseFor) {
    final ms = pauseFor.inMilliseconds.clamp(500, 10000).toInt();
    return Duration(milliseconds: ms);
  }

  List<String> _missingModelFiles(String modelDir) {
    return _requiredModelFiles
        .where((file) => !File('$modelDir/$file').existsSync())
        .toList(growable: false);
  }

  void _ensureBindingsInitialized() {
    if (_bindingsInitialized) {
      return;
    }
    sherpa.initBindings();
    _bindingsInitialized = true;
    AppLogger.info('Sherpa bindings initialized');
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

  // Converts raw little-endian Int16 PCM bytes to normalized Float32 samples
  // in the range [-1.0, 1.0] as required by the sherpa_onnx recognizer.
  static Float32List _pcm16ToFloat32(Uint8List bytes) {
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    final samples = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
