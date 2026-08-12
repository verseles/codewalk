import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/i18n/arb_strings.dart' as defs;

const _locales = <String>[
  'ar',
  'bn',
  'de',
  'es',
  'fr',
  'hi',
  'it',
  'ja',
  'ko',
  'pt',
  'ru',
  'ur',
  'zh',
];

Map<String, String> _messages(String locale) {
  final decoded =
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return <String, String>{
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

Set<String> _placeholders(String value) => RegExp(
  r'\{\s*([A-Za-z_]\w*)\s*(?:,\s*(?:plural|select)\s*,|\})',
).allMatches(value).map((match) => match.group(1)!).toSet();

Set<String> _pluralPlaceholders(String value) => RegExp(
  r'\{([A-Za-z_]\w*),\s*plural,',
).allMatches(value).map((match) => match.group(1)!).toSet();

String _canonicalArbValue(String value) => value.replaceAll("''", "'");

void main() {
  test('existing arb_strings values match the current ARBs', () {
    final english = _messages('en');
    for (final entry in defs.englishTemplate.entries) {
      expect(
        _canonicalArbValue(english[entry.key]!),
        _canonicalArbValue(entry.value),
        reason: 'en:${entry.key}',
      );
    }
    for (final locale in _locales) {
      final localized = _messages(locale);
      for (final entry in defs.translations[locale]!.entries) {
        expect(
          _canonicalArbValue(localized[entry.key]!),
          _canonicalArbValue(entry.value),
          reason: '$locale:${entry.key}',
        );
      }
    }
  });

  test('arb_strings contains every current ARB entry', () {
    final english = _messages('en');
    expect(defs.englishTemplate.keys.toSet(), english.keys.toSet());
    for (final locale in _locales) {
      final localized = _messages(locale);
      expect(
        defs.translations[locale]?.keys.toSet(),
        localized.keys.toSet(),
        reason: locale,
      );
    }
  });

  test(
    'every locale covers the English catalog with matching placeholders',
    () {
      final english = _messages('en');
      for (final locale in _locales) {
        final localized = _messages(locale);
        expect(localized.keys.toSet(), english.keys.toSet(), reason: locale);
        for (final entry in english.entries) {
          expect(
            _placeholders(localized[entry.key]!),
            _placeholders(entry.value),
            reason: '$locale:${entry.key}',
          );
          expect(
            _pluralPlaceholders(localized[entry.key]!),
            _pluralPlaceholders(entry.value),
            reason: '$locale:${entry.key}:plural',
          );
        }
      }
    },
  );

  test('locale catalogs do not contain over-escaped ICU apostrophes', () {
    for (final locale in _locales) {
      for (final entry in _messages(locale).entries) {
        expect(
          entry.value,
          isNot(matches(RegExp("'{3,}"))),
          reason: '$locale:${entry.key}',
        );
      }
    }
  });
}
