import 'package:codewalk/shared/releases/app_version.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter_test/flutter_test.dart';

AppVersion v(String text) => AppVersion.tryParse(text)!;

Map<String, Object?> release(
  String tag, {
  bool? prerelease,
  bool draft = false,
  List<String> assets = const [
    'codewalk-android-arm64.apk',
    'codewalk-linux-x64.tar.gz',
    'codewalk-linux-arm64.tar.gz',
  ],
  String? urlTag,
}) => {
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease ?? tag.contains('-'),
  'assets': [
    for (final name in assets)
      {
        'name': name,
        'browser_download_url':
            'https://github.com/verseles/codewalk/releases/download/${urlTag ?? tag}/$name',
      },
  ],
};

UpdateCandidate? pick(
  List<Object?> releases, {
  UpdateChannel channel = UpdateChannel.beta,
  String current = '2.0.0-beta.1',
  UpdateTarget target = UpdateTarget.androidArm64,
}) => selectUpdate(
  releases: releases,
  channel: channel,
  current: v(current),
  target: target,
);

void main() {
  group('AppVersion', () {
    test('orders prereleases numerically and below their release', () {
      final ordered = [
        '1.266.0',
        '2.0.0-alpha',
        '2.0.0-alpha.1',
        '2.0.0-alpha.beta',
        '2.0.0-beta',
        '2.0.0-beta.2',
        '2.0.0-beta.10',
        '2.0.0-beta.11',
        '2.0.0-rc.1',
        '2.0.0',
        '2.0.1',
        '10.0.0',
      ].map(v).toList();
      for (var i = 0; i + 1 < ordered.length; i++) {
        expect(
          ordered[i].compareTo(ordered[i + 1]),
          lessThan(0),
          reason: '${ordered[i]} < ${ordered[i + 1]}',
        );
      }
      expect(
        (ordered.toList()
          ..shuffle()
          ..sort()),
        ordered,
      );
    });

    test('ignores build metadata and keeps hyphenated identifiers lexical', () {
      expect(v('2.0.0-beta.1+1792800000'), v('2.0.0-beta.1+1'));
      expect(v('2.0.0-beta.1+5').compareTo(v('2.0.0-beta.1')), 0);
      // "-1" is alphanumeric, so it ranks above every numeric identifier.
      expect(v('2.0.0-beta.-1').compareTo(v('2.0.0-beta.99')), greaterThan(0));
    });

    test('rejects malformed versions', () {
      for (final text in [
        '',
        '2',
        '2.0',
        'v2.0.0',
        '02.0.0',
        '2.0.0-beta.01',
        '2.0.0-',
        '2.0.0-beta..1',
        '2.0.0+',
        '2.0.0 ',
      ]) {
        expect(AppVersion.tryParse(text), isNull, reason: text);
      }
    });
  });

  group('selectUpdate', () {
    test('beta offers the newest beta above the installed one', () {
      final candidate = pick([
        release('v2.0.0-beta.2'),
        release('v2.0.0-beta.10'),
        release('v2.0.0-beta.9'),
      ]);
      expect(candidate?.tag, 'v2.0.0-beta.10');
      expect(
        candidate?.assetUrl.toString(),
        'https://github.com/verseles/codewalk/releases/download/v2.0.0-beta.10/codewalk-android-arm64.apk',
      );
    });

    test('beta also offers the final release, stable never offers betas', () {
      final releases = [release('v2.0.0-beta.3'), release('v2.0.0')];
      expect(pick(releases)?.tag, 'v2.0.0');
      expect(pick(releases, channel: UpdateChannel.stable)?.tag, 'v2.0.0');
      expect(
        pick([release('v2.0.0-beta.3')], channel: UpdateChannel.stable),
        isNull,
      );
    });

    test('never offers CodeWalk 1, native cohorts or other majors', () {
      expect(
        pick([
          release('v1.266.0'),
          release('v1.266.0-native.1'),
          release('v2.0.0-native.1'),
          release('v3.0.0'),
          release('v3.0.0-beta.1'),
          release('v2.0.0-rc.1'),
          release('v2.0.1-beta.1'),
          release('v2.0.0-beta.0'),
        ], current: '1.265.0'),
        isNull,
      );
    });

    test('a CodeWalk 1 install is offered the first beta', () {
      expect(
        pick([release('v2.0.0-beta.1')], current: '1.265.0')?.tag,
        'v2.0.0-beta.1',
      );
    });

    test('skips drafts, mismatched flags and non-canonical tags', () {
      expect(
        pick([
          release('v2.0.0-beta.5', draft: true),
          release('v2.0.0-beta.6', prerelease: false),
          release('v2.0.0', prerelease: true),
          release('v2.0.0-beta.7+1'),
          release('2.0.0-beta.8'),
          {'tag_name': 'v2.0.0-beta.9', 'prerelease': true, 'assets': []},
          'not a release',
          null,
        ]),
        isNull,
      );
    });

    test('requires the target asset from this repository and tag', () {
      expect(
        pick([
          release('v2.0.0-beta.2', assets: ['codewalk-linux-x64.tar.gz']),
        ]),
        isNull,
      );
      expect(pick([release('v2.0.0-beta.2', urlTag: 'v2.0.0-beta.3')]), isNull);
      final foreign = release('v2.0.0-beta.2');
      (foreign['assets']! as List).first['browser_download_url'] =
          'https://example.com/codewalk-android-arm64.apk';
      expect(pick([foreign]), isNull);
      expect(
        pick([
          release('v2.0.0-beta.2'),
        ], target: UpdateTarget.linuxArm64)?.assetUrl.pathSegments.last,
        'codewalk-linux-arm64.tar.gz',
      );
    });

    test('nothing newer means no candidate', () {
      expect(pick([release('v2.0.0-beta.1')]), isNull);
      expect(pick([], current: '2.0.0-beta.1'), isNull);
    });

    test('a listing that is not a list is invalid', () {
      expect(
        () => selectUpdate(
          releases: {'message': 'rate limited'},
          channel: UpdateChannel.beta,
          current: v('2.0.0-beta.1'),
          target: UpdateTarget.linuxX64,
        ),
        throwsFormatException,
      );
    });

    test('the Linux command names the exact tag and channel', () {
      expect(
        linuxInstallCommand(pick([release('v2.0.0-beta.4')])!),
        'curl -fsSL install.cat/verseles/codewalk | '
        'CODEWALK_CHANNEL=beta CODEWALK_VERSION=v2.0.0-beta.4 sh',
      );
      expect(
        linuxInstallCommand(pick([release('v2.0.0')])!),
        contains('CODEWALK_CHANNEL=stable CODEWALK_VERSION=v2.0.0 sh'),
      );
    });
  });
}
