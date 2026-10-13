import 'package:codewalk/features/sessions/session_history_controller.dart';
import 'package:codewalk/shared/sessions/session_history_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fakes.dart';
import 'history_fakes.dart';

void main() {
  late CatalogRig rig;
  late SessionHistoryController controller;
  late List<HistorySource> sources;
  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final catalog = CatalogSource(profile('a'));
    sources = [];
    controller = SessionHistoryController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: catalog.row('one'),
      sourceFactory: (p, c, ref) {
        final source = HistorySource(ref);
        sources.add(source);
        return source;
      },
    );
  });
  tearDown(() {
    controller.dispose();
    rig.dispose();
  });

  test(
    'canonical fanout differs from message count; order dedupe and resident cap',
    () async {
      final first = controller.refresh();
      final s = sources.single;
      s.respond(List.generate(300, s.item), next: 'A');
      await first;
      expect(controller.items, hasLength(300));
      final second = controller.loadMore();
      s.respond(List.generate(300, (n) => s.item(n + 250)), next: 'B');
      await second;
      expect(controller.items, hasLength(500));
      expect(controller.items.last.id, s.item(499).id);
      expect(controller.limited, isTrue);
      expect(controller.hasMore, isFalse);
    },
  );
  test(
    'refresh cancels uncooperative read and rejects late success or errors',
    () async {
      final old = controller.refresh();
      final a = sources.single;
      final current = controller.refresh();
      final b = sources.last;
      expect(a.tasks.single.cancelled, isTrue);
      expect(a.closes, 1);
      a.fail(SessionHistoryFailure.authenticationRequired);
      await old;
      expect(controller.loading, isTrue);
      expect(controller.failure, isNull);
      b.respond([b.item(1)]);
      await current;
      expect(controller.items.single.id, b.item(1).id);
    },
  );
  test(
    'empty pages keep continuations and cycles fail without appending',
    () async {
      final first = controller.refresh();
      final s = sources.single;
      s.respond([], next: 'A');
      await first;
      expect(controller.hasMore, isTrue);
      final second = controller.loadMore();
      s.respond([], next: 'B');
      await second;
      final third = controller.loadMore();
      s.respond([s.item(1)], next: 'A');
      await third;
      expect(controller.items, isEmpty);
      expect(controller.failure, SessionHistoryFailure.invalidCursor);
      expect(controller.hasMore, isFalse);
    },
  );
  test('ten empty continuation pages stop with a local limit', () async {
    final first = controller.refresh();
    final s = sources.single;
    s.respond([], next: '0');
    await first;
    for (var n = 1; n < 10; n++) {
      final read = controller.loadMore();
      s.respond([], next: '$n');
      await read;
    }
    expect(controller.limited, isTrue);
    expect(controller.hasMore, isFalse);
  });
  test('auth rejection clears data and closes source', () async {
    final first = controller.refresh();
    final s = sources.single;
    s.respond([s.item(1)], next: 'A');
    await first;
    final second = controller.loadMore();
    s.fail(SessionHistoryFailure.authenticationRequired);
    await second;
    expect(controller.items, isEmpty);
    expect(s.closes, 1);
    expect(controller.failure, SessionHistoryFailure.authenticationRequired);
    expect(controller.loading, isFalse);
  });
  test('host reload cancels active task and discards late results', () async {
    final read = controller.refresh();
    final s = sources.single;
    rig.repository.secrets['profile_a'] = 'changed';
    await rig.hosts.load();
    expect(s.tasks.single.cancelled, isTrue);
    expect(s.closes, 1);
    s.respond([s.item(1)]);
    await read;
    expect(controller.items, isEmpty);
    expect(controller.loading, isFalse);
  });
  test('disposed page drops late response and closes exactly once', () async {
    final read = controller.refresh();
    final s = sources.single;
    controller.dispose();
    s.respond([s.item(1)]);
    await read;
    expect(controller.items, isEmpty);
    expect(s.closes, 1);
  });
  for (final badPage in ['duplicate', 'foreign', 'version', 'over-limit']) {
    test('atomically rejects $badPage response', () async {
      final read = controller.refresh();
      final s = sources.single;
      final items = switch (badPage) {
        'duplicate' => [s.item(1), s.item(1)],
        'foreign' => [
          HistorySource(
            const SessionRef(
              HostId('other'),
              HarnessInstanceId('other'),
              'ses_one',
            ),
          ).item(1),
        ],
        'version' => [s.item(1, version: '2.0.21')],
        _ => List.generate(501, s.item),
      };
      s.respond(items);
      await read;
      expect(controller.items, isEmpty);
      expect(controller.failure, SessionHistoryFailure.incompatibleResponse);
    });
  }
  test(
    'factory failures are safe and manual retry remains available',
    () async {
      controller.dispose();
      controller = SessionHistoryController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: CatalogSource(profile('a')).row('one'),
        sourceFactory: (_, _, _) => throw StateError('private details'),
      );
      await controller.refresh();
      expect(controller.failure, SessionHistoryFailure.connection);
      expect(controller.loading, isFalse);
      expect(controller.items, isEmpty);
    },
  );
  test('known expired credential blocks source construction', () async {
    rig.repository.credentials['profile_a'] = EndpointCredential(
      kind: EndpointAuthKind.paired,
      secret: 'fake',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    await rig.hosts.load();
    await controller.refresh();
    expect(sources, isEmpty);
    expect(controller.failure, SessionHistoryFailure.authenticationRequired);
  });
  test('source version drift clears old items and continuation', () async {
    final first = controller.refresh();
    final s = sources.single;
    s.respond([s.item(1)], next: 'A');
    await first;
    final second = controller.loadMore();
    s.fail(SessionHistoryFailure.sourceChanged);
    await second;
    expect(controller.items, isEmpty);
    expect(controller.hasMore, isFalse);
    expect(controller.failure, SessionHistoryFailure.sourceChanged);
  });
  test(
    'failed refresh retains marked stale data without the old cursor',
    () async {
      final first = controller.refresh();
      final s = sources.single;
      s.respond([s.item(1)], next: 'A');
      await first;
      final refresh = controller.refresh();
      sources.last.fail(SessionHistoryFailure.connection);
      await refresh;
      expect(controller.items, hasLength(1));
      expect(controller.stale, isTrue);
      expect(controller.hasMore, isFalse);
    },
  );
  test(
    'storage failure on refresh is unavailable rather than bad credentials',
    () async {
      rig.repository.failLoad = true;
      await rig.hosts.load();
      await controller.refresh();
      expect(controller.failure, SessionHistoryFailure.unavailable);
      expect(sources, isEmpty);
    },
  );
}
