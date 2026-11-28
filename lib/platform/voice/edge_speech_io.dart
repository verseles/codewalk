import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../shared/voice/read_aloud.dart';
import 'edge_token.dart';

/// Microsoft Edge's read-aloud voices (#541), through the unofficial
/// protocol of the Edge extension, as edge-tts 7.3.1 speaks it: a websocket
/// per chunk, a speech.config and an SSML message, MP3 frames back. A 403
/// with a `Date` corrects the clock once; a voice with no audio falls back
/// once to the language's default voice. Nothing falls back to another
/// provider.
final class EdgeSpeech implements SpeechSynthesizer {
  EdgeSpeech({HttpClient Function()? client})
    : _client = client ?? HttpClient.new;

  final HttpClient Function() _client;

  static const _host = 'speech.platform.bing.com';
  static const _path = '/consumer/speech/synthesize/readaloud';
  static const _chromium = '143.0.3650.75';
  static const _major = '143';
  static const _secVersion = '2-$_chromium';
  static const _connect = Duration(seconds: 10);
  static const _read = Duration(seconds: 60);

  /// The longest SSML text of one request, in UTF-8 bytes.
  static const maxChunkBytes = 4096;

  /// The longest message read, in UTF-8 bytes; longer is refused.
  static const maxTextBytes = 64 * 1024;

  /// The service's clock minus this device's, learnt from a 403.
  static int _skewSeconds = 0;

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/$_major.0.0.0 Safari/537.36 '
      'Edg/$_major.0.0.0';

  /// The default voice of each app language.
  static const defaultVoices = {
    'en': 'en-US-EmmaMultilingualNeural',
    'pt': 'pt-BR-FranciscaNeural',
    'es': 'es-ES-ElviraNeural',
    'fr': 'fr-FR-DeniseNeural',
    'de': 'de-DE-KatjaNeural',
    'it': 'it-IT-ElsaNeural',
    'ru': 'ru-RU-SvetlanaNeural',
    'ja': 'ja-JP-NanamiNeural',
    'ko': 'ko-KR-SunHiNeural',
    'zh': 'zh-CN-XiaoxiaoNeural',
    'hi': 'hi-IN-SwaraNeural',
    'bn': 'bn-IN-TanishaaNeural',
    'ar': 'ar-SA-ZariyahNeural',
    'ur': 'ur-PK-UzmaNeural',
  };

  static String defaultVoice(String locale) =>
      defaultVoices[locale.split(RegExp('[-_]')).first.toLowerCase()] ??
      defaultVoices['en']!;

  int get _now =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + _skewSeconds;

  Map<String, String> get _baseHeaders => {
    'User-Agent': _userAgent,
    'Accept-Language': 'en-US,en;q=0.9',
    'Cookie': 'muid=${_muid()};',
  };

  @override
  Future<SpeechAudio> synthesize(
    SpeechRequest request,
    SpeechCancel cancel,
  ) async {
    final text = request.text;
    if (utf8.encode(text).length > maxTextBytes) {
      throw const SpeechException(SpeechFailure.tooLong);
    }
    final settings = request.settings;
    final fallback = defaultVoice(request.locale);
    var voice = settings.voice ?? fallback;
    final out = BytesBuilder(copy: false);
    for (final chunk in edgeChunks(edgeEscape(text))) {
      if (cancel.cancelled) {
        throw const SpeechException(SpeechFailure.unavailable, 'cancelled');
      }
      Uint8List audio;
      try {
        audio = await _speakChunk(chunk, voice, settings.rate, cancel);
      } on SpeechException catch (error) {
        // A voice Microsoft dropped answers with no audio: the language's
        // default voice reads instead, for the rest of the message too.
        if (error.failure != SpeechFailure.noAudio || voice == fallback) {
          rethrow;
        }
        voice = fallback;
        if (cancel.cancelled) {
          throw const SpeechException(SpeechFailure.unavailable, 'cancelled');
        }
        audio = await _speakChunk(chunk, fallback, settings.rate, cancel);
      }
      out.add(audio);
    }
    final bytes = out.takeBytes();
    if (bytes.isEmpty) throw const SpeechException(SpeechFailure.noAudio);
    return SpeechAudio(bytes, 'audio/mpeg');
  }

