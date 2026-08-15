import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

const String kEdgeTtsTrustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
const String kEdgeTtsChromiumMajorVersion = '143';
const String kEdgeTtsChromiumFullVersion = '143.0.3650.75';
const String kEdgeTtsSecMsGecVersion = '1-143.0.3650.75';
const String kEdgeTtsWebSocketBaseUrl =
    'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
const String kEdgeTtsVoicesUrl =
    'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list';
const String kEdgeTtsAudioMimeType = 'audio/mpeg';
const String kEdgeTtsAudioOutputFormat = 'audio-24khz-48kbitrate-mono-mp3';
const int kEdgeTtsMaxInputBytes = 4096;

String edgeTtsSecMsGec(DateTime nowUtc) {
  final utc = nowUtc.toUtc();
  final secondsSinceUnixEpoch = utc.millisecondsSinceEpoch ~/ 1000;
  final windowsFileTime = (secondsSinceUnixEpoch + 11644473600) * 10000000;
  final rounded = windowsFileTime - (windowsFileTime % 3000000000);
  return sha256
      .convert(utf8.encode('$rounded$kEdgeTtsTrustedClientToken'))
      .toString()
      .toUpperCase();
}

String edgeTtsConnectionId([String? value]) {
  if (value != null && value.trim().isNotEmpty) {
    return value.replaceAll('-', '');
  }
  return edgeTtsRandomHex32();
}

String edgeTtsRandomHex32() {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i += 1) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String edgeTtsWebSocketKey() {
  final random = Random.secure();
  return base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
}

Uri edgeTtsWebSocketUri({
  required String connectionId,
  required DateTime nowUtc,
}) {
  return Uri.parse(kEdgeTtsWebSocketBaseUrl).replace(
    queryParameters: <String, String>{
      'TrustedClientToken': kEdgeTtsTrustedClientToken,
      'ConnectionId': connectionId.replaceAll('-', ''),
      'Sec-MS-GEC': edgeTtsSecMsGec(nowUtc),
      'Sec-MS-GEC-Version': kEdgeTtsSecMsGecVersion,
    },
  );
}

Uri edgeTtsVoicesUri({required DateTime nowUtc}) {
  return Uri.parse(kEdgeTtsVoicesUrl).replace(
    queryParameters: <String, String>{
      'trustedclienttoken': kEdgeTtsTrustedClientToken,
      'Sec-MS-GEC': edgeTtsSecMsGec(nowUtc),
      'Sec-MS-GEC-Version': kEdgeTtsSecMsGecVersion,
    },
  );
}

Map<String, String> edgeTtsBrowserHeaders({String? muid}) {
  return <String, String>{
    'Pragma': 'no-cache',
    'Cache-Control': 'no-cache',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
    'Sec-WebSocket-Version': '13',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/$kEdgeTtsChromiumMajorVersion.0.0.0 '
        'Safari/537.36 Edg/$kEdgeTtsChromiumMajorVersion.0.0.0',
    if (muid != null && muid.isNotEmpty) 'Cookie': 'muid=$muid;',
  };
}

Map<String, String> edgeTtsVoiceHeaders() {
  return <String, String>{
    'Authority': 'speech.platform.bing.com',
    'Sec-CH-UA':
        '" Not;A Brand";v="99", "Microsoft Edge";v="$kEdgeTtsChromiumMajorVersion", '
        '"Chromium";v="$kEdgeTtsChromiumMajorVersion"',
    'Sec-CH-UA-Mobile': '?0',
    'Accept': '*/*',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'en-US,en;q=0.9',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/$kEdgeTtsChromiumMajorVersion.0.0.0 '
        'Safari/537.36 Edg/$kEdgeTtsChromiumMajorVersion.0.0.0',
  };
}

String edgeTtsFrame({
  required Map<String, String> headers,
  required String payload,
}) {
  final buffer = StringBuffer();
  headers.forEach((key, value) {
    buffer.write(key);
    buffer.write(':');
    buffer.write(value);
    buffer.write('\r\n');
  });
  buffer.write('\r\n');
  buffer.write(payload);
  return buffer.toString();
}

String edgeTtsSpeechConfigFrame({DateTime? nowUtc}) {
  final config = jsonEncode(<String, Object>{
    'context': <String, Object>{
      'synthesis': <String, Object>{
        'audio': <String, Object>{
          'metadataoptions': <String, Object>{
            'sentenceBoundaryEnabled': 'false',
            'wordBoundaryEnabled': 'true',
          },
          'outputFormat': kEdgeTtsAudioOutputFormat,
        },
      },
    },
  });
  return edgeTtsFrame(
    headers: <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Path': 'speech.config',
      'X-Timestamp': edgeTtsTimestamp(nowUtc ?? DateTime.now().toUtc()),
    },
    payload: '$config\r\n',
  );
}

