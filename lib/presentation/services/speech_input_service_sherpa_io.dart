import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../core/logging/app_logger.dart';
import '../utils/speech_engine_platform_support.dart';
import 'sherpa_model_manager.dart';
import 'speech_audio_capture.dart';
import 'speech_model_residency_controller.dart';

// Sherpa STT backend using sherpa_onnx OnlineRecognizer with Kroko streaming
// transducer models and SpeechAudioCapture for microphone capture.
// Audio pipeline: AudioRecorder (PCM 16-bit 16kHz mono) → int16→float32
// conversion → sherpa_onnx OnlineStream → partial/final text results.
class SherpaSpeechInputService with ResidentSpeechInputService {
  SherpaSpeechInputService(
    this._modelManager, {
    this.recognizerFactory,
    this.captureFactory = SpeechAudioCapture.new,
    this.initializeBindings,
  });

  final sherpa.OnlineRecognizer Function(sherpa.OnlineRecognizerConfig)?
  recognizerFactory;
  final SpeechAudioCapture Function() captureFactory;
  final void Function()? initializeBindings;

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
  String? _loadedModelDir;
  Duration? _loadedPauseFor;
  Future<void> Function()? _finishOnStop;
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
  Future<bool> initializeBackend() async {
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
    releaseResidentModel();
    // Service is supported on this platform, but no model is installed yet.
    // startListening() will emit `model_required` so the UI can offer download.
    AppLogger.info('Sherpa model unavailable; waiting for user download');
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
          releaseResidentModel();
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

    final capture = captureFactory();
    _capture = capture;

    final hasPermission = await capture.hasPermission();
    if (!hasPermission) {
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
          stream.inputFinished();
          while (recognizer.isReady(stream)) {
            recognizer.decode(stream);
          }
          final text = recognizer.getResult(stream).text.trim();
          if (text.isNotEmpty) onResult(text, true);
        } catch (error, stackTrace) {
          AppLogger.error(
            'Sherpa final flush failed',
            error: error,
            stackTrace: stackTrace,
          );
          onError();
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
        if (!_isListening) {
          return;
        }
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
        'Sherpa recorder stream start failed',
        error: error,
        stackTrace: stackTrace,
      );
      _isListening = false;
      doneEmitted = true;
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
            unawaited(completeListeningSession());
          }
        } catch (error, stackTrace) {
          AppLogger.error(
            'Sherpa decode failed',
            error: error,
            stackTrace: stackTrace,
          );
          onError();
        }
      },
      onError: (error) {
        silenceTimer?.cancel();
        freeStreamOnce();
        if (doneEmitted) {
          return;
        }
        doneEmitted = true;
        _finishOnStop = null;
        _isListening = false;
        AppLogger.warn('Sherpa audio stream reported an error');
        _applyCaptureFailure(
          speechAudioCaptureFailureInfoForError(error),
          fallback: 'Microphone recording failed.',
        );
        onError();
      },
      onDone: () {
        if (!doneEmitted) unawaited(completeListeningSession());
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
    if (_recognizer != null &&
        _loadedModelDir == modelDir &&
        _loadedPauseFor == pauseFor) {
      return;
    }
    releaseResidentModel();

    final pauseSeconds = pauseFor.inMilliseconds / 1000.0;
    final rule2TrailingSilence = math.max(0.3, pauseSeconds / 2.0);

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
        rule2MinTrailingSilence: rule2TrailingSilence,
        rule3MinUtteranceLength: 20.0,
        maxActivePaths: 4,
      ),
    );
    _loadedModelDir = modelDir;
    _loadedPauseFor = pauseFor;
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
    if (initializeBindings != null) {
      initializeBindings!();
      return;
    }
    if (_bindingsInitialized) {
      return;
    }
    sherpa.initBindings();
    _bindingsInitialized = true;
    AppLogger.info('Sherpa bindings initialized');
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
