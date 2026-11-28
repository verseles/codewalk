import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../shared/voice/read_aloud.dart';

/// The cloud providers' speech over HTTPS (#541): OpenAI-compatible
/// servers, ElevenLabs and NVIDIA Speech NIM. Keys go only in the headers
/// each provider expects; errors carry a status, never text or keys.
final class CloudSpeech implements SpeechSynthesizer {
  CloudSpeech(this.provider, {HttpClient Function()? client})
    : _client = client ?? HttpClient.new;

  final SpeechProvider provider;
  final HttpClient Function() _client;

  static const _connect = Duration(seconds: 10);
  static const _total = Duration(seconds: 45);
  static const _maxAudio = 16 * 1024 * 1024;

  /// The longest text each provider takes in one request; longer text is
  /// refused rather than cut.
  static const maxCharacters = {
    SpeechProvider.openAi: 4096,
    SpeechProvider.elevenLabs: 10000,
    SpeechProvider.nim: 2000,
  };

  static const defaultBase = speechDefaultBase;
  static const defaultModel = {
    SpeechProvider.openAi: 'gpt-4o-mini-tts',
    SpeechProvider.elevenLabs: 'eleven_multilingual_v2',
  };
  static const defaultVoice = {
    SpeechProvider.openAi: 'alloy',
    SpeechProvider.elevenLabs: '21m00Tcm4TlvDq8ikWAM',
  };

  /// The provider's route under [base], whether or not [base] ends in /v1.
  static Uri endpoint(String base, String path) {
    var root = base.trim();
    while (root.endsWith('/')) {
      root = root.substring(0, root.length - 1);
    }
    if (!root.endsWith('/v1')) root = '$root/v1';
    return Uri.parse('$root$path');
  }

  Uri _base(ReadAloudSettings settings, String path) {
    final base = settings.baseUrl ?? defaultBase[provider];
    if (base == null) throw const SpeechException(SpeechFailure.notConfigured);
    final Uri uri;
    try {
      uri = endpoint(base, path);
    } on FormatException {
      throw const SpeechException(SpeechFailure.notConfigured, 'address');
    }
    // Text and keys never travel in the clear beyond the local network.
    if (uri.host.isEmpty || !speechAddressSecure(uri)) {
      throw const SpeechException(SpeechFailure.notConfigured, 'address');
    }
    return uri;
  }

  @override
  Future<SpeechAudio> synthesize(
    SpeechRequest request,
    SpeechCancel cancel,
  ) async {
    final text = request.text;
    final limit = maxCharacters[provider]!;
    if (text.runes.length > limit) {
      throw const SpeechException(SpeechFailure.tooLong);
    }
    final key = request.apiKey;
    final settings = request.settings;
    if (provider != SpeechProvider.nim && (key == null || key.isEmpty)) {
      throw const SpeechException(SpeechFailure.notConfigured);
    }
    switch (provider) {
      case SpeechProvider.openAi:
        final body = utf8.encode(
          jsonEncode({
            'model': settings.model ?? defaultModel[provider],
            'input': text,
            'voice': settings.voice ?? defaultVoice[provider],
            'response_format': 'mp3',
            // 0.0–1.0, normal at 0.5: 0.5x to 2x.
            'speed': 0.5 * pow(4, settings.rate),
          }),
        );
        final bytes = await _send(
          'POST',
          _base(settings, '/audio/speech'),
          headers: {
            'authorization': 'Bearer $key',
            'content-type': 'application/json',
          },
          body: body,
          cancel: cancel,
        );
        return SpeechAudio(bytes, 'audio/mpeg');
      case SpeechProvider.elevenLabs:
        final voice = settings.voice ?? defaultVoice[provider]!;
        final uri = _base(
          settings,
          '/text-to-speech/${Uri.encodeComponent(voice)}',
        ).replace(queryParameters: {'output_format': 'mp3_44100_128'});
        final bytes = await _send(
          'POST',
          uri,
          headers: {'xi-api-key': key!, 'content-type': 'application/json'},
          body: utf8.encode(
            jsonEncode({
              'text': text,
              'model_id': settings.model ?? defaultModel[provider],
              // ElevenLabs takes 0.7–1.2.
              'voice_settings': {'speed': 0.7 + 0.5 * settings.rate},
            }),
          ),
          cancel: cancel,
        );
        return SpeechAudio(bytes, 'audio/mpeg');
      case SpeechProvider.nim:
        final boundary = 'codewalk${Random().nextInt(1 << 30)}';
        final fields = {
          'text': text,
          'language': _language(settings.voice, request.locale),
          'voice': ?settings.voice,
          'model': ?settings.model,
        };
        final body = StringBuffer();
        fields.forEach((name, value) {
          body
            ..write('--$boundary\r\n')
            ..write('Content-Disposition: form-data; name="$name"\r\n\r\n')
            ..write(value)
            ..write('\r\n');
        });
        body.write('--$boundary--\r\n');
        final bytes = await _send(
          'POST',
          _base(settings, '/audio/synthesize'),
          headers: {
            if (key != null && key.isNotEmpty) 'authorization': 'Bearer $key',
            'content-type': 'multipart/form-data; boundary=$boundary',
          },
          body: utf8.encode(body.toString()),
          cancel: cancel,
        );
        return SpeechAudio(bytes, 'audio/wav');
      case SpeechProvider.edge || SpeechProvider.system:
        throw const SpeechException(SpeechFailure.unavailable);
    }
  }

