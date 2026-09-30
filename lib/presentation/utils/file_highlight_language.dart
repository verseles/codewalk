import 'package:re_highlight/languages/all.dart';

final Map<String, String> _builtinLanguageByNameOrAlias = () {
  final languages = <String, String>{
    for (final name in builtinAllLanguages.keys) name: name,
  };
  for (final entry in builtinAllLanguages.entries) {
    for (final alias in entry.value.aliases ?? const <String>[]) {
      languages.putIfAbsent(alias.toLowerCase(), () => entry.key);
    }
  }
  return Map<String, String>.unmodifiable(languages);
}();

String? resolveBuiltinFileHighlightLanguage(String extension) {
  final normalized = extension.trim().toLowerCase();
  // The bundled JSON mode already highlights both JSONC comment forms.
  return _builtinLanguageByNameOrAlias[normalized == 'jsonc'
      ? 'json'
      : normalized];
}
