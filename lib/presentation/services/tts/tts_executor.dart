import '../../../core/auth/tts_api_key_storage.dart';
import '../../../core/i18n/l10n_bridge.dart';
import '../../../domain/entities/experience_settings.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';
import 'tts_backend.dart';

class TtsConfiguration {
  const TtsConfiguration({
    required this.provider,
    required this.rate,
    required this.pitch,
    required this.responseFormat,
    this.voiceId,
    this.voiceLocale,
    this.model,
    this.baseUrl,
  });

  factory TtsConfiguration.fromSettings(ExperienceSettings settings) {
    return TtsConfiguration(
      provider: settings.readAloudProvider,
      rate: settings.readAloudRate,
      pitch: settings.readAloudPitch,
      voiceId: settings.readAloudVoiceId ?? settings.readAloudVoice,
      voiceLocale: settings.readAloudVoiceLocale,
      model: settings.readAloudModel,
      baseUrl: settings.readAloudBaseUrl,
      responseFormat: settings.readAloudResponseFormat,
    );
  }

  final ReadAloudProvider provider;
  final double rate;
  final double pitch;
  final String? voiceId;
  final String? voiceLocale;
  final String? model;
  final String? baseUrl;
  final String responseFormat;

  int get revision => Object.hash(
    provider,
    rate,
    pitch,
    voiceId,
    voiceLocale,
    model,
    baseUrl,
    responseFormat,
  );
}

class SpeechJob {
  const SpeechJob({
    required this.jobId,
    required this.snapshotId,
    required this.textDigest,
    required this.speechText,
    required this.configurationRevision,
    required this.configuration,
    this.identity,
  });

  final String jobId;
  final String snapshotId;
  final SessionAttentionIdentity? identity;
  final String textDigest;
  final String speechText;
  final int configurationRevision;
  final TtsConfiguration configuration;
}

class TtsExecutor {
  TtsExecutor({
    required Map<ReadAloudProvider, TtsBackend> backends,
    TtsApiKeyStorage? apiKeyStorage,
  }) : _backends = backends,
       _apiKeyStorage = apiKeyStorage;

  final Map<ReadAloudProvider, TtsBackend> _backends;
  final TtsApiKeyStorage? _apiKeyStorage;
  TtsBackend? _activeBackend;
  SpeechJob? _activeJob;
  int _generation = 0;
  Future<void>? _pendingStop;
  int _stopGeneration = 0;

  SpeechJob? get activeJob => _activeJob;

  TtsBackend backendFor(ReadAloudProvider provider) {
    return _backends[provider] ?? _backends[ReadAloudProvider.native]!;
  }

  Future<TtsSynthesisResult> play(
    SpeechJob job,
    TtsBackendCallbacks callbacks, {
    String? apiKeyOverride,
  }) async {
    final backend = backendFor(job.configuration.provider);
    final generation = ++_generation;
    final previousBackend = _activeBackend;
    _activeBackend = backend;
    _activeJob = job;
    await _queueStop(previousBackend);
    _ensureCurrent(generation, job);
    final apiKey =
        apiKeyOverride ?? await _apiKeyFor(job.configuration.provider);
    _ensureCurrent(generation, job);
    return backend.speakOrSynthesize(
      TtsSynthesisRequest(
        text: job.speechText,
        rate: job.configuration.rate,
        pitch: job.configuration.pitch,
        voiceId: job.configuration.voiceId,
        voiceLocale: job.configuration.voiceLocale,
        model: job.configuration.model,
        baseUrl: job.configuration.baseUrl,
        responseFormat: job.configuration.responseFormat,
        apiKey: apiKey,
      ),
      callbacks,
    );
  }

  Future<void> stop() async {
    _generation += 1;
    final backend = _activeBackend;
    _activeBackend = null;
    _activeJob = null;
    await _queueStop(backend);
  }

  Future<void> pause() => _activeBackend?.pause() ?? Future<void>.value();

  void complete(String jobId) {
    if (_activeJob?.jobId != jobId) {
      return;
    }
    _generation += 1;
    _activeBackend = null;
    _activeJob = null;
  }

  void completeActive() {
    final jobId = _activeJob?.jobId;
    if (jobId != null) {
      complete(jobId);
    }
  }

  void _ensureCurrent(int generation, SpeechJob job) {
    if (_generation != generation || !identical(_activeJob, job)) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechJobCancelled ?? 'Speech job was cancelled.',
      );
    }
  }

  Future<void> _queueStop(TtsBackend? backend) {
    final generation = ++_stopGeneration;
    final queued = _stopAfter(
      previous: _pendingStop,
      backend: backend,
      generation: generation,
    );
    _pendingStop = queued;
    return queued;
  }

  Future<void> _stopAfter({
    required Future<void>? previous,
    required TtsBackend? backend,
    required int generation,
  }) async {
    try {
      if (previous != null) await previous;
    } catch (_) {
      // A failed stop must not prevent later jobs from stopping their backend.
    }
    try {
      await backend?.stop();
    } finally {
      if (_stopGeneration == generation) _pendingStop = null;
    }
  }

  Future<String?> _apiKeyFor(ReadAloudProvider provider) async {
    if (provider != ReadAloudProvider.openAiCompatible) {
      return null;
    }
    try {
      return await _apiKeyStorage?.read(provider);
    } on TtsApiKeyStorageException catch (error) {
      throw TtsBackendException(
        TtsBackendErrorKind.providerUnavailable,
        error.message,
      );
    }
  }

  void dispose() {
    _generation += 1;
    _activeBackend = null;
    _activeJob = null;
    for (final backend in _backends.values) {
      backend.dispose();
    }
  }
}
