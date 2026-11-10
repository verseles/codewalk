import 'dart:convert';

import 'package:codewalk/features/settings/release_announcements_controller.dart';
import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

class Source implements ReleaseSource, ReleaseSourceTask {
  @override
  ReleaseSourceTask start({String? until}) => this;
  @override
  void close() {}
  @override
  void cancel() {}
  @override
  Future<ReleaseSourceResult> get result async => ReleaseSourceResult.success(
    jsonEncode([
      for (final beta in [1, 2])
        {
          'tag_name': 'v2.0.0-beta.$beta',
          'draft': false,
          'prerelease': true,
          'published_at': '2026-11-04T12:00:00Z',
          'body': '> 📣 Beta $beta',
          'assets': [],
        },
    ]),
  );
}

void main() {
  test(
    'saved catalog supports announcements offline without an update check',
    () async {
      final store = V2MetadataStore(backend: FakeMetadataBackend());
      final seed = UpdateCheckController(
        source: Source(),
        store: store,
        installedVersion: () async => '2.0.0-beta.2',
        target: UpdateTarget.androidArm64,
      );
      await seed.check();
      seed.dispose();
      final checks = UpdateCheckController(
        source: Source(),
        store: store,
        installedVersion: () async => '2.0.0-beta.2',
        target: UpdateTarget.androidArm64,
      );
      final announcements = ReleaseAnnouncementsController(
        store: store,
        checks: checks,
        installedVersion: () async => '2.0.0-beta.2',
        existingInstallation: Future.value(true),
      );
      addTearDown(() {
        announcements.dispose();
        checks.dispose();
      });
      await announcements.start();
      expect(checks.lastSuccessfulCheck, isNull);
      expect(announcements.pendingAnnouncements!.single.announcement, 'Beta 2');
      expect(announcements.shouldNotifyNews('v2.0.0-beta.2'), isTrue);
      expect(
        await announcements.acknowledge(announcements.pendingKey!),
        isTrue,
      );
      expect(announcements.shouldNotifyNews('v2.0.0-beta.2'), isTrue);
      expect(checks.visibleNews, isNotNull);
    },
  );
  test(
    'fresh baseline skips the dialog while independent news remains eligible',
    () async {
      final store = V2MetadataStore(backend: FakeMetadataBackend());
      final checks = UpdateCheckController(
        source: Source(),
        store: store,
        installedVersion: () async => '2.0.0-beta.2',
        target: UpdateTarget.androidArm64,
      );
      final announcements = ReleaseAnnouncementsController(
        store: store,
        checks: checks,
        installedVersion: () async => '2.0.0-beta.2',
        existingInstallation: Future.value(false),
      );
      addTearDown(() {
        announcements.dispose();
        checks.dispose();
      });
      await checks.check(silent: true, force: false);
      expect(announcements.shouldNotifyNews('v2.0.0-beta.2'), isFalse);
      await announcements.start();
      expect(announcements.shouldNotifyNews('v2.0.0-beta.2'), isTrue);
      expect(announcements.pendingKey, isNull);
      expect(checks.visibleNews?.tag, 'v2.0.0-beta.2');
    },
  );

  test(
    'existing installation announcement remains pending until explicit acknowledgement',
    () async {
      final store = V2MetadataStore(backend: FakeMetadataBackend());
      final checks = UpdateCheckController(
        source: Source(),
        store: store,
        installedVersion: () async => '2.0.0-beta.2',
        target: UpdateTarget.androidArm64,
      );
      final announcements = ReleaseAnnouncementsController(
        store: store,
        checks: checks,
        installedVersion: () async => '2.0.0-beta.2',
        existingInstallation: Future.value(true),
      );
      addTearDown(() {
        announcements.dispose();
        checks.dispose();
      });
      await announcements.start();
      await checks.check();
      expect(announcements.pendingAnnouncements!.single.announcement, 'Beta 2');
      final key = announcements.pendingKey!;
      announcements.markPresented(key);
      expect(announcements.pendingAnnouncements, isNull);
      expect(await announcements.acknowledge(key), isTrue);
      expect(announcements.pendingKey, isNull);
    },
  );
}
