import 'package:codewalk/features/sessions/session_context_refresh.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late List<(String, CatalogTask)> reads;
  late List<(String, SessionContextSnapshot)> published;
  late SessionContextRefresh refresh;
  late DateTime clock;

  SessionContextRefresh create() => SessionContextRefresh(
    read: (directory) {
      final task = CatalogTask();
      reads.add((directory, task));
      return task;
    },
    publish: (directory, snapshot) => published.add((directory, snapshot)),
    now: () => clock,
  );

  setUp(() {
    reads = [];
    published = [];
    clock = DateTime.utc(2026, 10, 26);
    refresh = create();
  });

  testWidgets('contexts are read one at a time and new ones at once', (
    tester,
  ) async {
    refresh.track(['/a', '/b']);
    await tester.pump();
    await tester.pump(Duration.zero);
    expect(reads.map((r) => r.$1), ['/a']);
    reads.single.$2.completion.complete(Page(items: const []));
    await tester.pump();
    expect(reads.map((r) => r.$1), ['/a', '/b']);
    reads.last.$2.completion.complete(
      Page(items: const [], nextCursor: 'next'),
    );
    await tester.pump();
    expect(published.map((p) => (p.$1, p.$2.complete)), [
      ('/a', true),
      // An empty page ends the list even with a cursor.
      ('/b', true),
    ]);
    // Known contexts are not read again on a track alone.
    refresh.track(['/a', '/b'], known: {'/a', '/b'});
    await tester.pump(Duration.zero);
    expect(reads, hasLength(2));
  });

  testWidgets('server changes coalesce into one pass after the interval', (
    tester,
  ) async {
    refresh.track(['/a']);
    await tester.pump(Duration.zero);
    reads.single.$2.completion.complete(Page(items: const []));
    await tester.pump();
    refresh
      ..changed()
      ..changed()
      ..changed();
    await tester.pump(const Duration(seconds: 9));
    expect(reads, hasLength(1));
    clock = clock.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(reads, hasLength(2));
  });

  testWidgets('three failed passes stop the automatic passes', (tester) async {
    refresh.track(['/a']);
    for (var pass = 0; pass < 3; pass++) {
      await tester.pump(Duration.zero);
      reads.last.$2.completion.completeError(
        const SessionCatalogException(SessionCatalogFailure.unavailable),
      );
      await tester.pump();
      clock = clock.add(const Duration(seconds: 10));
      refresh.changed();
      await tester.pump(const Duration(seconds: 10));
    }
    expect(reads, hasLength(3));
    // An explicit refresh lifts the stop.
    refresh.refresh();
    await tester.pump(Duration.zero);
    expect(reads, hasLength(4));
    expect(published, isEmpty);
  });

  testWidgets('a cancelled pass drops its late answer and its read', (
    tester,
  ) async {
    refresh.track(['/a']);
    await tester.pump(Duration.zero);
    final task = reads.single.$2;
    refresh.cancel();
    expect(task.cancelled, isTrue);
    task.completion.complete(Page(items: const []));
    await tester.pump();
    expect(published, isEmpty);
    refresh.changed();
    await tester.pump(const Duration(minutes: 1));
    expect(reads, hasLength(1));
  });

  testWidgets('a read that cannot start counts as a failed pass', (
    tester,
  ) async {
    final failing = SessionContextRefresh(
      read: (_) =>
          throw const SessionCatalogException(SessionCatalogFailure.cancelled),
      publish: (directory, snapshot) => published.add((directory, snapshot)),
      now: () => clock,
    );
    failing.track(['/a']);
    await tester.pump(Duration.zero);
    expect(published, isEmpty);
    failing.cancel();
  });
}
