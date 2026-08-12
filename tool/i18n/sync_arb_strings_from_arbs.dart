import 'dart:convert';
import 'dart:io';

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

Map<String, String> _readMessages(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) throw FormatException('Invalid ARB object: $path');
  return <String, String>{
    for (final entry in decoded.entries)
      if (entry.key is String &&
          !(entry.key as String).startsWith('@') &&
          entry.value is String)
        entry.key as String: entry.value as String,
  };
}

String _dartString(String value) {
  final normalized = value.replaceAll("''", "'");
  return "'${normalized.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n').replaceAll('\r', r'\r').replaceAll('\t', r'\t')}'";
}

String _entries(Map<String, String> values, {required String indent}) {
  final keys = values.keys.toList(growable: false)..sort();
  return keys
      .map(
        (key) =>
            "$indent'${key.replaceAll("'", r"\'")}': ${_dartString(values[key]!)},",
      )
      .join('\n');
}

void main() {
  final file = File('tool/i18n/arb_strings.dart');
  final englishArb = _readMessages('lib/l10n/app_en.arb');
  final buffer = StringBuffer()
    ..writeln(
      '/// ARB key definitions and per-locale translations for CodeWalk i18n.',
    )
    ..writeln('///')
    ..writeln('/// Generated from `lib/l10n/app_*.arb` by')
    ..writeln('/// `dart tool/i18n/sync_arb_strings_from_arbs.dart`.')
    ..writeln('library;')
    ..writeln()
    ..writeln('const englishTemplate = <String, String>{')
    ..writeln(_entries(englishArb, indent: '  '))
    ..writeln('};')
    ..writeln()
    ..writeln('const translations = <String, Map<String, String>>{');
  for (final locale in _locales) {
    final arb = _readMessages('lib/l10n/app_$locale.arb');
    buffer
      ..writeln("  '$locale': {")
      ..writeln(_entries(arb, indent: '    '))
      ..writeln('  },');
  }
  buffer.writeln('};');
  file.writeAsStringSync(buffer.toString());
  stdout.writeln(
    'Synchronized ${englishArb.length} keys across ${_locales.length} locales.',
  );
}
