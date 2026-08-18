import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/auth/tts_api_key_storage.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/experience_settings.dart';
import 'tts/generated_tts_audio_player.dart';
import 'tts/native_tts_backend.dart';
import 'tts/tts_backend.dart';
import 'tts/tts_executor.dart';

enum ReadAloudState { idle, loading, playing, paused }

enum ReadAloudErrorKind {
  unavailable,
  missingApiKey,
  invalidApiKey,
  rateLimitedOrQuota,
  network,
  providerUnavailable,
  cancelled,
  unknown,
}

class ReadAloudService extends ChangeNotifier {
  ReadAloudService({
    FlutterTts? tts,
    Map<ReadAloudProvider, TtsBackend>? backends,
    TtsAudioPlayer? audioPlayer,
    TtsApiKeyStorage? apiKeyStorage,
  }) : _backends = _buildBackends(tts: tts, backends: backends),
       _audioPlayer = audioPlayer {
    _executor = TtsExecutor(backends: _backends, apiKeyStorage: apiKeyStorage);
    if (_audioPlayer != null) {
      _attachAudioPlayer(_audioPlayer!);
    }
  }

  static Map<ReadAloudProvider, TtsBackend> _buildBackends({
    required FlutterTts? tts,
    required Map<ReadAloudProvider, TtsBackend>? backends,
  }) {
    final resolved = <ReadAloudProvider, TtsBackend>{...?backends};
    if (!resolved.containsKey(ReadAloudProvider.native) &&
        (backends == null || tts != null)) {
      resolved[ReadAloudProvider.native] = NativeTtsBackend(tts: tts);
    }
    return resolved;
  }

  final Map<ReadAloudProvider, TtsBackend> _backends;
  late final TtsExecutor _executor;
  TtsAudioPlayer? _audioPlayer;
  StreamSubscription<void>? _audioCompleteSubscription;
  StreamSubscription<Duration>? _audioDurationSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  ReadAloudState _state = ReadAloudState.idle;
  String? _activeMessageId;
  int _generation = 0;
  int? _audioPlaybackGeneration;
  Duration? _audioDuration;
  Duration? _audioPosition;
  ReadAloudErrorKind? _lastErrorKind;
  String? _lastErrorMessage;
  String? _lastErrorMessageId;
  int _lastErrorSequence = 0;
  int _consumedErrorSequence = 0;

  ReadAloudState get state => _state;
  String? get activeMessageId => _activeMessageId;
  bool get isSpeaking => _state == ReadAloudState.playing;
  bool get isLoading => _state == ReadAloudState.loading;
  ReadAloudErrorKind? get lastErrorKind => _lastErrorKind;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get lastErrorMessageId => _lastErrorMessageId;
  int get lastErrorSequence => _lastErrorSequence;

