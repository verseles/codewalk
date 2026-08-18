import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/i18n/l10n_bridge.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/experience_settings.dart';
import 'tts_backend.dart';

const String kElevenLabsOutputFormat = 'mp3';

/// ElevenLabs `voice_settings.speed` is validated to the 0.7–1.2 range.
/// Mapping the read-aloud rate (0.0–1.0) into that range keeps the slider
/// meaningful and always accepted by the API.
double elevenLabsSpeedFromReadAloudRate(double rate) {
  final clamped = rate.clamp(0.0, 1.0);
  return 0.7 + clamped * 0.5;
}

/// Character limits per ElevenLabs model. Unknown models are not preflight
/// restricted so providers can add models without client changes.
int? elevenLabsModelCharLimit(String model) {
  final normalized = model.trim().toLowerCase();
  return switch (normalized) {
    'eleven_v3' => 5000,
    'eleven_flash_v2_5' => 40000,
    'eleven_multilingual_v2' => 10000,
    _ => null,
  };
}

class ElevenLabsTtsBackend implements TtsBackend, TtsModelDiscovery {
  ElevenLabsTtsBackend({Dio? dio})
    : _dio = dio ?? Dio(),
      _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;

  /// Provider-reported character limits per model, scoped by normalized base
  /// URL and keyed by lowercase model id. Populated whenever a model list is
  /// fetched; synthesis falls back to the static map when a model (or the
  /// current base URL) was never fetched.
  final Map<String, Map<String, int>> _modelCharLimits =
      <String, Map<String, int>>{};

