import 'package:flutter_test/flutter_test.dart';
import 'package:codewalk/presentation/utils/diff_parser.dart';

void main() {
  group('parseDiffLines', () {
    test('distingue linhas + vs +++ (metadata)', () {
      const diff = '+added\n+++file.dart\n+another';
      final lines = parseDiffLines(diff);
      expect(lines[0].type, DiffLineType.add);
      expect(lines[1].type, DiffLineType.metadata);
      expect(lines[2].type, DiffLineType.add);
    });

    test('distingue linhas - vs --- (metadata)', () {
      const diff = '-removed\n---file.dart\n-another';
      final lines = parseDiffLines(diff);
      expect(lines[0].type, DiffLineType.remove);
      expect(lines[1].type, DiffLineType.metadata);
      expect(lines[2].type, DiffLineType.remove);
    });

    test('detecta hunk headers @@', () {
      const diff = '@@ -1,3 +1,4 @@\ncontext\n+added';
      final lines = parseDiffLines(diff);
      expect(lines[0].type, DiffLineType.hunk);
      expect(lines[1].type, DiffLineType.context);
      expect(lines[2].type, DiffLineType.add);
    });

    test('detecta metadata completa', () {
      const diff = '''diff --git a/file.dart b/file.dart
index abc123..def456 100644
--- a/file.dart
+++ b/file.dart''';
      final lines = parseDiffLines(diff);
      expect(lines[0].type, DiffLineType.metadata); // diff --git
      expect(lines[1].type, DiffLineType.metadata); // index
      expect(lines[2].type, DiffLineType.metadata); // ---
      expect(lines[3].type, DiffLineType.metadata); // +++
    });

    test('linhas de contexto sem marcadores', () {
      const diff = 'normal line\nanother line\n+added';
      final lines = parseDiffLines(diff);
      expect(lines[0].type, DiffLineType.context);
      expect(lines[1].type, DiffLineType.context);
      expect(lines[2].type, DiffLineType.add);
    });
  });

  group('isDiffFormat', () {
    test('detecta unified diff com 2+ marcadores', () {
      const diff = 'diff --git a/f b/f\n--- a/f\n+++ b/f';
      expect(isDiffFormat(diff), isTrue);
    });

    test('detecta diff com @@ marker', () {
      const diff = 'some text\n@@ -1,2 +1,3 @@\n--- a/file';
      expect(isDiffFormat(diff), isTrue);
    });

    test('rejeita texto normal', () {
      const text = 'Normal output\nwith lines\nno diff';
      expect(isDiffFormat(text), isFalse);
    });

    test('rejeita texto com apenas 1 marcador', () {
      const text = 'Output\n--- something\nbut not real diff';
      expect(isDiffFormat(text), isFalse);
    });

    test('verifica apenas primeiras 20 linhas', () {
      final lines = List.generate(25, (i) => 'line $i');
      lines[22] = 'diff --git a/f b/f';
      lines[23] = '--- a/f';
      final text = lines.join('\n');

      // Marcadores após linha 20 não devem ser detectados
      expect(isDiffFormat(text), isFalse);
    });
  });
}