String edgeTtsSsmlFrame({
  required String requestId,
  required String ssml,
  DateTime? nowUtc,
}) {
  return edgeTtsFrame(
    headers: <String, String>{
      'Content-Type': 'application/ssml+xml',
      'Path': 'ssml',
      'X-RequestId': requestId.replaceAll('-', ''),
      'X-Timestamp': '${edgeTtsTimestamp(nowUtc ?? DateTime.now().toUtc())}Z',
    },
    payload: ssml,
  );
}

String edgeTtsTimestamp(DateTime utc) {
  final value = utc.toUtc();
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int number) => number.toString().padLeft(2, '0');
  return '${weekdays[value.weekday - 1]} ${months[value.month - 1]} '
      '${two(value.day)} ${value.year} ${two(value.hour)}:${two(value.minute)}:'
      '${two(value.second)} GMT+0000 (Coordinated Universal Time)';
}

String buildEdgeTtsSsml({
  required String text,
  required String voice,
  String locale = 'en-US',
  String rate = '+0%',
  String pitch = '+0Hz',
}) {
  return "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' "
      "xml:lang='${escapeEdgeTtsXml(locale)}'><voice name='${escapeEdgeTtsXml(voice)}'>"
      "<prosody pitch='${escapeEdgeTtsXml(pitch)}' rate='${escapeEdgeTtsXml(rate)}' "
      "volume='+0%'>${escapeEdgeTtsXml(stripEdgeTtsControlChars(text))}"
      '</prosody></voice></speak>';
}

String stripEdgeTtsControlChars(String value) {
  return value.replaceAll(
    RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
    '',
  );
}

String escapeEdgeTtsXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

int _edgeTtsUtf8ByteLength(int rune) {
  if (rune < 0x80) return 1;
  if (rune < 0x800) return 2;
  if (rune < 0x10000) return 3;
  return 4;
}

int _edgeTtsRuneEscapedByteLength(int rune) {
  switch (rune) {
    case 0x26: // &
      return 5; // &amp;
    case 0x3C: // <
      return 4; // &lt;
    case 0x3E: // >
      return 4; // &gt;
    case 0x22: // "
      return 6; // &quot;
    case 0x27: // '
      return 6; // &apos;
    default:
      return _edgeTtsUtf8ByteLength(rune);
  }
}

/// Byte length of [value] after XML escaping, matching what the server
/// receives inside the SSML payload.
int edgeTtsEscapedByteLength(String value) {
  var length = 0;
  for (final rune in value.runes) {
    length += _edgeTtsRuneEscapedByteLength(rune);
  }
  return length;
}

bool _edgeTtsIsAsciiWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      (codeUnit >= 0x09 && codeUnit <= 0x0D);
}

/// Splits [text] (after control character cleanup) into chunks whose
/// XML-escaped byte length never exceeds [maxBytes].
///
/// Splits prefer newlines, then spaces; when no natural boundary fits, the
/// chunk is cut on a UTF-8 safe boundary. Since escaping happens per chunk,
/// XML entities can never be split. When a single escaped rune is itself
/// larger than [maxBytes] (only possible with tiny limits), that rune is
/// emitted as its own over-limit chunk so the split always terminates.
/// Returns an empty list for empty input.
List<String> splitEdgeTtsTextChunks(
  String text, {
  int maxBytes = kEdgeTtsMaxInputBytes,
}) {
  if (maxBytes <= 0) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
  }
  final cleaned = stripEdgeTtsControlChars(text);
  if (cleaned.isEmpty) {
    return const <String>[];
  }
  if (edgeTtsEscapedByteLength(cleaned) <= maxBytes) {
    return <String>[cleaned];
  }
  final chunks = <String>[];
  final units = cleaned;
  var start = 0;
  while (start < units.length &&
      _edgeTtsIsAsciiWhitespace(units.codeUnitAt(start))) {
    start += 1;
  }
  if (start >= units.length) {
    return const <String>[];
  }
  var i = start;
  var segmentBytes = 0;
  var lastNewline = -1;
  var lastSpace = -1;
  var lastFitting = 0;
  while (i < units.length) {
    final unit = units.codeUnitAt(i);
    var rune = unit;
    var width = 1;
    if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < units.length) {
      final low = units.codeUnitAt(i + 1);
      if (low >= 0xDC00 && low <= 0xDFFF) {
        rune = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
        width = 2;
      }
    }
    final runeBytes = _edgeTtsRuneEscapedByteLength(rune);
    if (segmentBytes + runeBytes > maxBytes) {
      var cut = lastFitting;
      if (lastNewline > start) {
        cut = lastNewline;
      } else if (lastSpace > start) {
        cut = lastSpace;
      }
      if (cut > start) {
        final chunk = units.substring(start, cut).trim();
        if (chunk.isNotEmpty) {
          chunks.add(chunk);
        }
        var next = cut;
        while (next < units.length && _edgeTtsIsAsciiWhitespace(units.codeUnitAt(next))) {
          next += 1;
        }
        start = next;
      } else {
        final chunk = units.substring(start, start + width).trim();
        if (chunk.isNotEmpty) {
          chunks.add(chunk);
        }
        start += width;
      }
      segmentBytes = 0;
      lastNewline = -1;
      lastSpace = -1;
      lastFitting = -1;
      i = start;
      continue;
    }
    segmentBytes += runeBytes;
    lastFitting = i + width;
    if (rune == 0x0A) {
      lastNewline = i;
    } else if (rune == 0x20) {
      lastSpace = i;
    }
    i += width;
  }
  if (start < units.length) {
    final tail = units.substring(start).trim();
    if (tail.isNotEmpty) {
      chunks.add(tail);
    }
  }
  return chunks;
}

