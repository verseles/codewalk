String nemotronLanguageForLocale(String? localeId) {
  final code = localeId?.split(RegExp(r'[-_]')).first.trim().toLowerCase();
  const known = <String>{
    'en',
    'pt',
    'es',
    'fr',
    'de',
    'it',
    'nl',
    'pl',
    'ru',
    'uk',
    'ja',
    'zh',
    'ko',
    'hi',
    'ar',
    'tr',
    'vi',
    'th',
    'id',
    'cs',
    'sv',
    'da',
    'fi',
    'no',
    'el',
    'he',
    'ro',
    'hu',
  };
  if (code != null && known.contains(code)) {
    return code;
  }
  return 'auto';
}
