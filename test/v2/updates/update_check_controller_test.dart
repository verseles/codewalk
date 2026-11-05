import 'dart:async';
import 'dart:convert';

import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
  bool failWrite = false;
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object value) async {
    if (failWrite) throw StateError('storage');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class PendingTask implements ReleaseSourceTask {
  final completion = Completer<ReleaseSourceResult>();
  bool cancelled = false;
  @override
  Future<ReleaseSourceResult> get result => completion.future;
  @override
  void cancel() => cancelled = true;
}

class ControlledSource implements ReleaseSource {
  final tasks = <PendingTask>[];
  bool closed = false;
  @override
  ReleaseSourceTask start() => PendingTask().also(tasks.add);
  @override
  void close() => closed = true;
}

extension<T> on T {
  T also(void Function(T) action) {
    action(this);
    return this;
  }
}

String listing(List<String> tags) => jsonEncode([
  for (final tag in tags)
    {
      'tag_name': tag,
      'draft': false,
      'prerelease': tag.contains('-'),
      'assets': [
        {
          'name': 'codewalk-linux-x64.tar.gz',
          'browser_download_url':
              'https://github.com/verseles/codewalk/releases/download/$tag/codewalk-linux-x64.tar.gz',
        },
      ],
    },
]);

void main() {
  late MemoryBackend backend;
  late ControlledSource source;
  var installed = '2.0.0-beta.1';
  var now = DateTime.utc(2026, 11, 4);

  UpdateCheckController controller({
    UpdateTarget? target = UpdateTarget.linuxX64,
  }) => UpdateCheckController(
    source: source,
    store: V2MetadataStore(backend: backend),
    installedVersion: () async => installed,
    target: target,
    clock: () => now,
  );

  setUp(() {
    backend = MemoryBackend();
    source = ControlledSource();
    installed = '2.0.0-beta.1';
    now = DateTime.utc(2026, 11, 4);
  });

  Future<void> answer(String body) async {
    await pumpEventQueue();
    source.tasks.last.completion.complete(ReleaseSourceResult.success(body));
  }

  test('optional build metadata cannot block automatic discovery', () async {
    final build = Completer<String>();
    final updates = UpdateCheckController(
      source: source,
      store: V2MetadataStore(backend: backend),
      installedVersion: () async => installed,
      installedBuild: () => build.future,
      target: UpdateTarget.linuxX64,
    );
    addTearDown(updates.dispose);
    final check = updates.check(silent: true, force: false);
    await answer(listing(['v2.0.0']));
    await check;
    expect(updates.candidate?.tag, 'v2.0.0');
    expect(updates.installedBuild, isNull);
    build.complete('42');
    await pumpEventQueue();
    expect(updates.installedBuild, '42');
  });

  test(
    'manual checks honor quota deadlines and silent recovery clears failure',
    () async {
      final updates = controller();
      addTearDown(updates.dispose);
      final first = updates.check();
      await pumpEventQueue();
      source.tasks.last.completion.complete(
        ReleaseSourceResult.failure(
          ReleaseSourceFailure.rateLimited,
          retryAt: now.add(const Duration(days: 2)),
        ),
      );
      await first;
      await updates.check();
      expect(source.tasks, hasLength(1));
      expect(updates.failure, ReleaseSourceFailure.rateLimited);
      now = now.add(const Duration(days: 2));
      final recovery = updates.check(silent: true, force: false);
      await answer('[]');
      await recovery;
      expect(updates.status, UpdateCheckStatus.idle);
      expect(updates.failure, isNull);
      expect(source.tasks, hasLength(2));
    },
  );

  test(
    'a persisted quota blocks all paths after restart until its deadline',
    () async {
      final first = controller();
      final check = first.check();
      await pumpEventQueue();
      final deadline = now.add(const Duration(hours: 3));
      source.tasks.last.completion.complete(
        ReleaseSourceResult.failure(
          ReleaseSourceFailure.rateLimited,
          retryAt: deadline,
        ),
      );
      await check;
      first.dispose();
      expect(
        backend.values[UpdateCheckController.retryAtKey],
        deadline.millisecondsSinceEpoch,
      );
      final newSource = ControlledSource();
      final restored = UpdateCheckController(
        source: newSource,
        store: V2MetadataStore(backend: backend),
        installedVersion: () async => installed,
        target: UpdateTarget.linuxX64,
        clock: () => now,
      );
      addTearDown(restored.dispose);
      await restored.check(silent: true, force: false);
      await restored.check(silent: true);
      await restored.check();
      expect(newSource.tasks, isEmpty);
      expect(restored.failure, ReleaseSourceFailure.rateLimited);
      now = deadline;
      final retry = restored.check(silent: true, force: false);
      await pumpEventQueue();
      expect(newSource.tasks, hasLength(1));
      newSource.tasks.single.completion.complete(
        const ReleaseSourceResult.success('[]'),
      );
      await retry;
      expect(restored.status, UpdateCheckStatus.idle);
      expect(
        backend.values.containsKey(UpdateCheckController.retryAtKey),
        isFalse,
      );
    },
  );

  test('an implausible persisted deadline cannot lock discovery out', () async {
    backend.values[UpdateCheckController.retryAtKey] = now
        .add(const Duration(days: 31))
        .millisecondsSinceEpoch;
    final updates = controller();
    addTearDown(updates.dispose);
    final check = updates.check();
    await answer('[]');
    await check;
    expect(source.tasks, hasLength(1));
    expect(updates.status, UpdateCheckStatus.upToDate);
    expect(
      backend.values.containsKey(UpdateCheckController.retryAtKey),
      isFalse,
    );
  });

  test('stable is the default and never offers a beta', () async {
    final updates = controller();
    final check = updates.check();
    expect(updates.status, UpdateCheckStatus.checking);
    await answer(listing(['v2.0.0-beta.2']));
    await check;
    expect(updates.channel, UpdateChannel.stable);
    expect(updates.status, UpdateCheckStatus.upToDate);
    expect(updates.installedVersion, '2.0.0-beta.1');
  });

  test('a second tap while checking starts nothing', () async {
    final updates = controller();
    final first = updates.check();
    final second = updates.check();
    await answer(listing(['v2.0.0']));
    await Future.wait([first, second]);
    expect(source.tasks, hasLength(1));
    expect(updates.status, UpdateCheckStatus.available);
  });

  test(
    'automatic reuse lasts one hour while manual checks bypass it',
    () async {
      final updates = controller();
      var check = updates.check(silent: true, force: false);
      await answer(listing(['v2.0.0']));
      await check;
      await updates.check(silent: true, force: false);
      expect(source.tasks, hasLength(1));
      check = updates.check();
      await answer(listing(['v2.0.0']));
      await check;
      expect(source.tasks, hasLength(2));
      now = now.add(const Duration(hours: 1));
      check = updates.check(silent: true, force: false);
      await answer(listing(['v2.0.1']));
      await check;
      expect(source.tasks, hasLength(3));
    },
  );

  test('complete catalog survives restart and a malformed refresh', () async {
    final updates = controller();
    final entries = jsonDecode(listing(['v2.0.0'])) as List;
    (entries.single as Map)['published_at'] = '2026-11-04T12:00:00Z';
    (entries.single as Map)['body'] = '> 📣 New release\n\nFull notes';
    var check = updates.check();
    await answer(jsonEncode(entries));
    await check;
    expect(updates.catalog!.single.announcement, 'New release');
    final restored = controller();
    await restored.restore();
    expect(restored.catalog!.single.notes, 'Full notes');
    check = restored.check();
    await answer(listing(['v2.0.1']));
    await check;
    expect(restored.candidate?.tag, 'v2.0.1');
    expect(restored.catalog!.single.tag, 'v2.0.0');
    updates.dispose();
    restored.dispose();
  });

  test('news and update dismissals are independent', () async {
    installed = '2.0.0-beta.2';
    final updates = controller();
    await updates.setChannel(UpdateChannel.beta);
    final entries =
        jsonDecode(listing(['v2.0.0-beta.3', 'v2.0.0-beta.2'])) as List;
    for (final entry in entries) {
      (entry as Map)['published_at'] = '2026-11-04T12:00:00Z';
      entry['body'] = '> 📣 News for ${entry['tag_name']}';
    }
    final check = updates.check();
    await answer(jsonEncode(entries));
    await check;
    expect(updates.visibleCandidate?.tag, 'v2.0.0-beta.3');
    expect(updates.visibleNews?.tag, 'v2.0.0-beta.2');
    await updates.dismissCandidate();
    expect(updates.visibleCandidate, isNull);
    expect(updates.visibleNews, isNotNull);
    await updates.dismissNews();
    expect(updates.visibleNews, isNull);
    updates.dispose();
  });

  test('silent failure preserves a previously found update', () async {
    final updates = controller();
    final first = updates.check();
    await answer(listing(['v2.0.0']));
    await first;
    final second = updates.check(silent: true);
    expect(updates.status, UpdateCheckStatus.available);
    await pumpEventQueue();
    source.tasks.last.completion.complete(
      const ReleaseSourceResult.failure(ReleaseSourceFailure.timeout),
    );
    await second;
    expect(updates.status, UpdateCheckStatus.available);
    expect(updates.candidate?.tag, 'v2.0.0');
  });

  test('dismissal persists for that version only', () async {
    final updates = controller();
    var check = updates.check();
    await answer(listing(['v2.0.0']));
    await check;
    expect(await updates.dismissCandidate(), isTrue);
    expect(updates.visibleCandidate, isNull);

    final restored = controller();
    check = restored.check();
    await answer(listing(['v2.0.0']));
    await check;
    expect(restored.visibleCandidate, isNull);
    check = restored.check();
    await answer(listing(['v2.0.1']));
    await check;
    expect(restored.visibleCandidate?.tag, 'v2.0.1');
    restored.dispose();
    updates.dispose();
  });

  test('manual request joins an in-flight silent check', () async {
    final updates = controller();
    final silent = updates.check(silent: true);
    final manual = updates.check();
    expect(updates.status, UpdateCheckStatus.checking);
    await answer(listing(['v2.0.0']));
    await Future.wait([silent, manual]);
    expect(source.tasks, hasLength(1));
    expect(updates.status, UpdateCheckStatus.available);
  });

  test('the beta opt-in is saved and offers the newest beta', () async {
    final updates = controller();
    await updates.setChannel(UpdateChannel.beta);
    expect(backend.values[UpdateCheckController.channelKey], 'beta');
    final check = updates.check();
    await answer(listing(['v2.0.0-beta.10', 'v2.0.0-beta.2']));
    await check;
    expect(updates.status, UpdateCheckStatus.available);
    expect(updates.candidate?.tag, 'v2.0.0-beta.10');

    final restored = controller();
    await restored.restore();
    expect(restored.channel, UpdateChannel.beta);
  });

  test('an unreadable or unknown saved channel keeps stable', () async {
    backend.values[UpdateCheckController.channelKey] = 42;
    final updates = controller();
    await updates.restore();
    expect(updates.channel, UpdateChannel.stable);
  });

  test('changing channel cancels a check in flight', () async {
    final updates = controller();
    final check = updates.check();
    await pumpEventQueue();
    await updates.setChannel(UpdateChannel.beta);
    expect(source.tasks.single.cancelled, isTrue);
    expect(updates.status, UpdateCheckStatus.idle);
    source.tasks.single.completion.complete(
      ReleaseSourceResult.success(listing(['v2.0.0'])),
    );
    await check;
    expect(updates.status, UpdateCheckStatus.idle);
    expect(updates.candidate, isNull);
  });

  test('a failed source, bad body or unparsable version fails', () async {
    final updates = controller();
    var check = updates.check();
    await pumpEventQueue();
    source.tasks.last.completion.complete(
      const ReleaseSourceResult.failure(ReleaseSourceFailure.timeout),
    );
    await check;
    expect(updates.status, UpdateCheckStatus.failed);

    check = updates.check();
    await answer('{"message":"API rate limit exceeded"}');
    await check;
    expect(updates.status, UpdateCheckStatus.failed);

    installed = 'unknown';
    await updates.check();
    expect(updates.status, UpdateCheckStatus.failed);
  });

  test('a write failure keeps the choice for the session', () async {
    backend.failWrite = true;
    final updates = controller();
    await updates.setChannel(UpdateChannel.beta);
    expect(updates.channel, UpdateChannel.beta);
  });

  test('an unsupported platform never checks', () async {
    final updates = controller(target: null);
    expect(updates.supported, isFalse);
    await updates.check();
    expect(source.tasks, isEmpty);
    expect(updates.status, UpdateCheckStatus.idle);
  });

  test(
    'automatic notices are shown once per version, without manual toasts',
    () async {
      final updates = controller();
      var check = updates.check(silent: true, force: false);
      await answer(listing(['v2.0.0']));
      await check;
      expect(updates.automaticUpdateNotice?.tag, 'v2.0.0');
      updates.markNoticePresented('v2.0.0', news: false);
      expect(updates.automaticUpdateNotice, isNull);
      now = now.add(const Duration(hours: 1));
      check = updates.check(silent: true, force: false);
      await answer(listing(['v2.0.0']));
      await check;
      expect(updates.automaticUpdateNotice, isNull);
      check = updates.check();
      await answer(listing(['v2.0.1']));
      await check;
      expect(updates.automaticUpdateNotice, isNull);
    },
  );

  test('dispose cancels the check and closes the source', () async {
    final updates = controller();
    final check = updates.check();
    await pumpEventQueue();
    updates.dispose();
    expect(source.tasks.single.cancelled, isTrue);
    expect(source.closed, isTrue);
    source.tasks.single.completion.complete(
      ReleaseSourceResult.success(listing(['v2.0.0'])),
    );
    await check;
  });
}
