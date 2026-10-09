import 'dart:io';

import 'package:codewalk/shared/releases/release_archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real retained archive parses without coupling to legacy services', () {
    final entries = parseReleaseArchive(
      File('CHANGELOG.md').readAsStringSync(),
    );
    expect(entries, isNotEmpty);
    for (var i = 1; i < entries.length; i++) {
      expect(
        entries[i - 1].version.compareTo(entries[i].version),
        greaterThan(0),
      );
    }
    expect(() => entries.clear(), throwsUnsupportedError);
  });

  test('BOM CRLF, numeric ordering and original-language announcements', () {
    final entries = parseReleaseArchive(
      '\uFEFF# Archive\r\n'
      '## v2.9.0 - 2026-10-09\r\n> 📣 Olá\r\n> 続き\r\n\r\nNotes\r\n'
      '## v2.10.0 - 2026-10-08\r\n> 📣 Only announcement\r\n',
    );
    expect(entries.first.version.toString(), '2.10.0');
    expect(entries.first.notes, isEmpty);
    expect(entries.last.announcement, 'Olá\n続き');
    expect(entries.last.notes, 'Notes');
  });

  test(
    'rejects malformed boundaries rather than attaching wrong release notes',
    () {
      for (final source in [
        '# No releases',
        '## v1.0.0 - 2026-02-30\nNotes',
        '## v1.0.0-beta.1 - 2026-10-09\nNotes',
        '## v1.0.0+build - 2026-10-09\nNotes',
        '## v1.0.0 - 2026-10-09\n',
        '## v1.0.0 - 2026-10-09\n> 📣',
        '## v1.0.0 - 2026-10-09\nNotes\n## Unreleased\nOther',
        '## v1.0.0 - 2026-10-09\nNotes\n## v01.0.0 - 2026-10-08\nOther',
      ]) {
        expect(
          () => parseReleaseArchive(source),
          throwsFormatException,
          reason: source,
        );
      }
    },
  );

  test('large versions remain distinct and mid-body markers are notes', () {
    final entries = parseReleaseArchive(
      '## v18446744073709551616.0.0 - 2026-10-09\nNotes\n> 📣 Later\n'
      '## v18446744073709551615.0.0 - 2026-10-08\nOther',
    );
    expect(entries.first.version.toString(), '18446744073709551616.0.0');
    expect(entries.first.announcement, isNull);
    expect(entries.first.notes, contains('> 📣 Later'));
  });
}
