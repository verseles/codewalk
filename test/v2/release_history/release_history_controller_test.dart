import 'dart:async';
import 'dart:convert';

import 'package:codewalk/features/settings/release_history_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:flutter_test/flutter_test.dart';

const archive =
    '## v2.0.0 - 2026-10-09\nNew\n'
    '## v1.9.0 - 2026-10-08\nOld';

class MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
  bool failWrite = false;
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object value) async {
    if (failWrite) throw StateError('private storage details');
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
  ReleaseSourceTask start() {
    final task = PendingTask();
    tasks.add(task);
    return task;
  }

  @override
  void close() => closed = true;
}

void main() {
  final now = DateTime.utc(2026, 10, 9, 12);
  test(
    'cold load coalesces and saved copy survives shortened refresh',
    () async {
      final backend = MemoryBackend();
      final source = ControlledSource();
      final history = ReleaseHistoryController(
        source: source,
        store: V2MetadataStore(backend: backend),
        now: () => now,
      );
      final first = history.load();
      expect(identical(history.load(), first), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(source.tasks.length, 1);
      source.tasks.single.completion.complete(
        const ReleaseSourceResult.success(archive),
      );
      await first;
      expect(history.failed, isFalse);
      expect(history.entries.length, 2);
      await history.load();
      expect(source.tasks.length, 1);
      final refresh = history.load(forceRefresh: true);
      source.tasks.last.completion.complete(
        const ReleaseSourceResult.success('## v2.0.0 - 2026-10-09\nNew'),
      );
      await refresh;
      expect(history.failed, isTrue);
      expect(history.entries.length, 2);
      expect(history.savedCopyAvailable, isTrue);
      expect(
        jsonDecode(
          backend.values[ReleaseHistoryController.cacheKey] as String,
        )['body'],
        archive,
      );
      final emptyRefresh = history.load(forceRefresh: true);
      source.tasks.last.completion.complete(
        const ReleaseSourceResult.success(
          '## v2.0.0 - 2026-10-09\n> 📣\n'
          '## v1.9.0 - 2026-10-08\n> 📣',
        ),
      );
      await emptyRefresh;
      expect(history.failed, isTrue);
      expect(history.entries.length, 2);
      expect(
        jsonDecode(
          backend.values[ReleaseHistoryController.cacheKey] as String,
        )['body'],
        archive,
      );
      history.dispose();
    },
  );

  test(
    'future cache retains notes but cannot suppress remote recovery',
    () async {
      final backend = MemoryBackend();
      backend.values[ReleaseHistoryController.cacheKey] = jsonEncode({
        'body': archive,
        'fetchedAt': now.add(const Duration(hours: 1)).toIso8601String(),
      });
      final source = ControlledSource();
      final history = ReleaseHistoryController(
        source: source,
        store: V2MetadataStore(backend: backend),
        now: () => now,
      );
      final load = history.load();
      await Future<void>.delayed(Duration.zero);
      expect(source.tasks.length, 1);
      source.tasks.single.completion.complete(
        const ReleaseSourceResult.failure(ReleaseSourceFailure.unavailable),
      );
      await load;
      expect(history.failed, isTrue);
      expect(history.entries.length, 2);
      expect(history.fetchedAt, isNull);
      history.dispose();
    },
  );

  test('dispose cancels source and ignores late successful content', () async {
    final source = ControlledSource();
    final history = ReleaseHistoryController(
      source: source,
      store: V2MetadataStore(backend: MemoryBackend()),
    );
    var notifications = 0;
    history.addListener(() => notifications++);
    final load = history.load();
    await Future<void>.delayed(Duration.zero);
    final before = notifications;
    history.dispose();
    expect(source.closed, isTrue);
    expect(source.tasks.single.cancelled, isTrue);
    source.tasks.single.completion.complete(
      const ReleaseSourceResult.success(archive),
    );
    await load;
    expect(notifications, before);
    expect(history.entries, isEmpty);
  });
}
