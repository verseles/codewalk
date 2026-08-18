import 'dart:typed_data';

import '../../../domain/entities/experience_settings.dart';

enum TtsPlaybackMode { nativeEngine, generatedAudio }

enum TtsBackendErrorKind {
  missingApiKey,
  invalidApiKey,
  rateLimitedOrQuota,
  network,
  providerUnavailable,
  invalidRequest,
  unknown,
}

class TtsBackendException implements Exception {
  const TtsBackendException(this.kind, this.message, {this.statusCode});

  final TtsBackendErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'TtsBackendException: $message'
      : 'TtsBackendException: $message ($statusCode)';
}

typedef TtsVoidCallback = void Function();
typedef TtsErrorCallback = void Function(String message);

class TtsBackendCallbacks {
  const TtsBackendCallbacks({
    this.onStart,
    this.onComplete,
    this.onCancel,
    this.onPause,
    this.onContinue,
    this.onError,
  });

  final TtsVoidCallback? onStart;
  final TtsVoidCallback? onComplete;
  final TtsVoidCallback? onCancel;
  final TtsVoidCallback? onPause;
  final TtsVoidCallback? onContinue;
  final TtsErrorCallback? onError;
}

class TtsVoiceOption {
  const TtsVoiceOption({
    required this.id,
    required this.label,
    this.locale,
    this.providerMetadata = const <String, String>{},
  });

  final String id;
  final String label;
  final String? locale;
  final Map<String, String> providerMetadata;
}

class TtsSynthesisRequest {
  const TtsSynthesisRequest({
    required this.text,
    required this.rate,
    required this.pitch,
    this.voiceId,
    this.voiceLocale,
    this.model,
    this.baseUrl,
    this.responseFormat = kDefaultReadAloudResponseFormat,
    this.apiKey,
  });

  final String text;
  final double rate;
  final double pitch;
  final String? voiceId;
  final String? voiceLocale;
  final String? model;
  final String? baseUrl;
  final String responseFormat;
  final String? apiKey;
}

sealed class TtsSynthesisResult {
  const TtsSynthesisResult();
}

class NativeTtsStarted extends TtsSynthesisResult {
  const NativeTtsStarted();
}

class GeneratedTtsAudio extends TtsSynthesisResult {
  const GeneratedTtsAudio({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

abstract class TtsBackend {
  ReadAloudProvider get provider;
  TtsPlaybackMode get playbackMode;
  Future<bool> get isAvailable;
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  });
  Future<List<String>> getLanguages();
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  );
  Future<void> stop();
  Future<void> pause();
  void dispose();
}
