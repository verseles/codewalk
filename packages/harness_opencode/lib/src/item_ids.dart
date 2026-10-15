import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

const _idLimit = 64 * 1024;

/// The native `msg_` id an item of [ref] was projected from: every projection
/// encodes item ids as `[storageKey, nativeId, kind, discriminator]`. Null for
/// any other shape, another session or a non-message id.
String? openCodeMessageIdOf(ItemId id, SessionRef ref) {
  if (id.value.length > _idLimit) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(id.value);
  } on FormatException {
    return null;
  }
  if (decoded is! List<Object?> ||
      decoded.length != 4 ||
      decoded[0] != ref.storageKey ||
      decoded[2] is! String) {
    return null;
  }
  final message = decoded[1];
  return message is String && message.startsWith('msg_') ? message : null;
}
