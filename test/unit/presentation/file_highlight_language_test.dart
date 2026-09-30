import 'package:codewalk/presentation/utils/file_highlight_language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

void main() {
  test('resolves canonical language names and package aliases', () {
    expect(resolveBuiltinFileHighlightLanguage('lua'), 'lua');
    expect(resolveBuiltinFileHighlightLanguage('cs'), 'csharp');
    expect(resolveBuiltinFileHighlightLanguage('ps1'), 'powershell');
    expect(resolveBuiltinFileHighlightLanguage('tex'), 'latex');
    expect(resolveBuiltinFileHighlightLanguage('exs'), 'elixir');
    expect(resolveBuiltinFileHighlightLanguage('fs'), 'fsharp');
  });

  test('normalizes extension case and rejects unknown languages', () {
    expect(resolveBuiltinFileHighlightLanguage('RS'), 'rust');
    expect(resolveBuiltinFileHighlightLanguage('not-a-language'), isNull);
  });

  test('JSONC uses JSON highlighting without changing JSON or unknown files', () {
    expect(resolveBuiltinFileHighlightLanguage('jsonc'), 'json');
    expect(resolveBuiltinFileHighlightLanguage(' JSONC '), 'json');
    expect(resolveBuiltinFileHighlightLanguage('json'), 'json');
    expect(resolveBuiltinFileHighlightLanguage('json5'), isNull);
    final highlighter = Highlight()
      ..registerLanguage('json', builtinAllLanguages['json']!);
    final result = highlighter.highlight(
      code:
          '{\n // note\n "url": "https://example.com",\n /* block */ "count": 42, "enabled": true\n}',
      language: 'json',
    );
    expect(result.illegal, isFalse);
    final html = result.toHtml();
    expect('hljs-comment'.allMatches(html).length, 2);
    expect(html, contains('hljs-attr'));
    expect(html, contains('hljs-string'));
    expect(html, contains('hljs-number'));
    expect(html, contains('hljs-literal'));
  });
}
