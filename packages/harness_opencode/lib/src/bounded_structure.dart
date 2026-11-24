import 'package:codewalk_core/codewalk_core.dart';

import 'shell_observation.dart';

/// Shared finite bounds for structured tool inputs and outputs.
const openCodeStructuredFieldLimit = 65536;
const openCodeStructuredNodeLimit = 4096;
const openCodeStructuredDepthLimit = 16;
const openCodeToolContentPartLimit = 128;
const openCodeToolMimeLimit = 4096;

/// Discarded raw streaming argument ceilings (validated, never retained):
/// live SSE frames are bounded at 16 MiB and media-aware history reads at 32 MiB.
const openCodeLiveDiscardedInputLimit = 16 * 1024 * 1024;
const openCodeHistoryDiscardedInputLimit = 32 * 1024 * 1024;

/// Top-level tool input keys projected first so compact timeline subtitles stay
/// informative even when a huge sibling field (such as `content`) is truncated.
const openCodeToolInputPriorityKeys = <String>[
  'command',
  'path',
  'filePath',
  'pattern',
  'url',
  'query',
  'name',
  'header',
];

enum OpenCodeBoundedStructureFailure {
  malformed,
  depthExceeded,
  limitExceeded,
  unsupportedValue,
}

final class OpenCodeBoundedStructureException implements Exception {
  const OpenCodeBoundedStructureException(this.failure);

  final OpenCodeBoundedStructureFailure failure;

  @override
  String toString() => 'OpenCodeBoundedStructureException(${failure.name})';
}

const _credentialKeys = <String>{
  'password',
  'passwd',
  'secret',
  'apikey',
  'xapikey',
  'authorization',
  'token',
  'accesstoken',
  'refreshtoken',
  'apitoken',
  'privatekey',
  'secretaccesskey',
  'awssecretaccesskey',
  'clientsecret',
  'providerstate',
  'providerresultstate',
};

const _redactedToken = '[redacted]';
const _redactedJsonBytes = 12; // "[redacted]"

/// A credential key: a named one, or any whose normalized name ends with
/// `authorization` (`Proxy-Authorization`, `HTTP_AUTHORIZATION`).
bool openCodeIsCredentialKey(String key) {
  final name = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  return _credentialKeys.contains(name) || name.endsWith('authorization');
}

/// Validates that [value] contains no unpaired UTF-16 surrogates, throwing
/// [FormatException] on the first invalid code unit.
void validateOpenCodeUtf16(String value) {
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        throw const FormatException('Unpaired high UTF-16 surrogate.');
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        throw const FormatException('Invalid UTF-16 surrogate pair.');
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('Unpaired low UTF-16 surrogate.');
    }
  }
}

/// Validates a discarded raw streaming argument string without retaining it or
/// charging page budgets: throws [FormatException] for non-strings or lone
/// surrogates, and [RangeError] if UTF-8 bytes exceed [maxBytes].
void validateOpenCodeDiscardedText(Object? value, {required int maxBytes}) {
  if (value is! String) {
    throw const FormatException('Expected string argument.');
  }
  if (value.length > maxBytes) {
    throw RangeError('Discarded argument text exceeds limit.');
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        throw const FormatException('Unpaired high UTF-16 surrogate.');
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        throw const FormatException('Invalid UTF-16 surrogate pair.');
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('Unpaired low UTF-16 surrogate.');
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > maxBytes) {
      throw RangeError('Discarded argument text exceeds UTF-8 limit.');
    }
  }
}

