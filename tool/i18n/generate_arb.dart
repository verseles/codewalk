import 'dart:convert';
import 'dart:io';
import 'arb_strings.dart' as defs;

const _arbDir = 'lib/l10n';

final _locales = const {
  'ar',
  'bn',
  'de',
  'en',
  'es',
  'fr',
  'hi',
  'it',
  'ja',
  'ko',
  'pt',
  'ru',
  'zh',
  'ur',
};

Map<String, String> _messages(String locale) {
  final decoded = jsonDecode(
    File('$_arbDir/app_$locale.arb').readAsStringSync(),
  );
  if (decoded is! Map) throw FormatException('Invalid app_$locale.arb');
  return <String, String>{
    for (final entry in decoded.entries)
      if (!entry.key.toString().startsWith('@') && entry.value is String)
        entry.key.toString(): (entry.value as String).replaceAll("''", "'"),
  };
}

void main() {
  final expectedByLocale = <String, Map<String, String>>{
    'en': defs.englishTemplate,
    ...defs.translations,
  };
  for (final locale in _locales) {
    final actual = _messages(locale);
    final expected = expectedByLocale[locale];
    if (expected == null || actual.length != expected.length) {
      throw StateError('Catalog key mismatch for $locale');
    }
    for (final entry in expected.entries) {
      if (actual[entry.key] != entry.value) {
        throw StateError('Catalog value mismatch for $locale:${entry.key}');
      }
    }
  }
  print(
    'ARB catalogs are synchronized. ARBs are canonical; use '
    '`dart tool/i18n/sync_arb_strings_from_arbs.dart` after editing them.',
  );
}