  // Progress as a 0.0-1.0 fraction for generated audio when duration is known.
  double? get progress {
    final duration = _audioDuration;
    final position = _audioPosition;
    if (duration == null || position == null || duration.inMilliseconds <= 0) {
      return null;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Whether the platform has a TTS engine available.
  Future<bool> get isAvailable async {
    return isProviderAvailable(ReadAloudProvider.native);
  }

  Future<bool> isProviderAvailable(ReadAloudProvider provider) async {
    final backend = _backendFor(provider);
    return backend.isAvailable;
  }

  /// Speak the given [text] for [messageId].
  /// If already speaking, stops current speech first.
  Future<void> speak({
    required String messageId,
    required String text,
    ReadAloudProvider provider = ReadAloudProvider.native,
    double rate = 0.5,
    double pitch = 1.0,
    String? voice,
    String? voiceId,
    String? voiceLocale,
    String? model,
    String? baseUrl,
    String responseFormat = kDefaultReadAloudResponseFormat,
    String? apiKey,
  }) async {
    if (text.trim().isEmpty) {
      return;
    }

    await _stopActiveSpeech(notify: false);
    final generation = ++_generation;
    final backend = _executor.backendFor(provider);
    _activeMessageId = messageId;
    _audioDuration = null;
    _audioPosition = null;
    _lastErrorKind = null;
    _lastErrorMessage = null;
    _lastErrorMessageId = null;
    _state = ReadAloudState.loading;
    notifyListeners();

    try {
      final configuration = TtsConfiguration(
        provider: provider,
        rate: rate,
        pitch: pitch,
        voiceId: _effectiveVoiceId(voiceId: voiceId, legacyVoice: voice),
        voiceLocale: voiceLocale,
        model: model,
        baseUrl: baseUrl,
        responseFormat: responseFormat,
      );
      final job = SpeechJob(
        jobId: '$messageId:$generation',
        snapshotId: messageId,
        textDigest: Object.hash(text, text.length).toString(),
        speechText: text,
        configurationRevision: configuration.revision,
        configuration: configuration,
      );
      final result = await _executor.play(
        job,
        _callbacksFor(generation, backend.playbackMode, job.jobId),
        apiKeyOverride: apiKey,
      );
      if (!_isCurrentGeneration(generation)) {
        return;
      }
      if (result is NativeTtsStarted) {
        if (_state == ReadAloudState.loading) {
          _state = ReadAloudState.playing;
          notifyListeners();
        }
      } else if (result is GeneratedTtsAudio) {
        _audioPlaybackGeneration = generation;
        await _ensureAudioPlayer().playBytes(
          result.bytes,
          mimeType: result.mimeType,
        );
        if (!_isCurrentGeneration(generation)) {
          return;
        }
        _state = ReadAloudState.playing;
        notifyListeners();
      }
    } catch (error, stackTrace) {
      AppLogger.warn('TTS speak failed', error: error, stackTrace: stackTrace);
      if (_isCurrentGeneration(generation)) {
        if (error is TtsBackendException) {
          _setError(_mapBackendError(error.kind), error.message);
        } else {
          _setError(
            ReadAloudErrorKind.unknown,
            L10nBridge.current?.speechReadAloudFailed ??
                'Text-to-speech failed.',
          );
        }
      }
    }
  }

  /// Pause current speech. No-op if not playing.
  Future<void> pause() async {
    if (_state != ReadAloudState.playing) {
      return;
    }
    try {
      if (_executor.activeJob != null &&
          _executor
                  .backendFor(_executor.activeJob!.configuration.provider)
                  .playbackMode ==
              TtsPlaybackMode.generatedAudio) {
        await _audioPlayer?.pause();
        _state = ReadAloudState.paused;
        notifyListeners();
        return;
      }
      await _executor.pause();
    } catch (error, stackTrace) {
      AppLogger.warn('TTS pause failed', error: error, stackTrace: stackTrace);
    }
  }

  /// Stop current speech and reset state.
  Future<void> stop() async {
    await _stopActiveSpeech(notify: true);
  }

  /// Stop playback if reading the given [messageId].
  /// Used when a message is removed or becomes stale.
  Future<void> stopIfReading(String messageId) async {
    if (_activeMessageId == messageId) {
      await stop();
    }
  }

  bool consumeLastErrorForMessage({
    required String messageId,
    required String message,
    required int sequence,
  }) {
    if (_consumedErrorSequence == sequence ||
        _lastErrorSequence != sequence ||
        _lastErrorMessageId != messageId ||
        _lastErrorMessage != message) {
      return false;
    }
    _consumedErrorSequence = sequence;
    return true;
  }

  /// Release TTS resources. Call when service is no longer needed.
  @override
  Future<void> dispose() async {
    await stop();
    await _audioCompleteSubscription?.cancel();
    await _audioDurationSubscription?.cancel();
    await _audioPositionSubscription?.cancel();
    _executor.dispose();
    await _audioPlayer?.dispose();
    super.dispose();
  }

  // --- Platform capability queries (for settings UI) ---

  /// List of available voices from the platform TTS engine.
  Future<List<Map<String, String>>> getVoices() async {
    return getVoicesForProvider(ReadAloudProvider.native);
  }

  Future<List<Map<String, String>>> getVoicesForProvider(
    ReadAloudProvider provider, {
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final voices = await _backendFor(provider).getVoices(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
    );
    return voices
        .map(
          (voice) => <String, String>{
            'name': voice.id,
            'locale': voice.locale ?? '',
            'label': voice.label,
          },
        )
        .toList();
  }

  /// List of available languages from the platform TTS engine.
  Future<List<String>> getLanguages() async {
    return _backendFor(ReadAloudProvider.native).getLanguages();
  }

  TtsBackend _backendFor(ReadAloudProvider provider) {
    return _backends[provider] ?? _backends[ReadAloudProvider.native]!;
  }

  TtsAudioPlayer _ensureAudioPlayer() {
    final existing = _audioPlayer;
    if (existing != null) {
      return existing;
    }
    final player = AudioplayersTtsAudioPlayer();
    _audioPlayer = player;
    _attachAudioPlayer(player);
    return player;
  }

  void _attachAudioPlayer(TtsAudioPlayer player) {
    _audioCompleteSubscription = player.onComplete.listen((_) {
      final playbackGeneration = _audioPlaybackGeneration;
      if (playbackGeneration != null) {
        _completeGeneratedAudio(playbackGeneration);
      }
    });
    _audioDurationSubscription = player.onDurationChanged.listen((value) {
      _audioDuration = value;
      notifyListeners();
    });
    _audioPositionSubscription = player.onPositionChanged.listen((value) {
      _audioPosition = value;
      notifyListeners();
    });
  }

  String? _effectiveVoiceId({
    required String? voiceId,
    required String? legacyVoice,
  }) {
    final explicit = voiceId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final legacy = legacyVoice?.trim();
    return legacy != null && legacy.isNotEmpty ? legacy : null;
  }

  TtsBackendCallbacks _callbacksFor(
    int generation,
    TtsPlaybackMode playbackMode,
    String jobId,
  ) {
    return TtsBackendCallbacks(
      onStart: () {
        if (!_isCurrentGeneration(generation)) return;
        if (playbackMode != TtsPlaybackMode.nativeEngine) return;
        if (_state != ReadAloudState.loading) return;
        _state = ReadAloudState.playing;
        notifyListeners();
      },
      onComplete: () => _completeNativeSpeech(generation, jobId),
      onCancel: () => _completeNativeSpeech(generation, jobId),
      onPause: () {
        if (!_isCurrentGeneration(generation)) return;
        _state = ReadAloudState.paused;
        notifyListeners();
      },
      onContinue: () {
        if (!_isCurrentGeneration(generation)) return;
        _state = ReadAloudState.playing;
        notifyListeners();
      },
      onError: (message) {
        if (!_isCurrentGeneration(generation)) return;
        AppLogger.warn('TTS error: $message');
        _setError(ReadAloudErrorKind.providerUnavailable, message);
      },
    );
  }

  Future<void> _stopActiveSpeech({required bool notify}) async {
    if (_state == ReadAloudState.idle && _executor.activeJob == null) {
      return;
    }
    _generation += 1;
    try {
      await _executor.stop();
      await _audioPlayer?.stop();
    } catch (error, stackTrace) {
      AppLogger.warn('TTS stop failed', error: error, stackTrace: stackTrace);
    }
    _resetPlaybackState(clearError: false);
    if (notify) {
      notifyListeners();
    }
  }

  bool _isCurrentGeneration(int generation) => generation == _generation;

  void _completeNativeSpeech(int generation, String jobId) {
    if (!_isCurrentGeneration(generation)) {
      return;
    }
    _executor.complete(jobId);
    _resetPlaybackState(clearError: false);
    notifyListeners();
  }

  void _completeGeneratedAudio(int generation) {
    if (!_isCurrentGeneration(generation)) {
      return;
    }
    _executor.completeActive();
    _resetPlaybackState(clearError: false);
    notifyListeners();
  }

  void _setError(ReadAloudErrorKind kind, String message) {
    _lastErrorKind = kind;
    _lastErrorMessage = message;
    _lastErrorMessageId = _activeMessageId;
    _lastErrorSequence += 1;
    _executor.completeActive();
    _resetPlaybackState(clearError: false);
    notifyListeners();
  }

  void _resetPlaybackState({required bool clearError}) {
    _state = ReadAloudState.idle;
    _activeMessageId = null;
    _audioPlaybackGeneration = null;
    _audioDuration = null;
    _audioPosition = null;
    if (clearError) {
      _lastErrorKind = null;
      _lastErrorMessage = null;
      _lastErrorMessageId = null;
      _consumedErrorSequence = _lastErrorSequence;
    }
  }

  ReadAloudErrorKind _mapBackendError(TtsBackendErrorKind kind) {
    return switch (kind) {
      TtsBackendErrorKind.missingApiKey => ReadAloudErrorKind.missingApiKey,
      TtsBackendErrorKind.invalidApiKey => ReadAloudErrorKind.invalidApiKey,
      TtsBackendErrorKind.rateLimitedOrQuota =>
        ReadAloudErrorKind.rateLimitedOrQuota,
      TtsBackendErrorKind.network => ReadAloudErrorKind.network,
      TtsBackendErrorKind.providerUnavailable =>
        ReadAloudErrorKind.providerUnavailable,
      TtsBackendErrorKind.invalidRequest => ReadAloudErrorKind.unavailable,
      TtsBackendErrorKind.unknown => ReadAloudErrorKind.unknown,
    };
  }
}
