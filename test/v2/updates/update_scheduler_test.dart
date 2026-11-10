import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/features/settings/update_scheduler.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

class CountingSource implements ReleaseSource {
  CountingSource({this.delay = Duration.zero});
  final Duration delay;
  int count = 0;
  @override
  ReleaseSourceTask start({String? until}) {
    count++;
    return _Task(delay);
  }

  @override
  void close() {}
}

class _Task implements ReleaseSourceTask {
  _Task(this.delay);
  final Duration delay;
  @override
  Future<ReleaseSourceResult> get result async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return const ReleaseSourceResult.success('[]');
  }

  @override
  void cancel() {}
}

void main() {
  testWidgets(
    'hourly discovery runs after each cache expiry despite fetch latency',
    (tester) async {
      final source = CountingSource(delay: const Duration(seconds: 5));
      final store = V2MetadataStore(backend: FakeMetadataBackend());
      final checks = UpdateCheckController(
        source: source,
        store: store,
        installedVersion: () async => '2.0.0-beta.1',
        target: UpdateTarget.androidArm64,
        clock: tester.binding.clock.now,
      );
      final scheduler = UpdateScheduler(
        checks: checks,
        store: store,
        clock: tester.binding.clock.now,
      );
      try {
        await scheduler.start();
        await tester.pump(const Duration(seconds: 5));
        expect(source.count, 1);
        await tester.pump(const Duration(hours: 1));
        expect(source.count, 2);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(hours: 1));
        expect(source.count, 3);
        await tester.pump(const Duration(seconds: 5));
      } finally {
        scheduler.dispose();
        checks.dispose();
      }
    },
  );

  test(
    'settings checks are throttled and ignore the startup preference',
    () async {
      final backend = FakeMetadataBackend();
      final store = V2MetadataStore(backend: backend);
      final source = CountingSource();
      var now = DateTime.utc(2026, 11, 4);
      final checks = UpdateCheckController(
        source: source,
        store: store,
        installedVersion: () async => '2.0.0-beta.1',
        target: UpdateTarget.androidArm64,
      );
      final scheduler = UpdateScheduler(
        checks: checks,
        store: store,
        clock: () => now,
      );
      addTearDown(() {
        scheduler.dispose();
        checks.dispose();
      });
      await scheduler.start();
      await pumpEventQueue();
      expect(source.count, 1);
      expect(await scheduler.setEnabled(false), isTrue);
      await scheduler.settingsOpened();
      expect(source.count, 2);
      await scheduler.settingsOpened();
      expect(source.count, 2);
      now = now.add(const Duration(minutes: 20));
      await scheduler.settingsOpened();
      expect(source.count, 3);
    },
  );
}