  Future<Uint8List> _speakChunk(
    String chunk,
    String voice,
    double rate,
    SpeechCancel cancel,
  ) async {
    if (cancel.cancelled) {
      throw const SpeechException(SpeechFailure.unavailable, 'cancelled');
    }
    final socket = await _open(retry: true, cancel: cancel);
    // A stop drops the connection at once.
    final forget = cancel.onCancel(() => unawaited(socket.close()));
    try {
      final date = edgeDate(DateTime.now().toUtc());
      socket
        ..add(
          'X-Timestamp:$date\r\n'
          'Content-Type:application/json; charset=utf-8\r\n'
          'Path:speech.config\r\n\r\n'
          '{"context":{"synthesis":{"audio":{"metadataoptions":'
          '{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},'
          '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n',
        )
        ..add(
          'X-RequestId:${_hexId()}\r\n'
          'Content-Type:application/ssml+xml\r\n'
          'X-Timestamp:${date}Z\r\n'
          'Path:ssml\r\n\r\n'
          '${edgeSsml(chunk, voice: voice, rate: rate)}',
        );
      final audio = BytesBuilder(copy: false);
      var ended = false;
      await for (final message in socket.timeout(_read)) {
        if (cancel.cancelled) {
          throw const SpeechException(SpeechFailure.unavailable, 'cancelled');
        }
        if (message is String) {
          final path = edgeHeader(message, 'Path');
          if (path == 'turn.end') {
            ended = true;
            break;
          }
        } else if (message is List<int>) {
          final frame = edgeAudioFrame(Uint8List.fromList(message));
          if (frame != null) audio.add(frame);
        }
      }
      if (cancel.cancelled) {
        throw const SpeechException(SpeechFailure.unavailable, 'cancelled');
      }
      // A connection closed before the service said it was done would read
      // only part of the message.
      if (!ended) throw const SpeechException(SpeechFailure.offline, 'cut');
      final bytes = audio.takeBytes();
      if (bytes.isEmpty) throw const SpeechException(SpeechFailure.noAudio);
      return bytes;
    } on TimeoutException {
      throw const SpeechException(SpeechFailure.offline, 'timeout');
    } on WebSocketException {
      throw const SpeechException(SpeechFailure.offline, 'websocket');
    } on IOException {
      // The connection dropped midway.
      throw const SpeechException(SpeechFailure.offline);
    } finally {
      forget();
      unawaited(socket.close());
    }
  }

  /// Opens the websocket by hand, to read a refusal's status and `Date`.
  Future<WebSocket> _open({
    required bool retry,
    required SpeechCancel cancel,
  }) async {
    final uri = Uri.https(_host, '$_path/edge/v1', {
      'TrustedClientToken': edgeTrustedClientToken,
      'ConnectionId': _hexId(),
      'Sec-MS-GEC': edgeSecMsGec(_now),
      'Sec-MS-GEC-Version': _secVersion,
    });
    final client = _client()..connectionTimeout = _connect;
    // A stop during the handshake drops it at once.
    final forget = cancel.onCancel(() => client.close(force: true));
    try {
      final request = await client.getUrl(uri).timeout(_connect);
      request.followRedirects = false;
      final key = base64.encode(
        List<int>.generate(16, (_) => Random.secure().nextInt(256)),
      );
      final headers = {
        ..._baseHeaders,
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
        'Connection': 'Upgrade',
        'Upgrade': 'websocket',
        'Sec-WebSocket-Version': '13',
        'Sec-WebSocket-Key': key,
      };
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(_connect);
      if (response.statusCode == HttpStatus.switchingProtocols) {
        // The websocket owns the detached socket from here on.
        // ignore: close_sinks
        final socket = await response.detachSocket();
        client.close();
        return WebSocket.fromUpgradedSocket(socket, serverSide: false);
      }
      final date = response.headers.value(HttpHeaders.dateHeader);
      // The refusal's body is not read: closing ends it.
      client.close(force: true);
      if (response.statusCode == HttpStatus.forbidden && retry) {
        final server = date == null ? null : _parseDate(date);
        if (server != null) {
          _skewSeconds += server - _now;
          forget();
          return await _open(retry: false, cancel: cancel);
        }
      }
      // Edge takes no key: a refusal is the service's, not the user's.
      throw SpeechException(
        SpeechFailure.rejected,
        'HTTP ${response.statusCode}',
      );
    } on SpeechException {
      rethrow;
    } on TimeoutException {
      client.close(force: true);
      throw const SpeechException(SpeechFailure.offline, 'timeout');
    } on SocketException {
      client.close(force: true);
      throw const SpeechException(SpeechFailure.offline);
    } on HandshakeException {
      client.close(force: true);
      throw const SpeechException(SpeechFailure.offline, 'TLS');
    } on HttpException {
      client.close(force: true);
      throw const SpeechException(SpeechFailure.offline);
    } finally {
      forget();
    }
  }

