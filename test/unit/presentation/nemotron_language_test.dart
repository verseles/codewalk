import 'package:codewalk/presentation/services/nemotron_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Portuguese locales and falls back to auto', () {
    expect(nemotronLanguageForLocale('pt-BR'), 'pt');
    expect(nemotronLanguageForLocale('en_US'), 'en');
    expect(nemotronLanguageForLocale('xx'), 'auto');
    expect(nemotronLanguageForLocale(null), 'auto');
  });
}
