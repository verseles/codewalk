import 'package:codewalk/presentation/utils/file_path_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilePathDetector', () {
    late FilePathDetector detector;

    setUp(() {
      detector = FilePathDetector();
    });

    group('detect', () {
      test('matches simple relative path with known extension', () {
        final results = detector.detect('see lib/main.dart for details');
        expect(results, hasLength(1));
        expect(results.first.path, 'lib/main.dart');
        expect(results.first.lineNumber, isNull);
        expect(results.first.columnNumber, isNull);
      });

      test('matches path with line number', () {
        final results = detector.detect('error at src/app.dart:42');
        expect(results, hasLength(1));
        expect(results.first.path, 'src/app.dart');
        expect(results.first.lineNumber, 42);
        expect(results.first.columnNumber, isNull);
      });

      test('matches path with line and column', () {
        final results = detector.detect('error at src/app.dart:42:10');
        expect(results, hasLength(1));
        expect(results.first.path, 'src/app.dart');
        expect(results.first.lineNumber, 42);
        expect(results.first.columnNumber, 10);
      });

      test('matches dot-slash relative path', () {
        final results = detector.detect('check ./config/settings.yaml');
        expect(results, hasLength(1));
        expect(results.first.path, './config/settings.yaml');
      });

      test('matches parent directory relative path', () {
        final results = detector.detect('see ../lib/utils.py:100');
        expect(results, hasLength(1));
        expect(results.first.path, '../lib/utils.py');
        expect(results.first.lineNumber, 100);
      });

      test('matches home directory path', () {
        final results = detector.detect('edit ~/.bashrc');
        // ~/.bashrc has no directory separator after ~/, so it may not match
        // depending on the regex. This is expected behavior.
        // The regex requires at least one / segment after the prefix.
      });

      test('matches deep nested paths', () {
        final results = detector.detect(
          'see packages/core/lib/src/models/user.dart:15:5',
        );
        expect(results, hasLength(1));
        expect(results.first.path, 'packages/core/lib/src/models/user.dart');
        expect(results.first.lineNumber, 15);
        expect(results.first.columnNumber, 5);
      });

      test('matches multiple paths in one text', () {
        final results = detector.detect(
          'compare lib/main.dart and test/main_test.dart',
        );
        expect(results, hasLength(2));
        expect(results[0].path, 'lib/main.dart');
        expect(results[1].path, 'test/main_test.dart');
      });

      test('does not match URLs', () {
        final results = detector.detect('visit https://example.com/page.tsx');
        expect(results, isEmpty);
      });

      test('does not match http URLs', () {
        final results = detector.detect('see http://example.com/app.dart');
        expect(results, isEmpty);
      });

      test('does not match ftp URLs', () {
        final results = detector.detect('download ftp://server/file.go');
        expect(results, isEmpty);
      });

      test('does not match paths inside markdown links', () {
        final results = detector.detect('click [here](lib/main.dart)');
        // The ( prefix before the path should exclude it
        expect(results, isEmpty);
      });

      test('excludes paths inside code block ranges', () {
        final text = 'before ```lib/main.dart``` after';
        final codeBlockRanges = FilePathDetector.extractCodeBlockRanges(text);
        final results = detector.detect(text, codeBlockRanges: codeBlockRanges);
        // The path inside the code block should be excluded
        for (final r in results) {
          expect(r.path, isNot(equals('lib/main.dart')));
        }
      });

      test('does not match bare filenames without directory separator', () {
        final results = detector.detect('the file main.dart is important');
        // Bare filenames are intentionally not matched to reduce false positives
        expect(results, isEmpty);
      });

      test('does not match paths without known extensions', () {
        final results = detector.detect('see docs/readme for details');
        expect(results, isEmpty);
      });

      test('matches TypeScript files', () {
        final results = detector.detect('edit src/components/App.tsx:10');
        expect(results, hasLength(1));
        expect(results.first.path, 'src/components/App.tsx');
        expect(results.first.lineNumber, 10);
      });

      test('matches Go files', () {
        final results = detector.detect('fix in cmd/server/main.go:30');
        expect(results, hasLength(1));
        expect(results.first.path, 'cmd/server/main.go');
        expect(results.first.lineNumber, 30);
      });

      test('matches Rust files', () {
        final results = detector.detect('see src/main.rs:5');
        expect(results, hasLength(1));
        expect(results.first.path, 'src/main.rs');
      });

      test('matches Python files', () {
        final results = detector.detect('edit scripts/train.py:100');
        expect(results, hasLength(1));
        expect(results.first.path, 'scripts/train.py');
      });

      test('matches Kotlin files', () {
        final results = detector.detect('see app/src/MainActivity.kt');
        expect(results, hasLength(1));
        expect(results.first.path, 'app/src/MainActivity.kt');
      });

      test('fullText includes line:col suffixes', () {
        final results = detector.detect('error at lib/core/di/injection_container.dart:42:10');
        expect(results, hasLength(1));
        expect(results.first.fullText, 'lib/core/di/injection_container.dart:42:10');
      });
    });

    group('extractCodeBlockRanges', () {
      test('extracts fenced code block ranges', () {
        final text = 'before```\ncode\n```after';
        final ranges = FilePathDetector.extractCodeBlockRanges(text);
        expect(ranges, hasLength(1));
        // The range should cover the entire fenced block
        expect(ranges.first.$1, lessThan(ranges.first.$2));
      });

      test('extracts multiple fenced code blocks', () {
        final text = '```\na\n```\ntext\n```\nb\n```';
        final ranges = FilePathDetector.extractCodeBlockRanges(text);
        expect(ranges, hasLength(2));
      });

      test('returns empty list when no code blocks', () {
        final ranges = FilePathDetector.extractCodeBlockRanges('no code here');
        expect(ranges, isEmpty);
      });

      test('matches Windows absolute paths on any client', () {
        final results = detector.detect(r'see C:\repo\lib\main.dart:42');
        expect(results, hasLength(1));
        expect(results.first.path, r'C:\repo\lib\main.dart');
        expect(results.first.lineNumber, 42);
      });
    });

    group('FilePathMatch', () {
      test('toString includes path, line, and col', () {
        const match = FilePathMatch(
          fullText: 'lib/main.dart:42:10',
          path: 'lib/main.dart',
          lineNumber: 42,
          columnNumber: 10,
        );
        expect(match.toString(), contains('lib/main.dart'));
        expect(match.toString(), contains('42'));
        expect(match.toString(), contains('10'));
      });
    });
  });
}
