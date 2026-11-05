import 'package:codewalk/shared/releases/release_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> release(String tag, {String? body}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': tag.contains('-'),
  'published_at': '2026-11-04T12:00:00Z',
  'body': body,
};

void main() {
  test('preserves announcements and orders eligible releases as SemVer', () {
    final entries = parseReleaseCatalog([
      release('v2.0.0-beta.2', body: '> 📣 Hello\n\nFull notes'),
      release('v2.0.0-beta.10'),
      release('v1.266.0-native.1'),
      release('v2.0.0'),
    ]);
    expect(entries.map((e) => e.tag), [
      'v2.0.0',
      'v2.0.0-beta.10',
      'v2.0.0-beta.2',
    ]);
    expect(entries.last.announcement, 'Hello');
    expect(entries.last.notes, 'Full notes');
  });

  test('rejects duplicate tags or malformed metadata in eligible records', () {
    expect(
      () => parseReleaseCatalog([release('v2.0.0'), release('v2.0.0')]),
      throwsFormatException,
    );
    expect(
      () => parseReleaseCatalog([
        {...release('v2.0.0'), 'published_at': 'invalid'},
      ]),
      throwsFormatException,
    );
  });
}
