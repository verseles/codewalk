import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/i18n/l10n_bridge.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/experience_settings.dart';
import 'elevenlabs_tts_backend.dart' show extractDioErrorMessage;
import 'tts_backend.dart';

/// Normalized character limits per NVIDIA Speech NIM TTS request. Chatterbox
/// models accept fewer characters than the rest of the NIM TTS catalog.
int nimTtsCharLimit(String model) {
  return model.toLowerCase().contains('chatterbox') ? 500 : 2000;
}

class NvidiaNimTtsBackend implements TtsBackend {
  NvidiaNimTtsBackend({Dio? dio})
    : _dio = dio ?? Dio(),
      _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.nim;

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
    final base = _effectiveBaseUrl(baseUrl);
    if (key == null || key.isEmpty || base.isEmpty) {
      return const <TtsVoiceOption>[];
    }
    try {
      final response = await _dio.get<dynamic>(
        '$base/audio/list_voices',
        options: Options(
          responseType: ResponseType.json,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: <String, String>{
            'Authorization': 'Bearer $key',
            'Accept': 'application/json',
          },
        ),
      );
      return _parseVoices(response.data);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'NVIDIA NIM voice list request failed',
        error: error,
        stackTrace: stackTrace,
        tags: <String>{'tts', 'nim'},
      );
      return const <TtsVoiceOption>[];
    }
  }

  @override
  Future<List<String>> getLanguages() async => const <String>[];

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
    final base = _effectiveBaseUrl(request.baseUrl);
    if (base.isEmpty) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechNimBaseUrlRequired ??
            'Enter the NVIDIA NIM deployment base URL in Settings > Speech.',
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
    final voice = request.voiceId?.trim();
    if (voice == null || voice.isEmpty) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechReadAloudNoVoice ??
            'Select a voice for this TTS provider.',
      );
    }
    final model = _effectiveModel(request.model);
    final limit = nimTtsCharLimit(model);
    if (text.length > limit) {
      throw TtsBackendException(
        TtsBackendErrorKind.invalidRequest,
        L10nBridge.current?.speechProviderTextTooLong ??
            'The text is too long for this TTS model.',
      );
    }
    final language = _effectiveLanguage(request.voiceLocale);
    try {
      final formData = FormData.fromMap(<String, dynamic>{
        'text': text,
        'voice': voice,
        'language': language,
        'model': model,
      });
      final response = await _dio.post<List<int>>(
        '$base/audio/synthesize',
        data: formData,
        options: Options(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Accept': 'audio/wav',
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
      if (!_isWav(data)) {
        throw TtsBackendException(
          TtsBackendErrorKind.providerUnavailable,
          L10nBridge.current?.speechProviderInvalidAudio ??
              'The TTS provider returned unrecognized audio.',
        );
      }
      return GeneratedTtsAudio(
        bytes: Uint8List.fromList(data),
        mimeType: 'audio/wav',
      );
    } on DioException catch (error) {
      throw mapNimDioException(error);
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
    } else if (data is Map) {
      // Tolerate a Map of voice id -> name.
      for (final entry in data.entries) {
        voices.add(
          TtsVoiceOption(
            id: entry.key.toString(),
            label: entry.value.toString(),
          ),
        );
      }
      return voices;
    } else {
      return voices;
    }
    for (final entry in entries) {
      if (entry is! Map) continue;
      final id = entry['voice_id']?.toString() ?? entry['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final name = entry['name']?.toString() ?? entry['voice']?.toString();
      final language = entry['language']?.toString();
      final locale = entry['locale']?.toString() ?? entry['language_code']?.toString();
      voices.add(
        TtsVoiceOption(
          id: id,
          label: (name != null && name.isNotEmpty) ? name : id,
          locale: locale ?? language,
        ),
      );
    }
    return voices;
  }

  String _effectiveModel(String? model) {
    final trimmed = model?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : kDefaultNimTtsModel;
  }

  String _effectiveLanguage(String? voiceLocale) {
    final trimmed = voiceLocale?.trim().toLowerCase();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : 'en';
  }

  String _effectiveBaseUrl(String? baseUrl) {
    final trimmed = baseUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return kDefaultNimTtsBaseUrl;
    }
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  bool _isWav(List<int> bytes) {
    if (bytes.length < 12) {
      return false;
    }
    final prefix = String.fromCharCodes(bytes.take(4));
    return prefix == 'RIFF';
  }
}

TtsBackendException mapNimDioException(DioException error) {
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