  /// A NIM voice names its language (`English-US.Female-1`); otherwise the
  /// app's, as a BCP 47 tag with a region.
  static String _language(String? voice, String locale) {
    final known = {
      'English-US': 'en-US',
      'Spanish-US': 'es-US',
      'German-DE': 'de-DE',
      'French-FR': 'fr-FR',
      'Italian-IT': 'it-IT',
      'Mandarin-CN': 'zh-CN',
    };
    for (final entry in known.entries) {
      if (voice?.startsWith(entry.key) ?? false) return entry.value;
    }
    return locale.contains('-') ? locale : 'en-US';
  }

  @override
  Future<List<SpeechVoice>> voices(SpeechRequest request) async {
    final settings = request.settings;
    final key = request.apiKey;
    switch (provider) {
      case SpeechProvider.elevenLabs:
        if (key == null || key.isEmpty) {
          throw const SpeechException(SpeechFailure.notConfigured);
        }
        final bytes = await _send(
          'GET',
          _base(settings, '/voices'),
          headers: {'xi-api-key': key},
          cancel: SpeechCancel(),
        );
        final json = jsonDecode(utf8.decode(bytes));
        final list = json is Map ? json['voices'] : null;
        return [
          if (list is List)
            for (final voice in list)
              if (voice is Map &&
                  voice['voice_id'] is String &&
                  voice['name'] is String)
                SpeechVoice(
                  id: voice['voice_id'] as String,
                  label: voice['name'] as String,
                ),
        ];
      case SpeechProvider.nim:
        final bytes = await _send(
          'GET',
          _base(settings, '/audio/list_voices'),
          headers: {
            if (key != null && key.isNotEmpty) 'authorization': 'Bearer $key',
          },
          cancel: SpeechCancel(),
        );
        final json = jsonDecode(utf8.decode(bytes));
        return [
          if (json is Map)
            for (final entry in json.entries)
              if (entry.value case {'voices': final List list})
                for (final voice in list)
                  if (voice is String)
                    SpeechVoice(
                      id: voice,
                      label: voice,
                      locale: entry.key as String?,
                    ),
        ];
      case SpeechProvider.openAi:
        return [
          for (final voice in const [
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
          ])
            SpeechVoice(id: voice, label: voice),
        ];
      case SpeechProvider.edge || SpeechProvider.system:
        return const [];
    }
  }

  Future<Uint8List> _send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    List<int>? body,
    required SpeechCancel cancel,
  }) async {
    final client = _client()..connectionTimeout = _connect;
    // A stop drops the connection at once.
    final forget = cancel.onCancel(() => client.close(force: true));
    try {
      // One deadline for the whole exchange, the body included.
      return await _exchange(
        client,
        method,
        uri,
        headers: headers,
        body: body,
        cancel: cancel,
      ).timeout(_total);
    } on SpeechException {
      rethrow;
    } on TimeoutException {
      throw const SpeechException(SpeechFailure.offline, 'timeout');
    } on SocketException {
      throw const SpeechException(SpeechFailure.offline);
    } on HandshakeException {
      throw const SpeechException(SpeechFailure.offline, 'TLS');
    } on HttpException {
      throw const SpeechException(SpeechFailure.offline);
    } finally {
      forget();
      client.close(force: true);
    }
  }

  Future<Uint8List> _exchange(
    HttpClient client,
    String method,
    Uri uri, {
    required Map<String, String> headers,
    List<int>? body,
    required SpeechCancel cancel,
  }) async {
    final request = await client.openUrl(method, uri);
    // A key is for this host only: never follow a redirect with it.
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) request.add(body);
    final response = await request.close();
    if (cancel.cancelled) {
      throw const SpeechException(SpeechFailure.unavailable, 'cancelled');
    }
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      // The connection closes with the client; its body is not read.
      throw SpeechException(switch (status) {
        401 || 403 => SpeechFailure.unauthorized,
        429 => SpeechFailure.rateLimited,
        413 => SpeechFailure.tooLong,
        _ => SpeechFailure.rejected,
      }, 'HTTP $status');
    }
    final out = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (cancel.cancelled) {
        throw const SpeechException(SpeechFailure.unavailable, 'cancelled');
      }
      out.add(chunk);
      if (out.length > _maxAudio) {
        throw const SpeechException(SpeechFailure.tooLong, 'audio');
      }
    }
    final bytes = out.takeBytes();
    if (bytes.isEmpty) throw const SpeechException(SpeechFailure.noAudio);
    return bytes;
  }
}