  /// Monotonic counter so an overlapping, older model-list request cannot
  /// overwrite limits fetched for the current context.
  int _modelsFetchGeneration = 0;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.elevenLabs;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.generatedAudio;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final key = apiKey?.trim();
    if (key == null || key.isEmpty) {
      return const <TtsVoiceOption>[];
    }
    try {
      final response = await _dio.get<dynamic>(
        '${_normalizeBaseUrl(baseUrl)}/voices',
        options: Options(
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: <String, String>{
            'xi-api-key': key,
            'Accept': 'application/json',
          },
        ),
      );
      return _parseVoices(response.data);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'ElevenLabs voice list request failed',
        error: error,
        stackTrace: stackTrace,
        tags: <String>{'tts', 'elevenlabs'},
      );
      return const <TtsVoiceOption>[];
    }
  }

  @override
  Future<List<String>> getLanguages() async => const <String>[];

  @override
  Future<List<TtsModelOption>> getModels({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final key = apiKey?.trim();
    if (key == null || key.isEmpty) {
      return const <TtsModelOption>[];
    }
    // The cache must only reflect the most recent fetch; limits learned from
    // a previous base URL/account must not leak into the current context.
    final generation = ++_modelsFetchGeneration;
    _modelCharLimits.clear();
    final base = _normalizeBaseUrl(baseUrl);
    try {
      final response = await _dio.get<dynamic>(
        '$base/models',
        options: Options(
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: <String, String>{
            'xi-api-key': key,
            'Accept': 'application/json',
          },
        ),
      );
      return _parseModels(response.data,
          generation: generation, baseUrl: base);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'ElevenLabs model list request failed',
        error: error,
        stackTrace: stackTrace,
        tags: <String>{'tts', 'elevenlabs'},
      );
      return const <TtsModelOption>[];
    }
  }

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    final apiKey = request.apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw TtsBackendException(
        TtsBackendErrorKind.missingApiKey,
        L10nBridge.current?.speechApiKeyMissing ??
            'Add an API key in Settings > Speech to use this TTS provider.',
      );
    }
    final text = request.text.trim();
    if (text.isEmpty) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechReadAloudNoText ??
            'There is no text to read aloud.',
      );
    }
    final voice = _effectiveVoice(request.voiceId);
    if (voice == null) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechReadAloudNoVoice ??
            'Select a voice for this TTS provider.',
      );
    }
    final model = _effectiveModel(request.model);
    final limit = _charLimitFor(model, request.baseUrl);
    if (limit != null && text.length > limit) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechProviderTextTooLong ??
            'The text is too long for this TTS model.',
      );
    }
    try {
      final response = await _dio.post<List<int>>(
        '${_normalizeBaseUrl(request.baseUrl)}/text-to-speech/'
        '${Uri.encodeComponent(voice)}',
        data: <String, dynamic>{
          'text': text,
          'model_id': model,
          'output_format': kElevenLabsOutputFormat,
          'voice_settings': <String, double>{
            'speed': elevenLabsSpeedFromReadAloudRate(request.rate),
          },
        },
        options: Options(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: <String, String>{
            'xi-api-key': apiKey,
            'Accept': 'audio/mpeg',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw TtsBackendException(
          TtsBackendErrorKind.providerUnavailable,
          L10nBridge.current?.speechProviderEmptyAudio ??
              'The TTS provider returned an empty audio response.',
        );
      }
      return GeneratedTtsAudio(
        bytes: Uint8List.fromList(data),
        mimeType: 'audio/mpeg',
      );
    } on DioException catch (error) {
      throw mapElevenLabsDioException(error);
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  void dispose() {
    if (_ownsDio) {
      _dio.close(force: true);
    }
  }

  List<TtsVoiceOption> _parseVoices(dynamic data) {
    final voices = <TtsVoiceOption>[];
    final Iterable<dynamic> entries;
    if (data is List) {
      entries = data;
    } else if (data is Map && data['voices'] is List) {
      entries = data['voices'] as List<dynamic>;
    } else {
      return voices;
    }
    for (final entry in entries) {
      if (entry is! Map) continue;
      final id = entry['voice_id']?.toString();
      final name = entry['name']?.toString();
      if (id == null || id.isEmpty) continue;
      final labels = entry['labels'];
      final category = labels is Map ? labels['category']?.toString() : null;
      voices.add(
        TtsVoiceOption(
          id: id,
          label: (name != null && name.isNotEmpty) ? name : id,
          providerMetadata: <String, String>{
            if (category != null && category.isNotEmpty) 'category': category,
          },
        ),
      );
    }
    return voices;
  }

  List<TtsModelOption> _parseModels(
    Object? data, {
    required int generation,
    required String baseUrl,
  }) {
    if (data is! List) {
      return const <TtsModelOption>[];
    }
    final models = <TtsModelOption>[];
    for (final entry in data) {
      if (entry is! Map) continue;
      final id = entry['model_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final canSynthesize = entry['can_do_text_to_speech'];
      if (canSynthesize == false) continue;
      final name = entry['name']?.toString();
      final maxCharacters = entry['max_characters_request'] is num
          ? (entry['max_characters_request'] as num).toInt()
          : null;
      if (maxCharacters != null && generation == _modelsFetchGeneration) {
        _modelCharLimits.putIfAbsent(baseUrl, () => <String, int>{})[
            id.toLowerCase()] = maxCharacters;
      }
      models.add(
        TtsModelOption(
          id: id,
          label: (name != null && name.isNotEmpty) ? name : id,
          maxCharacters: maxCharacters,
        ),
      );
    }
    return models;
  }

  int? _charLimitFor(String model, String? baseUrl) {
    final normalized = model.trim().toLowerCase();
    final limits = _modelCharLimits[_normalizeBaseUrl(baseUrl)];
    return limits?[normalized] ?? elevenLabsModelCharLimit(model);
  }

  String _effectiveModel(String? model) {
    final trimmed = model?.trim();
    return trimmed != null && trimmed.isNotEmpty
        ? trimmed
        : kDefaultElevenLabsTtsModel;
  }

  String? _effectiveVoice(String? voiceId) {
    final trimmed = voiceId?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : null;
  }

  String _normalizeBaseUrl(String? baseUrl) {
    final normalized =
        (baseUrl?.trim().isNotEmpty == true
            ? baseUrl!.trim()
            : kDefaultElevenLabsTtsBaseUrl)
            .replaceFirst(RegExp(r'/+$'), '');
    return normalized;
  }
}

TtsBackendException mapElevenLabsDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  final message = extractDioErrorMessage(error);
  if (statusCode == 400 || statusCode == 404 || statusCode == 422) {
    return TtsBackendException(
      TtsBackendErrorKind.invalidRequest,
      message ??
          (L10nBridge.current?.speechProviderRequestRejected ??
              'The TTS provider rejected the speech request.'),
      statusCode: statusCode,
    );
  }
  if (statusCode == 401 || statusCode == 403) {
    return TtsBackendException(
      TtsBackendErrorKind.invalidApiKey,
      message ??
          (L10nBridge.current?.speechApiKeyRejected ??
              'The TTS API key was rejected by the provider.'),
      statusCode: statusCode,
    );
  }
  if (statusCode == 429) {
    return TtsBackendException(
      TtsBackendErrorKind.rateLimitedOrQuota,
      message ??
          (L10nBridge.current?.speechProviderQuotaRateLimit ??
              'The TTS provider reported a quota or rate limit.'),
      statusCode: statusCode,
    );
  }
  if (statusCode != null && statusCode >= 500) {
    return TtsBackendException(
      TtsBackendErrorKind.providerUnavailable,
      message ??
          (L10nBridge.current?.speechProviderTemporarilyUnavailable ??
              'The TTS provider is temporarily unavailable.'),
      statusCode: statusCode,
    );
  }
  return TtsBackendException(
    TtsBackendErrorKind.network,
    message ??
        (L10nBridge.current?.speechProviderUnreachable ??
            'The TTS provider could not be reached.'),
    statusCode: statusCode,
  );
}

/// Tolerant extraction of a human-readable message from a provider error
/// body. Handles ElevenLabs `detail` objects, NIM `detail` strings, and any
/// JSON/string body without logging request credentials.
String? extractDioErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data == null) return null;
  final String raw;
  if (data is String) {
    raw = data;
  } else if (data is List<int>) {
    raw = utf8.decode(data, allowMalformed: true);
  } else if (data is Map || data is List) {
    raw = jsonEncode(data);
  } else {
    raw = data.toString();
  }
  if (raw.trim().isEmpty) {
    return null;
  }
  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    // Plain-text error bodies (for example "Rate limit hit") carry a useful
    // message even though they are not JSON.
    return _truncate(raw);
  }
  if (decoded is Map) {
    final detail = decoded['detail'];
    if (detail is String) {
      return _truncate(detail);
    }
    if (detail is Map) {
      final detailMessage = detail['message']?.toString();
      if (detailMessage != null && detailMessage.isNotEmpty) {
        return _truncate(detailMessage);
      }
    }
    final message = decoded['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return _truncate(message);
    }
    return null;
  }
  if (decoded is String && decoded.isNotEmpty) {
    return _truncate(decoded);
  }
  return null;
}

String? _truncate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 200)}…';
}