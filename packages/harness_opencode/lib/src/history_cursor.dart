import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'session_reader.dart';

const _maxEncodedCursorLength = 32 * 1024;
const _maxNativeCursorBytes = 16 * 1024;

/// Validates an opaque native OpenCode continuation cursor.
String? parseOpenCodeNativeCursor(Object? value) {
  if (value == null) return null;
  if (value is! String ||
      value.isEmpty ||
      utf8.encode(value).length > _maxNativeCursorBytes) {
    throw const FormatException('Malformed OpenCode cursor.');
  }
  return value;
}

/// Encodes an opaque session-list continuation token bound to [scope] and
/// optional [directory].
String encodeOpenCodeListCursor(
  String native, {
  required String scope,
  String? directory,
}) => base64Url.encode(
  utf8.encode(
    jsonEncode({
      'version': 1,
      'scope': scope,
      'directory': ?directory,
      'native': native,
    }),
  ),
);

/// Decodes and validates a session-list continuation token for [scope] and
/// optional [directory].
String decodeOpenCodeListCursor(
  String value, {
  required String scope,
  String? directory,
}) {
  try {
    if (value.length > _maxEncodedCursorLength) throw const FormatException();
    final data = jsonDecode(utf8.decode(base64Url.decode(value)));
    if (data is! Map<String, Object?> ||
        data['version'] != 1 ||
        data['scope'] != scope ||
        data['directory'] != directory) {
      throw const FormatException();
    }
    return parseOpenCodeNativeCursor(data['native']) ??
        (throw const FormatException());
  } on FormatException {
    throw const OpenCodeSessionReadException(
      OpenCodeSessionReadFailure.invalidCursor,
    );
  }
}

/// Encodes an opaque history continuation token bound to [scope], [ref],
/// caller [limit], [sourceVersion], and [order].
String encodeOpenCodeHistoryCursor(
  String native, {
  required String scope,
  required SessionRef ref,
  required int limit,
  required String sourceVersion,
  required String order,
}) {
  if (utf8.decode(utf8.encode(native)) != native) {
    throw const FormatException('Malformed history continuation.');
  }
  final encoded = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'version': 2,
        'kind': 'history',
        'scope': scope,
        'ref': ref.storageKey,
        'order': order,
        'limit': limit,
        'sourceVersion': sourceVersion,
        'native': native,
      }),
    ),
  );
  if (encoded.length > _maxEncodedCursorLength) {
    throw const FormatException('History continuation exceeds its limit.');
  }
  return encoded;
}

/// Decodes and validates a history continuation token for [scope], [ref],
/// caller [limit], and [sourceVersion].
({String native, String order}) decodeOpenCodeHistoryCursor(
  String value, {
  required String scope,
  required SessionRef ref,
  required int limit,
  required String sourceVersion,
}) {
  try {
    if (value.length > _maxEncodedCursorLength) throw const FormatException();
    final data = jsonDecode(utf8.decode(base64Url.decode(value)));
    if (data is! Map<String, Object?> ||
        data['version'] != 2 ||
        data['kind'] != 'history' ||
        data['scope'] != scope ||
        data['ref'] != ref.storageKey ||
        (data['order'] != 'asc' && data['order'] != 'desc') ||
        data['limit'] != limit ||
        data['sourceVersion'] != sourceVersion) {
      throw const FormatException();
    }
    return (
      native:
          parseOpenCodeNativeCursor(data['native']) ??
          (throw const FormatException()),
      order: data['order']! as String,
    );
  } on FormatException {
    throw const OpenCodeSessionReadException(
      OpenCodeSessionReadFailure.invalidCursor,
    );
  }
}
