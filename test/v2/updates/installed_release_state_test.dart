import 'package:codewalk/shared/releases/app_version.dart';
import 'package:codewalk/shared/releases/installed_release_state.dart';
import 'package:codewalk/shared/releases/release_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

AppVersion version(int beta) => AppVersion.tryParse('2.0.0-beta.$beta')!;
ReleaseCatalogEntry entry(int beta) => ReleaseCatalogEntry(
  tag: 'v${version(beta)}',
  version: version(beta),
  publishedAt: DateTime.utc(2026),
  notes: '',
  announcement: 'Beta $beta',
  body: '> 📣 Beta $beta',
);

void main() {
  test('a later upgrade retains unacknowledged announcements', () {
    final baseline = InstalledReleaseState.first(version(1), existing: false);
    final first = baseline.observe(version(2));
    final latest = first.observe(version(10));
    expect(latest.from, version(1));
    expect(latest.to, version(10));
    expect(
      latest.announcements([entry(10), entry(2), entry(1)])!.map((e) => e.tag),
      ['v2.0.0-beta.10', 'v2.0.0-beta.2'],
    );
    expect(latest.acknowledge(first.key).pending, isTrue);
    expect(latest.acknowledge(latest.key).pending, isFalse);
    expect(latest.observe(version(2)).to, version(10));
  });

  test('missing boundaries cannot acknowledge a maintenance-only interval', () {
    final state = InstalledReleaseState.first(
      version(1),
      existing: false,
    ).observe(version(2));
    expect(state.announcements([entry(2)]), isNull);
    expect(InstalledReleaseState.tryParse(state.toJson())!.key, state.key);
  });

  test('existing v2 installs include only the installed version initially', () {
    final state = InstalledReleaseState.first(version(2), existing: true);
    expect(
      state.announcements([entry(10), entry(2), entry(1)])!.single.version,
      version(2),
    );
    expect(
      InstalledReleaseState.first(version(2), existing: false).pending,
      isFalse,
    );
  });
}
