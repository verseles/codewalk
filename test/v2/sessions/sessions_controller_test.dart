import 'dart:async';

import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late CatalogRig rig;
  setUp(() => rig = CatalogRig());
  tearDown(() => rig.dispose());

  test(
    'explicit selection waits for settled credentials; no automatic reads',
    () async {
      await rig.save('a');
      final gate = rig.repository.credentialGate =
          Completer<EndpointCredential?>();
      final load = rig.sessions.initialize();
      await flush();
      expect(rig.hosts.loading, isTrue);
      expect(rig.hosts.profiles, hasLength(1));
      await rig.sessions.selectProfile('profile_a');
      expect(rig.sources, isEmpty);
      gate.complete(
        EndpointCredential(kind: EndpointAuthKind.password, secret: 'fake-a'),
      );
      await load;
      expect(rig.sessions.selectedProfile, isNull);
      expect(rig.sources, isEmpty);
      final read = rig.sessions.selectProfile('profile_a');
      rig.sources.single.respond([]);
      await read;
      expect(rig.sessions.loaded, isTrue);
      expect(rig.sources.single.queries.single.limit, 50);
    },
  );

  for (final lateError in [false, true]) {
    test(
      'A-B-A rejects obsolete ${lateError ? 'error' : 'success'} and finally',
      () async {
        await rig.save('a');
        await rig.save('b');
        await rig.sessions.initialize();
        final first = rig.sessions.selectProfile('profile_a');
        final a1 = rig.sources.last;
        final second = rig.sessions.selectProfile('profile_b');
        final b = rig.sources.last;
        final current = rig.sessions.selectProfile('profile_a');
        final a2 = rig.sources.last;
        expect(a1.tasks.single.cancelled, isTrue);
        expect(b.tasks.single.cancelled, isTrue);
        if (lateError) {
          a1.fail(SessionCatalogFailure.authenticationRequired);
        } else {
          a1.respond([a1.row('old')]);
        }
        b.respond([b.row('same')]);
        await Future.wait([first, second]);
        expect(rig.sessions.loading, isTrue);
        expect(rig.sessions.failure, isNull);
        expect(rig.sessions.sessions, isEmpty);
        a2.respond([a2.row('same')]);
        await current;
        expect(rig.sessions.sessions.single.info.ref.harnessRef, a2.harness);
        expect(rig.sessions.loading, isFalse);
        expect(a1.closes, 1);
        expect(b.closes, 1);
      },
    );
  }

  test('refresh supersedes page, old cursor and retained detail', () async {
    await rig.save('a');
    await rig.sessions.initialize();
    final initial = rig.sessions.selectProfile('profile_a');
    final source = rig.sources.single;
    source.respond([source.row('one')], next: 'cursorA');
    await initial;
    rig.sessions.inspect(source.row('one').info.ref);
    final paging = rig.sessions.loadMore();
    final oldTask = source.tasks.last;
    final refresh = rig.sessions.refresh();
    expect(oldTask.cancelled, isTrue);
    expect(rig.sessions.stale, isTrue);
    expect(rig.sessions.hasMore, isFalse);
    expect(identical(refresh, rig.sessions.refresh()), isTrue);
    oldTask.completion.complete(
      Page(items: [source.row('obsolete')], nextCursor: 'bad'),
    );
    await paging;
    expect(rig.sessions.loading, isTrue);
    source.respond([]);
    await refresh;
    expect(rig.sessions.sessions, isEmpty);
    expect(rig.sessions.selectedSession, isNull);
    expect(rig.sessions.stale, isFalse);
    expect(source.queries.map((q) => q.cursor), [null, 'cursorA', null]);
  });

  test(
    'manual paging preserves order, first occurrence and empty continuation',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final initial = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      source.respond([source.row('z'), source.row('a')], next: 'A');
      await initial;
      var paging = rig.sessions.loadMore();
      source.respond([
        source.row('a', title: 'changed'),
        source.row('m'),
      ], next: 'B');
      await paging;
      expect(rig.sessions.sessions.map((s) => s.info.title), ['z', 'a', 'm']);
      paging = rig.sessions.loadMore();
      source.respond([], next: 'C');
      await paging;
      expect(rig.sessions.hasMore, isTrue);
      expect(source.queries, hasLength(3));
      paging = rig.sessions.loadMore();
      source.respond([]);
      await paging;
      expect(rig.sessions.hasMore, isFalse);
      expect(rig.sessions.limited, isFalse);
    },
  );

  test(
    'transient page failure retries same cursor; auth clears catalog',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final initial = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      source.respond([source.row('one')], next: 'A');
      await initial;
      var paging = rig.sessions.loadMore();
      source.fail(SessionCatalogFailure.timeout);
      await paging;
      expect(rig.sessions.sessions, hasLength(1));
      expect(rig.sessions.hasMore, isTrue);
      paging = rig.sessions.loadMore();
      source.respond([source.row('two')], next: 'B');
      await paging;
      expect(source.queries.map((q) => q.cursor), [null, 'A', 'A']);
      paging = rig.sessions.loadMore();
      source.fail(SessionCatalogFailure.authenticationRequired);
      await paging;
      expect(rig.sessions.sessions, isEmpty);
      expect(
        rig.sessions.failure,
        SessionCatalogFailure.authenticationRequired,
      );
      expect(source.closes, 1);
    },
  );

  test(
    'failed refresh retains marked results but never old pagination',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final initial = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      source.respond([source.row('one')], next: 'A');
      await initial;
      final refresh = rig.sessions.refresh();
      source.fail(SessionCatalogFailure.unavailable);
      await refresh;
      expect(rig.sessions.stale, isTrue);
      expect(rig.sessions.sessions, hasLength(1));
      await rig.sessions.loadMore();
      expect(source.queries, hasLength(2));
    },
  );

  test(
    'multi-page cursor cycle rejected without publishing partial response',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final initial = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      source.respond([source.row('one')], next: 'A');
      await initial;
      var paging = rig.sessions.loadMore();
      source.respond([source.row('two')], next: 'B');
      await paging;
      paging = rig.sessions.loadMore();
      source.respond([source.row('bad')], next: 'A');
      await paging;
      expect(rig.sessions.failure, SessionCatalogFailure.invalidCursor);
      expect(rig.sessions.sessions.map((r) => r.info.title), ['one', 'two']);
      expect(rig.sessions.hasMore, isFalse);
    },
  );

  for (final foreign in [false, true]) {
    test(
      'reject ${foreign ? 'foreign harness' : 'duplicate within page'} atomically',
      () async {
        await rig.save('a');
        await rig.sessions.initialize();
        final initial = rig.sessions.selectProfile('profile_a');
        final source = rig.sources.single;
        source.respond(
          foreign
              ? [CatalogSource(profile('b')).row('one')]
              : [source.row('one'), source.row('one')],
        );
        await initial;
        expect(rig.sessions.sessions, isEmpty);
        expect(
          rig.sessions.failure,
          SessionCatalogFailure.incompatibleResponse,
        );
        expect(rig.sessions.loaded, isFalse);
      },
    );
  }

  test(
    'ten empty partial pages stop at local bound without automatic requests',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      var read = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      for (var i = 0; i < 10; i++) {
        source.respond([], next: 'cursor$i');
        await read;
        if (i < 9) read = rig.sessions.loadMore();
      }
      expect(rig.sessions.limited, isTrue);
      expect(rig.sessions.hasMore, isFalse);
      await rig.sessions.loadMore();
      expect(source.tasks, hasLength(10));
    },
  );

  for (final continuation in [false, true]) {
    test(
      '200-row bound distinguishes terminal page from limited continuation=$continuation',
      () async {
        await rig.save('a');
        await rig.sessions.initialize();
        var read = rig.sessions.selectProfile('profile_a');
        final source = rig.sources.single;
        for (var i = 0; i < 4; i++) {
          source.respond(
            List.generate(50, (j) => source.row('${i * 50 + j}')),
            next: i == 3 && !continuation ? null : 'cursor$i',
          );
          await read;
          if (i < 3) read = rig.sessions.loadMore();
        }
        expect(rig.sessions.sessions, hasLength(200));
        expect(rig.sessions.limited, continuation);
        expect(rig.sessions.hasMore, isFalse);
      },
    );
  }

  test(
    'credential repair invalidates reads, requires explicit refresh',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final initial = rig.sessions.selectProfile('profile_a');
      final old = rig.sources.single;
      rig.repository.secrets['profile_a'] = 'fake-repaired';
      await rig.hosts.load();
      expect(old.tasks.single.cancelled, isTrue);
      expect(old.closes, 1);
      old.respond([old.row('obsolete')]);
      await initial;
      expect(rig.sessions.sessions, isEmpty);
      expect(rig.sources, hasLength(1));
      final refresh = rig.sessions.refresh();
      rig.sources.last.respond([rig.sources.last.row('current')]);
      await refresh;
      expect(rig.sources, hasLength(2));
    },
  );

  test(
    'missing, unreadable and known-expired credentials never contact source',
    () async {
      await rig.save('a');
      rig.repository.secrets.clear();
      await rig.sessions.initialize();
      await rig.sessions.selectProfile('profile_a');
      expect(
        rig.sessions.failure,
        SessionCatalogFailure.authenticationRequired,
      );
      rig.repository.unreadable = 'profile_a';
      await rig.hosts.load();
      await rig.sessions.refresh();
      expect(rig.sources, isEmpty);
      rig.repository.unreadable = null;
      rig.repository.credentials['profile_a'] = EndpointCredential(
        kind: EndpointAuthKind.paired,
        secret: 'fake-token',
        expiresAt: DateTime.utc(2000),
      );
      await rig.hosts.load();
      await rig.sessions.refresh();
      expect(rig.sources, isEmpty);
      expect(
        rig.sessions.failure,
        SessionCatalogFailure.authenticationRequired,
      );
    },
  );

  test(
    'profile removal and storage error do not fabricate empty successful list',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final initial = rig.sessions.selectProfile('profile_a');
      rig.sources.single.respond([rig.sources.single.row('one')]);
      await initial;
      await rig.hosts.remove(profile('a'));
      expect(rig.sessions.selectedProfile, isNull);
      expect(rig.sessions.loaded, isFalse);
      rig.repository.failLoad = true;
      await rig.hosts.load();
      expect(rig.hosts.storageError, isTrue);
      await rig.sessions.selectProfile('profile_a');
      expect(rig.sources, hasLength(1));
    },
  );

  test(
    'disposed controller ignores late result and detaches borrowed hosts',
    () async {
      await rig.save('a');
      await rig.sessions.initialize();
      var notifications = 0;
      rig.sessions.addListener(() => notifications++);
      final initial = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      rig.sessions.dispose();
      final before = notifications;
      source.fail(SessionCatalogFailure.timeout);
      await initial;
      await rig.hosts.load();
      expect(notifications, before);
      expect(source.tasks.single.cancelled, isTrue);
      expect(source.closes, 1);
    },
  );

  group('the live catalog', () {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    Future<CatalogRig> loaded() async {
      final rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      await flush();
      final read = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      source.respond([source.row('1')]);
      await read;
      await settle();
      return rig;
    }

    test('a lifecycle change re-reads the list from the head', () async {
      final rig = await loaded();
      final source = rig.sources.single;
      expect(rig.sessions.sessions.map((s) => s.info.ref.nativeId), ['ses_1']);
      expect(source.tasks, hasLength(1));

      rig.feed.emit(const SessionCatalogChanged());
      await settle();
      expect(source.tasks, hasLength(2), reason: 'the change triggers one read');
      source.respond([source.row('1'), source.row('2')]);
      await settle();
      expect(
        rig.sessions.sessions.map((s) => s.info.ref.nativeId),
        ['ses_1', 'ses_2'],
      );
    });

    test('a change the server does not return invents no row', () async {
      final rig = await loaded();
      final source = rig.sources.single;
      rig.feed.emit(const SessionCatalogChanged());
      await settle();
      source.respond([source.row('1')]);
      await settle();
      expect(rig.sessions.sessions.map((s) => s.info.ref.nativeId), ['ses_1']);
    });

    test('a deleted row disappears after the re-read', () async {
      final rig = await loaded();
      final source = rig.sources.single;
      rig.feed.emit(const SessionCatalogChanged());
      await settle();
      source.respond([]);
      await settle();
      expect(rig.sessions.sessions, isEmpty);
    });

    test('the expanded row survives while the server returns it', () async {
      final rig = await loaded();
      final source = rig.sources.single;
      final ref = source.row('1').info.ref;
      rig.sessions.inspect(ref);
      expect(rig.sessions.selectedSession, isNotNull);
      rig.feed.emit(const SessionCatalogChanged());
      await settle();
      source.respond([source.row('1')]);
      await settle();
      expect(rig.sessions.selectedSession, isNotNull);
      rig.feed.emit(const SessionCatalogChanged());
      await settle();
      source.respond([]);
      await settle();
      expect(rig.sessions.selectedSession, isNull);
    });

    test('a quiet re-read never shows the loading or the stale state',
        () async {
      final rig = await loaded();
      final source = rig.sources.single;
      rig.feed.emit(const SessionCatalogChanged());
      await settle();
      expect(rig.sessions.loading, isFalse);
      expect(rig.sessions.stale, isFalse);
      expect(rig.sessions.quietRefreshing, isTrue);
      source.respond([source.row('1')]);
      await settle();
      expect(rig.sessions.quietRefreshing, isFalse);
    });

    test('a failed re-read keeps the rows and marks the list behind',
        () async {
      final rig = await loaded();
      final source = rig.sources.single;
      rig.feed.emit(const SessionCatalogChanged());
      await settle();
      source.fail(SessionCatalogFailure.connection);
      await settle();
      expect(rig.sessions.sessions.map((s) => s.info.ref.nativeId), ['ses_1']);
      expect(rig.sessions.behind, isTrue);
      expect(rig.sessions.failure, isNull, reason: 'the catalog failure is its own');
    });

    test('a burst of changes collapses into one read', () async {
      final rig = await loaded();
      final source = rig.sources.single;
      for (var i = 0; i < 5; i++) {
        rig.feed.emit(const SessionCatalogChanged());
      }
      await settle();
      expect(source.tasks, hasLength(2), reason: 'one read, not five');
    });

    test('the list is behind while the feed is not connected', () async {
      final rig = await loaded();
      expect(rig.sessions.behind, isFalse);
      rig.feed.emit(const SessionCatalogConnection(false));
      await settle();
      expect(rig.sessions.behind, isTrue);
    });

    test('disposing the controller releases the feed', () async {
      final rig = await loaded();
      final feed = rig.feed;
      expect(feed.closes, 0);
      rig.dispose();
      expect(feed.closes, 1);
    });

    test('without a feed the list stays pull-only', () async {
      final rig = CatalogRig(withFeed: false);
      await rig.save('a');
      await rig.sessions.initialize();
      await flush();
      final read = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      source.respond([source.row('1')]);
      await read;
      await settle();
      expect(rig.sessions.sessions, hasLength(1));
      expect(rig.sessions.behind, isFalse);
    });
  });
}