const List<String> _edgeTtsHttpMonths = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Parses an RFC 7231 HTTP date header such as
/// `Wed, 08 Jul 2026 16:00:00 GMT` into a UTC [DateTime].
///
/// Returns `null` for malformed input and for impossible calendar dates
/// (e.g. `31 Feb`) so callers never apply a wrong clock skew.
DateTime? parseEdgeTtsHttpDate(String value) {
  final match = RegExp(
    r'(\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  final month = _edgeTtsHttpMonths.indexOf(match.group(2)!);
  if (month < 0) {
    return null;
  }
  final day = int.parse(match.group(1)!);
  final year = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  if (day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    return null;
  }
  final parsed = DateTime.utc(year, month + 1, day, hour, minute, second);
  if (parsed.day != day || parsed.month != month + 1) {
    return null;
  }
  return parsed;
}

double edgeTtsRatePercentFromReadAloudRate(double rate) {
  return ((rate.clamp(0.0, 1.0) - 0.5) * 100).roundToDouble();
}

String edgeTtsRateAttribute(double rate) {
  final percent = edgeTtsRatePercentFromReadAloudRate(rate).round();
  return percent >= 0 ? '+$percent%' : '$percent%';
}

String edgeTtsPitchAttribute(double pitch) {
  final percent = ((pitch.clamp(0.5, 2.0) - 1.0) * 50).round();
  return percent >= 0 ? '+${percent}Hz' : '${percent}Hz';
}

class EdgeTtsTextFrame {
  const EdgeTtsTextFrame({required this.headers, required this.body});

  final Map<String, String> headers;
  final String body;

  String? get path => headers['Path'];
}

EdgeTtsTextFrame parseEdgeTtsTextFrame(String frame) {
  final separatorIndex = frame.indexOf('\r\n\r\n');
  final headerText = separatorIndex >= 0
      ? frame.substring(0, separatorIndex)
      : frame;
  final body = separatorIndex >= 0 ? frame.substring(separatorIndex + 4) : '';
  final headers = <String, String>{};
  for (final line in headerText.split('\r\n')) {
    if (line.isEmpty) continue;
    final index = line.indexOf(':');
    if (index <= 0) continue;
    headers[line.substring(0, index)] = line.substring(index + 1);
  }
  return EdgeTtsTextFrame(headers: headers, body: body);
}

class EdgeTtsBinaryFrame {
  const EdgeTtsBinaryFrame({required this.headers, required this.audioBytes});

  final Map<String, String> headers;
  final Uint8List audioBytes;

  String? get path => headers['Path'];
  String? get contentType => headers['Content-Type'];
}

EdgeTtsBinaryFrame parseEdgeTtsBinaryFrame(List<int> data) {
  if (data.length < 2) {
    throw const FormatException('Edge TTS binary frame is too short.');
  }
  final headerLength = (data[0] << 8) + data[1];
  final payloadOffset = headerLength + 2;
  if (data.length < payloadOffset) {
    throw const FormatException('Edge TTS binary frame header is truncated.');
  }
  final headerText = utf8.decode(data.sublist(2, payloadOffset));
  final headers = parseEdgeTtsTextFrame('$headerText\r\n\r\n').headers;
  return EdgeTtsBinaryFrame(
    headers: headers,
    audioBytes: Uint8List.fromList(data.sublist(payloadOffset)),
  );
}

@visibleForTesting
Uint8List buildEdgeTtsBinaryFrameForTest({
  required Map<String, String> headers,
  required List<int> audioBytes,
}) {
  final headerBytes = utf8.encode(
    headers.entries.map((entry) => '${entry.key}:${entry.value}').join('\r\n'),
  );
  final result = Uint8List(2 + headerBytes.length + audioBytes.length);
  result[0] = (headerBytes.length >> 8) & 0xff;
  result[1] = headerBytes.length & 0xff;
  result.setRange(2, 2 + headerBytes.length, headerBytes);
  result.setRange(2 + headerBytes.length, result.length, audioBytes);
  return result;
}