/// Bounds a JSON tree to at most [maxBytes] JSON-escaped UTF-8 bytes and
/// [maxNodes] kept nodes, keeping a redacted prefix instead of throwing on
/// field size or width overflow.
///
/// Fails closed via [OpenCodeBoundedStructureException] on depth > [maxDepth],
/// non-finite numbers, unsupported value types, or unpaired UTF-16 surrogates
/// in any kept key or kept string prefix.
({CanonicalValue value, int bytes, int nodes, bool truncated, bool redacted})
boundOpenCodeStructure(
  Object? value, {
  required bool redact,
  List<String> priorityKeys = const [],
  int maxBytes = openCodeStructuredFieldLimit,
  int maxNodes = openCodeStructuredNodeLimit,
  int maxDepth = openCodeStructuredDepthLimit,
}) {
  var nodes = 0;
  var truncated = false;
  var redacted = false;

  ({bool fits, Object? value, int bytes, bool cut}) walk(
    Object? v,
    int depth,
    int budget,
  ) {
    if (depth > maxDepth) {
      throw const OpenCodeBoundedStructureException(
        OpenCodeBoundedStructureFailure.depthExceeded,
      );
    }
    if (nodes + 1 > maxNodes) {
      truncated = true;
      return (fits: false, value: null, bytes: 0, cut: true);
    }
    if (v == null) {
      if (budget < 4) {
        truncated = true;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      nodes++;
      return (fits: true, value: null, bytes: 4, cut: false);
    }
    if (v is bool) {
      final size = v ? 4 : 5;
      if (budget < size) {
        truncated = true;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      nodes++;
      return (fits: true, value: v, bytes: size, cut: false);
    }
    if (v is num) {
      if (!v.isFinite) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      final size = v.toString().length;
      if (budget < size) {
        truncated = true;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      nodes++;
      return (fits: true, value: v, bytes: size, cut: false);
    }
    if (v is String) {
      if (budget < 2) {
        truncated = true;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      final bounded = _boundJsonString(v, budget - 2, redact: redact);
      nodes++;
      if (bounded.redacted) redacted = true;
      if (bounded.cut) truncated = true;
      return (
        fits: true,
        value: bounded.text,
        bytes: bounded.innerBytes + 2,
        cut: bounded.cut,
      );
    }
    if (v is List) {
      if (budget < 2) {
        truncated = true;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      nodes++;
      var used = 2; // []
      var listCut = false;
      final out = <Object?>[];
      for (final child in v) {
        if (nodes >= maxNodes) {
          truncated = true;
          listCut = true;
          break;
        }
        final sep = out.isEmpty ? 0 : 1;
        final remaining = budget - used - sep;
        if (remaining <= 0) {
          truncated = true;
          listCut = true;
          break;
        }
        final item = walk(child, depth + 1, remaining);
        if (!item.fits) {
          truncated = true;
          listCut = true;
          break;
        }
        out.add(item.value);
        used += sep + item.bytes;
        if (item.cut) {
          listCut = true;
          break;
        }
      }
      if (depth > 0 && v.isNotEmpty && out.isEmpty) {
        nodes--;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      return (fits: true, value: out, bytes: used, cut: listCut);
    }
    if (v is Map<String, Object?>) {
      if (budget < 2) {
        truncated = true;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      nodes++;
      var used = 2; // {}
      var mapCut = false;
      final out = <String, Object?>{};
      final ordered = depth == 0 && priorityKeys.isNotEmpty
          ? _prioritizedEntries(v, priorityKeys)
          : v.entries;
      for (final entry in ordered) {
        if (nodes + 2 > maxNodes) {
          truncated = true;
          mapCut = true;
          break;
        }
        final key = entry.key;
        final sep = out.isEmpty ? 0 : 1;
        final keyBytes = _validatedJsonStringBytes(key);
        final overhead = sep + keyBytes + 1; // , + "key" + :
        if (redact && openCodeIsCredentialKey(key)) {
          if (depth + 1 > maxDepth) {
            throw const OpenCodeBoundedStructureException(
              OpenCodeBoundedStructureFailure.depthExceeded,
            );
          }
          if (used + overhead + _redactedJsonBytes > budget) {
            truncated = true;
            mapCut = true;
            break;
          }
          nodes += 2;
          redacted = true;
          out[key] = _redactedToken;
          used += overhead + _redactedJsonBytes;
          continue;
        }
        final remaining = budget - used - overhead;
        if (remaining <= 0) {
          truncated = true;
          mapCut = true;
          break;
        }
        // Account for the key node before descending into the value.
        nodes++;
        final child = walk(entry.value, depth + 1, remaining);
        if (!child.fits) {
          nodes--;
          truncated = true;
          mapCut = true;
          break;
        }
        out[key] = child.value;
        used += overhead + child.bytes;
        if (child.cut) {
          mapCut = true;
          break;
        }
      }
      if (depth > 0 && v.isNotEmpty && out.isEmpty) {
        nodes--;
        return (fits: false, value: null, bytes: 0, cut: true);
      }
      return (fits: true, value: out, bytes: used, cut: mapCut);
    }
    throw const OpenCodeBoundedStructureException(
      OpenCodeBoundedStructureFailure.unsupportedValue,
    );
  }

  final root = walk(value, 0, maxBytes);
  if (!root.fits) {
    throw const OpenCodeBoundedStructureException(
      OpenCodeBoundedStructureFailure.malformed,
    );
  }
  return (
    value: CanonicalValue(root.value),
    bytes: root.bytes,
    nodes: nodes,
    truncated: truncated,
    redacted: redacted,
  );
}

/// Bounds a tool `content` part list to at most [maxParts] parts, [maxBytes]
/// JSON-escaped UTF-8 bytes, and [maxNodes] nodes while sanitizing shell output
/// and redacting credentials before cutting.
({
  CanonicalValue value,
  int bytes,
  int nodes,
  bool truncated,
  bool omitted,
  bool redacted,
})
boundOpenCodeToolContent(
  Object? value, {
  bool shellTool = false,
  int maxBytes = openCodeStructuredFieldLimit,
  int maxNodes = openCodeStructuredNodeLimit,
  int maxParts = openCodeToolContentPartLimit,
}) {
  if (value is! List<Object?> || value.isEmpty) {
    throw const OpenCodeBoundedStructureException(
      OpenCodeBoundedStructureFailure.malformed,
    );
  }
  var used = 2; // []
  var nodes = 1;
  var truncated = false;
  var omitted = false;
  var redacted = false;
  final selected = <Object?>[];

  for (var i = 0; i < value.length; i++) {
    if (i >= maxParts) {
      truncated = true;
      break;
    }
    final raw = value[i];
    if (raw is! Map<String, Object?>) {
      throw const OpenCodeBoundedStructureException(
        OpenCodeBoundedStructureFailure.malformed,
      );
    }
    final type = raw['type'];
    if (type is! String || type.isEmpty) {
      throw const OpenCodeBoundedStructureException(
        OpenCodeBoundedStructureFailure.malformed,
      );
    }
    _validateBoundedUtf8String(type, openCodeToolMimeLimit);
    final sep = selected.isEmpty ? 0 : 1;
    if (type == 'text') {
      final rawText = raw['text'];
      if (rawText is! String) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      // {"type":"text","text":} is 23 bytes before the JSON string value.
      const wrapperBytes = 23;
      const partNodes = 5;
      final remaining = maxBytes - used - sep - wrapperBytes;
      if (remaining < 2 || nodes + partNodes > maxNodes) {
        truncated = true;
        break;
      }
      final bounded = _boundToolTextPart(
        rawText,
        remaining - 2,
        shellTool: shellTool,
      );
      selected.add({'type': 'text', 'text': bounded.text});
      used += sep + wrapperBytes + bounded.innerBytes + 2;
      nodes += partNodes;
      if (bounded.redacted) redacted = true;
      if (bounded.cut) {
        truncated = true;
        break;
      }
    } else if (type == 'file') {
      final mime = raw['mime'];
      if (mime is! String) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      _validateBoundedUtf8String(mime, openCodeToolMimeLimit);
      // {"type":"file","mime":,"available":false} is 41 bytes before mime JSON.
      const wrapperBytes = 41;
      const partNodes = 7;
      final mimeJsonBytes = _validatedJsonStringBytes(mime);
      final partBytes = sep + wrapperBytes + mimeJsonBytes;
      if (used + partBytes > maxBytes || nodes + partNodes > maxNodes) {
        truncated = true;
        break;
      }
      selected.add({'type': 'file', 'mime': mime, 'available': false});
      used += partBytes;
      nodes += partNodes;
      omitted = true;
    } else {
      throw const OpenCodeBoundedStructureException(
        OpenCodeBoundedStructureFailure.malformed,
      );
    }
  }

  return (
    value: CanonicalValue(selected),
    bytes: used,
    nodes: nodes,
    truncated: truncated,
    omitted: omitted,
    redacted: redacted,
  );
}

Iterable<MapEntry<String, Object?>> _prioritizedEntries(
  Map<String, Object?> map,
  List<String> priorityKeys,
) sync* {
  final seen = <String>{};
  for (final key in priorityKeys) {
    if (map.containsKey(key)) {
      seen.add(key);
      yield MapEntry(key, map[key]);
    }
  }
  for (final entry in map.entries) {
    if (!seen.contains(entry.key)) yield entry;
  }
}

void _validateBoundedUtf8String(String value, int maxUtf8Bytes) {
  if (value.length > maxUtf8Bytes) {
    throw const OpenCodeBoundedStructureException(
      OpenCodeBoundedStructureFailure.limitExceeded,
    );
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const OpenCodeBoundedStructureException(
        OpenCodeBoundedStructureFailure.malformed,
      );
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > maxUtf8Bytes) {
      throw const OpenCodeBoundedStructureException(
        OpenCodeBoundedStructureFailure.limitExceeded,
      );
    }
  }
}

int _validatedJsonStringBytes(String value) {
  var bytes = 2; // quotes
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const OpenCodeBoundedStructureException(
        OpenCodeBoundedStructureFailure.malformed,
      );
    } else {
      bytes += _jsonCodeUnitBytes(unit);
    }
  }
  return bytes;
}

int _jsonCodeUnitBytes(int unit) {
  if (unit == 0x22 ||
      unit == 0x5c ||
      unit == 8 ||
      unit == 9 ||
      unit == 10 ||
      unit == 12 ||
      unit == 13) {
    return 2;
  }
  if (unit < 0x20) return 6;
  return unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
}

/// Cuts [raw] to fit within [maxInnerBytes] JSON-escaped UTF-8 bytes on a
/// Unicode code-point boundary. Fails closed on unpaired UTF-16 surrogates in
/// the kept prefix when [strict] is true; when [strict] is false (used only for
/// the lookahead redaction margin), stops before an unpaired surrogate.
({String text, int innerBytes, bool cut}) _cutJsonEscaped(
  String raw,
  int maxInnerBytes, {
  required bool strict,
}) {
  var bytes = 0;
  for (var i = 0; i < raw.length; i++) {
    final unit = raw.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (i + 1 >= raw.length) {
        if (strict) {
          throw const OpenCodeBoundedStructureException(
            OpenCodeBoundedStructureFailure.malformed,
          );
        }
        return (text: raw.substring(0, i), innerBytes: bytes, cut: true);
      }
      final low = raw.codeUnitAt(i + 1);
      if (low < 0xdc00 || low > 0xdfff) {
        if (strict) {
          throw const OpenCodeBoundedStructureException(
            OpenCodeBoundedStructureFailure.malformed,
          );
        }
        return (text: raw.substring(0, i), innerBytes: bytes, cut: true);
      }
      if (bytes + 4 > maxInnerBytes) {
        return (text: raw.substring(0, i), innerBytes: bytes, cut: true);
      }
      bytes += 4;
      i++;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      if (strict) {
        throw const OpenCodeBoundedStructureException(
          OpenCodeBoundedStructureFailure.malformed,
        );
      }
      return (text: raw.substring(0, i), innerBytes: bytes, cut: true);
    } else {
      final size = _jsonCodeUnitBytes(unit);
      if (bytes + size > maxInnerBytes) {
        return (text: raw.substring(0, i), innerBytes: bytes, cut: true);
      }
      bytes += size;
    }
  }
  return (text: raw, innerBytes: bytes, cut: false);
}

({String text, int innerBytes, bool cut, bool redacted}) _boundJsonString(
  String raw,
  int maxInnerBytes, {
  required bool redact,
}) {
  final unredacted = _cutJsonEscaped(raw, maxInnerBytes, strict: true);
  if (!redact) {
    return (
      text: unredacted.text,
      innerBytes: unredacted.innerBytes,
      cut: unredacted.cut,
      redacted: false,
    );
  }
  final clean = redactCredentialSlice(raw, 0, unredacted.text.length);
  final kept = _cutJsonEscaped(clean, maxInnerBytes, strict: true);
  return (
    text: kept.text,
    innerBytes: kept.innerBytes,
    cut: unredacted.cut || kept.cut,
    redacted: kept.text != unredacted.text,
  );
}

({String text, int innerBytes, bool cut, bool redacted}) _boundToolTextPart(
  String raw,
  int maxInnerBytes, {
  required bool shellTool,
}) {
  // Validate the kept prefix up front so lone surrogates never slip through.
  final unredacted = _cutJsonEscaped(raw, maxInnerBytes, strict: true);
  final source = shellTool ? openCodeSanitizeShellToolOutputText(raw) : raw;
  final sanitizedPrefix = shellTool
      ? _cutJsonEscaped(source, maxInnerBytes, strict: false)
      : unredacted;
  final clean = redactCredentialSlice(source, 0, sanitizedPrefix.text.length);
  final kept = _cutJsonEscaped(clean, maxInnerBytes, strict: true);
  return (
    text: kept.text,
    innerBytes: kept.innerBytes,
    cut: sanitizedPrefix.cut || kept.cut,
    redacted: kept.text != unredacted.text,
  );
}