  @override
  Future<List<SpeechVoice>> voices(SpeechRequest request) async {
    final uri = Uri.https(_host, '$_path/voices/list', {
      'trustedclienttoken': edgeTrustedClientToken,
      'Sec-MS-GEC': edgeSecMsGec(_now),
      'Sec-MS-GEC-Version': _secVersion,
    });
    final client = _client()..connectionTimeout = _connect;
    try {
      final http = await client.getUrl(uri).timeout(_connect);
      ({
        ..._baseHeaders,
        'Accept': '*/*',
        'Sec-CH-UA':
            '" Not;A Brand";v="99", "Microsoft Edge";v="$_major", '
            '"Chromium";v="$_major"',
        'Sec-CH-UA-Mobile': '?0',
      }).forEach(http.headers.set);
      final response = await http.close().timeout(_read);
      if (response.statusCode != HttpStatus.ok) {
        throw SpeechException(
          SpeechFailure.rejected,
          'HTTP ${response.statusCode}',
        );
      }
      // One deadline and a size bound for the whole list.
      final body = await () async {
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          bytes.add(chunk);
          if (bytes.length > 8 << 20) {
            throw const SpeechException(SpeechFailure.rejected, 'voices');
          }
        }
        return utf8.decode(bytes.takeBytes(), allowMalformed: true);
      }().timeout(_read);
      return edgeVoices(body);
    } on SpeechException {
      rethrow;
    } on Object {
      throw const SpeechException(SpeechFailure.offline);
    } finally {
      client.close(force: true);
    }
  }

  static String _hexId() => [
    for (var i = 0; i < 16; i++)
      Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  static String _muid() => _hexId().toUpperCase();

  static int? _parseDate(String value) {
    try {
      return HttpDate.parse(value).millisecondsSinceEpoch ~/ 1000;
    } on HttpException {
      return null;
    }
  }
}

/// The voices of the list's JSON, sorted by language then name.
@visibleForTesting
List<SpeechVoice> edgeVoices(String json) {
  final decoded = jsonDecode(json);
  final voices =
      [
        if (decoded is List)
          for (final voice in decoded)
            if (voice is Map &&
                voice['ShortName'] is String &&
                voice['Locale'] is String)
              SpeechVoice(
                id: voice['ShortName'] as String,
                label: _voiceLabel(voice),
                locale: voice['Locale'] as String,
              ),
      ]..sort((a, b) {
        final byLocale = a.locale!.compareTo(b.locale!);
        return byLocale != 0 ? byLocale : a.label.compareTo(b.label);
      });
  return voices;
}

String _voiceLabel(Map<Object?, Object?> voice) {
  final short = voice['ShortName'] as String;
  final name = short.split('-').skip(2).join('-').replaceAll('Neural', '');
  final gender = voice['Gender'];
  return gender is String ? '$name ($gender)' : name;
}

/// The service's date format, in UTC.
@visibleForTesting
String edgeDate(DateTime utc) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String two(int value) => value.toString().padLeft(2, '0');
  return '${days[utc.weekday - 1]} ${months[utc.month - 1]} ${two(utc.day)} '
      '${utc.year} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} '
      'GMT+0000 (Coordinated Universal Time)';
}

