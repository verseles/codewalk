import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/i18n/l10n_bridge.dart';
import '../../../domain/entities/experience_settings.dart';
import 'tts_backend.dart';

const List<String> kOpenAiCompatibleVoiceIds = <String>[
  'alloy',
  'ash',
  'ballad',
  'coral',
  'echo',
  'fable',
  'nova',
  'onyx',
  'sage',
  'shimmer',
  'verse',
  'marin',
  'cedar',
];

class OpenAiCompatibleTtsBackend implements TtsBackend {
  OpenAiCompatibleTtsBackend({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.openAiCompatible;

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
    return kOpenAiCompatibleVoiceIds
        .map((id) => TtsVoiceOption(id: id, label: id))
        .toList(growable: false);
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

    final format = _normalizeResponseFormat(request.responseFormat);
    try {
      final response = await _dio.post<List<int>>(
        speechEndpointForOpenAiCompatible(request.baseUrl),
        data: <String, dynamic>{
          'model': _effectiveModel(request.model),
          'input': request.text,
          'voice': _effectiveVoice(request.voiceId),
          'response_format': format,
          'speed': openAiSpeedFromReadAloudRate(request.rate),
        },
        options: Options(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Accept': mimeTypeForOpenAiAudioFormat(format),
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
        mimeType: mimeTypeForOpenAiAudioFormat(format),
      );
    } on DioException catch (error) {
      throw mapOpenAiCompatibleDioException(error);
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  void dispose() {}
}

double openAiSpeedFromReadAloudRate(double rate) {
  return (0.5 + (rate.clamp(0.0, 1.0) * 1.5)).clamp(0.5, 2.0);
}

String speechEndpointForOpenAiCompatible(String? baseUrl) {
  final normalized =
      (baseUrl?.trim().isNotEmpty == true
              ? baseUrl!.trim()
              : kDefaultOpenAiCompatibleTtsBaseUrl)
          .replaceFirst(RegExp(r'/+$'), '');
  return '$normalized/audio/speech';
}

String mimeTypeForOpenAiAudioFormat(String format) {
  return switch (format.trim().toLowerCase()) {
    'wav' => 'audio/wav',
    'opus' => 'audio/opus',
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'pcm' => 'audio/pcm',
    _ => 'audio/mpeg',
  };
}

TtsBackendException mapOpenAiCompatibleDioException(DioException error) {
  final statusCode = error.response?.statusCode;
  if (statusCode == 400) {
    return TtsBackendException(
      TtsBackendErrorKind.invalidRequest,
      L10nBridge.current?.speechProviderRequestRejected ??
          'The TTS provider rejected the speech request.',
      statusCode: statusCode,
    );
  }
  if (statusCode == 401 || statusCode == 403) {
    return TtsBackendException(
      TtsBackendErrorKind.invalidApiKey,
      L10nBridge.current?.speechApiKeyRejected ??
          'The TTS API key was rejected by the provider.',
      statusCode: statusCode,
    );
  }
  if (statusCode == 429) {
    return TtsBackendException(
      TtsBackendErrorKind.rateLimitedOrQuota,
      L10nBridge.current?.speechProviderQuotaRateLimit ??
          'The TTS provider reported a quota or rate limit.',
      statusCode: statusCode,
    );
  }
  if (statusCode != null && statusCode >= 500) {
    return TtsBackendException(
      TtsBackendErrorKind.providerUnavailable,
      L10nBridge.current?.speechProviderTemporarilyUnavailable ??
          'The TTS provider is temporarily unavailable.',
      statusCode: statusCode,
    );
  }
  return TtsBackendException(
    TtsBackendErrorKind.network,
    L10nBridge.current?.speechProviderUnreachable ??
        'The TTS provider could not be reached.',
    statusCode: statusCode,
  );
}

String _effectiveModel(String? model) {
  final trimmed = model?.trim();
  return trimmed != null && trimmed.isNotEmpty
      ? trimmed
      : kDefaultOpenAiCompatibleTtsModel;
}

String _effectiveVoice(String? voiceId) {
  final trimmed = voiceId?.trim();
  return trimmed != null && trimmed.isNotEmpty ? trimmed : 'alloy';
}

String _normalizeResponseFormat(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isNotEmpty ? normalized : kDefaultReadAloudResponseFormat;
}
