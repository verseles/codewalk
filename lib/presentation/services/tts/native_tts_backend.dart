import 'package:flutter_tts/flutter_tts.dart';

import '../../../domain/entities/experience_settings.dart';
import 'tts_backend.dart';

class NativeTtsBackend implements TtsBackend {
  NativeTtsBackend({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  ReadAloudProvider get provider => ReadAloudProvider.native;

  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.nativeEngine;

  @override
  Future<bool> get isAvailable async {
    if ((await getVoices()).isNotEmpty) {
      return true;
    }
    if ((await getLanguages()).isNotEmpty) {
      return true;
    }
    try {
      final engines = await _tts.getEngines;
      return engines is Iterable && engines.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    _tts.setStartHandler(() => callbacks.onStart?.call());
    _tts.setCompletionHandler(() => callbacks.onComplete?.call());
    _tts.setErrorHandler((message) => callbacks.onError?.call(message));
    _tts.setCancelHandler(() => callbacks.onCancel?.call());
    _tts.setPauseHandler(() => callbacks.onPause?.call());
    _tts.setContinueHandler(() => callbacks.onContinue?.call());

    await _tts.setSpeechRate(request.rate);
    await _tts.setPitch(request.pitch);
    final voiceId = request.voiceId?.trim();
    if (voiceId != null && voiceId.isNotEmpty) {
      final voice = await _resolveVoice(voiceId, request.voiceLocale);
      if (voice == null) {
        await _tts.speak(request.text);
        return const NativeTtsStarted();
      }
      try {
        await _tts.setVoice({
          'name': voice.id,
          if (voice.locale != null && voice.locale!.isNotEmpty)
            'locale': voice.locale!,
        });
      } catch (_) {
        // Voice catalogs can become stale after OS voice changes; fall back to
        // the platform default instead of failing the whole read-aloud action.
      }
    }

    await _tts.speak(request.text);
    return const NativeTtsStarted();
  }

  Future<TtsVoiceOption?> _resolveVoice(String voiceId, String? locale) async {
    final voices = await getVoices();
    final explicit = locale?.trim();
    for (final voice in voices) {
      if (voice.id == voiceId) {
        if (explicit != null && explicit.isNotEmpty) {
          return TtsVoiceOption(
            id: voice.id,
            label: voice.label,
            locale: explicit,
          );
        }
        return voice;
      }
    }
    if (voices.isEmpty && explicit != null && explicit.isNotEmpty) {
      return TtsVoiceOption(id: voiceId, label: voiceId, locale: explicit);
    }
    return null;
  }

  @override
  Future<void> pause() async {
    await _tts.pause();
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async {
    try {
      final voices = await _tts.getVoices;
      return voices.map<TtsVoiceOption>((dynamic value) {
        final map = value is Map ? value : const <String, dynamic>{};
        final name = map['name']?.toString() ?? '';
        final locale = map['locale']?.toString();
        return TtsVoiceOption(
          id: name,
          label: locale != null && locale.isNotEmpty ? '$name ($locale)' : name,
          locale: locale,
        );
      }).toList();
    } catch (_) {
      return const <TtsVoiceOption>[];
    }
  }

  @override
  Future<List<String>> getLanguages() async {
    try {
      final languages = await _tts.getLanguages;
      return languages
          .map<String>((dynamic value) => value.toString())
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  @override
  void dispose() {}
}