/// Control characters as spaces, then `&`, `<` and `>` escaped.
@visibleForTesting
String edgeEscape(String text) => text
    .replaceAll(RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), ' ')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// [escaped] in pieces of at most [EdgeSpeech.maxChunkBytes] UTF-8 bytes:
/// cut at the last line break, else the last space, else between whole
/// characters, never inside an entity.
@visibleForTesting
List<String> edgeChunks(String escaped) {
  final chunks = <String>[];
  var rest = escaped;
  while (utf8.encode(rest).length > EdgeSpeech.maxChunkBytes) {
    // The longest prefix of whole characters within the limit.
    var end = 0;
    var bytes = 0;
    for (final rune in rest.runes) {
      final size = utf8.encode(String.fromCharCode(rune)).length;
      if (bytes + size > EdgeSpeech.maxChunkBytes) break;
      bytes += size;
      end += rune > 0xFFFF ? 2 : 1;
    }
    final head = rest.substring(0, end);
    var cut = head.lastIndexOf('\n');
    if (cut <= 0) cut = head.lastIndexOf(' ');
    if (cut <= 0) cut = end;
    // Never between `&` and its `;`.
    final amp = head.lastIndexOf('&', cut - 1);
    if (amp >= 0 && !head.substring(amp, cut).contains(';')) cut = amp;
    if (cut <= 0) cut = end;
    final piece = rest.substring(0, cut).trim();
    if (piece.isNotEmpty) chunks.add(piece);
    rest = rest.substring(cut);
  }
  final last = rest.trim();
  if (last.isNotEmpty) chunks.add(last);
  return chunks;
}

/// The SSML of one chunk; [rate] 0–1, normal at 0.5 (half to double speed).
@visibleForTesting
String edgeSsml(String escaped, {required String voice, required double rate}) {
  final percent = ((0.5 * pow(4, rate) - 1) * 100).round();
  final sign = percent < 0 ? '' : '+';
  return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' "
      "xml:lang='en-US'><voice name='${edgeVoiceName(voice)}'>"
      "<prosody pitch='+0Hz' rate='$sign$percent%' volume='+0%'>"
      '$escaped</prosody></voice></speak>';
}

/// The service's long voice name for a short one (`en-US-AriaNeural`).
@visibleForTesting
String edgeVoiceName(String voice) {
  final match = RegExp(
    r'^([a-z]{2,})-([A-Z]{2,})-(.+Neural)$',
  ).firstMatch(voice);
  if (match == null) return voice;
  var region = match.group(2)!;
  var name = match.group(3)!;
  final dash = name.indexOf('-');
  if (dash >= 0) {
    region = '$region-${name.substring(0, dash)}';
    name = name.substring(dash + 1);
  }
  return 'Microsoft Server Speech Text to Speech Voice '
      '(${match.group(1)}-$region, $name)';
}

/// A header of a text frame (`Path:turn.end`).
@visibleForTesting
String? edgeHeader(String frame, String name) {
  final end = frame.indexOf('\r\n\r\n');
  final head = end < 0 ? frame : frame.substring(0, end);
  for (final line in head.split('\r\n')) {
    final colon = line.indexOf(':');
    if (colon > 0 && line.substring(0, colon) == name) {
      return line.substring(colon + 1).trim();
    }
  }
  return null;
}

/// The audio of a binary frame: a big-endian header length, the headers
/// (`Path:audio`), then MP3 bytes; null for any other frame.
@visibleForTesting
Uint8List? edgeAudioFrame(Uint8List frame) {
  if (frame.length < 2) return null;
  final length = (frame[0] << 8) | frame[1];
  if (frame.length < 2 + length) return null;
  final headers = latin1.decode(
    frame.sublist(2, 2 + length),
    allowInvalid: true,
  );
  if (edgeHeader('$headers\r\n\r\n', 'Path') != 'audio') return null;
  final audio = frame.sublist(2 + length);
  return audio.isEmpty ? null : audio;
}
