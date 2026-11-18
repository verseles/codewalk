import 'dart:convert';

/// Display metadata is optional. Reject an oversized label or unpaired UTF-16
/// surrogate without rejecting the message that carries it.
String? openCodeDisplayLabel(Object? value) {
  if (value is! String || value.isEmpty || value.length > 256) return null;
  // A paired surrogate is one supplementary rune. An unpaired one remains
  // in the surrogate range and would be replaced by the UTF-8 encoder.
  if (value.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff)) return null;
  if (utf8.encode(value).length > 256) return null;
  return value;
}
