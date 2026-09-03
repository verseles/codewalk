import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'speech_input_service.dart';
import 'windows_microphone_service.dart';

// speech_to_text backend for iOS, macOS, Web, and mobile-native targets.
// Moves the STT logic that previously lived inline in _ChatInputWidgetState.
class SttSpeechInputService implements SpeechInputService {
  SttSpeechInputService({WindowsMicrophoneService? windowsMicrophoneService})
    : _windowsMicrophoneService =
          windowsMicrophoneService ?? const WindowsMicrophoneService();

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final WindowsMicrophoneService _windowsMicrophoneService;

  bool _isAvailable = false;
  Future<bool>? _initialization;
  String? _lastUnavailableReason;
  String? _lastUnavailableReasonKey;

  void Function(String status)? _onStatus;
  void Function()? _onError;

  @override
  bool get isListening => _speechToText.isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  String? get unavailableReason => _lastUnavailableReason;

  // Stable reason key for the most recent init failure. Used by the UI to
  // pick the right actionable Windows settings link without re-parsing text.
  @override
  String? get unavailableReasonKey => _lastUnavailableReasonKey;

  @override
  Future<bool> initialize() async {
    if (_isAvailable) return true;

    final inFlight = _initialization;
    if (inFlight != null) {
      return inFlight;
    }

    final initialization = _initializeSpeechEngine();
    _initialization = initialization;
    try {
      return await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }

  Future<bool> _initializeSpeechEngine() async {
    _lastUnavailableReason = null;
    _lastUnavailableReasonKey = null;
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (isWindows) {
      _isAvailable = false;
      _lastUnavailableReasonKey = 'nativeDisabled';
      _lastUnavailableReason =
          'Native Windows speech recognition is disabled for stability. Use an on-device engine with CodeWalk WASAPI microphone capture.';
      return false;
    }
    try {
      _isAvailable = await _speechToText.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (!_isAvailable) {
        _lastUnavailableReason = await _buildUnavailableReason();
      }
      return _isAvailable;
    } catch (_) {
      _isAvailable = false;
      _lastUnavailableReason = await _buildUnavailableReason(
        fallback: 'Native speech engine failed to initialize.',
      );
      return false;
    }
  }

  Future<String> _buildUnavailableReason({String? fallback}) async {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (isWindows) {
      final probe = await _windowsMicrophoneService.probe();
      switch (probe) {
        case WindowsMicrophoneAccessStatus.denied:
          _lastUnavailableReasonKey = 'microphoneDenied';
          return 'Microphone access is blocked by Windows privacy settings.';
        case WindowsMicrophoneAccessStatus.noInputDevice:
          _lastUnavailableReasonKey = 'noInputDevice';
          return 'No microphone input device is available.';
        case WindowsMicrophoneAccessStatus.deviceBusy:
          _lastUnavailableReasonKey = 'deviceBusy';
          return 'The default microphone is currently in use by another app.';
        case WindowsMicrophoneAccessStatus.unsupportedFormat:
          _lastUnavailableReasonKey = 'unsupportedFormat';
          return 'The default microphone format is not supported.';
        case WindowsMicrophoneAccessStatus.unknown:
          _lastUnavailableReasonKey = 'speechPrivacy';
          return 'Windows speech services may be disabled (speech privacy, online speech recognition, or language packs).';
        case WindowsMicrophoneAccessStatus.notSupported:
        case WindowsMicrophoneAccessStatus.allowed:
          break;
      }
    }

    final permissionGranted = await _speechToText.hasPermission;
    if (!permissionGranted) {
      _lastUnavailableReasonKey = 'microphoneDenied';
      return 'Microphone permission is disabled.';
    }

    final errorMessage = _speechToText.lastError?.errorMsg.trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      _lastUnavailableReasonKey = 'generic';
      return errorMessage;
    }

    if (isWindows) {
      _lastUnavailableReasonKey = 'speechPrivacy';
      return 'Check Windows speech privacy, online speech recognition, and installed speech language packs.';
    }

    _lastUnavailableReasonKey = 'generic';
    return fallback ?? 'Native speech engine is unavailable on this device.';
  }

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function() onError,
    Duration? pauseFor,
    String? localeId,
  }) async {
    _onStatus = onStatus;
    _onError = onError;

    // Enable auto-punctuation (question marks, periods) on platforms that
    // support it via native speech APIs (iOS and macOS only).
    final supportsAutoPunctuation =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    await _speechToText.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      // Wait for the specified silence window before auto-stopping.
      // Android enforces a system minimum of ~1-3s regardless of this value.
      // NOTE: kept as top-level args (not SpeechListenOptions) because 7.4.0
      // ships broken Android sources; revisit when unpinning speech_to_text.
      pauseFor: pauseFor ?? const Duration(seconds: 5),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        autoPunctuation: supportsAutoPunctuation,
      ),
      localeId: localeId,
    );
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
    } catch (_) {
      // Ignore platform stop errors to keep compose flow resilient.
    }
  }

  void _handleStatus(String status) {
    _onStatus?.call(status);
  }

  void _handleError(SpeechRecognitionError error) {
    final message = error.errorMsg.trim();
    if (message.isNotEmpty) {
      _lastUnavailableReason = message;
    }
    _onError?.call();
  }
}
