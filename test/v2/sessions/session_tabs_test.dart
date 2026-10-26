import 'dart:async';

import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

final class _MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
  int writes = 0;
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? writeGate;

  @override
  Future<Object?> read(String key) async {
    if (failRead) throw StateError('unreadable');
    return values[key];
  }

  @override
  Future<void> write(String key, Object value) async {
    if (failWrite) throw StateError('unwritable');
    await writeGate?.future;
    writes++;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

SessionSummary _row(
  String host,
  String id, {
  String? harness,
  String? directory,
  String? title,
}) => SessionSummary(
  info: SessionInfo(
    ref: SessionRef(HostId(host), HarnessInstanceId(harness ?? host), id),
    lineage: const SessionLineage(),
    title: title ?? id,
    ownership: const OwnershipInfo.unknown(reason: 'not observed'),
    project: directory == null ? null : ProjectRef(HostId(host), directory),
  ),
);

/// A controller over [backend] whose clock advances one millisecond per read.
SessionTabsController _tabs(
  _MemoryBackend backend, {
  SessionsController? catalog,
}) {
  var clock = 1000;
  return SessionTabsController(
    store: SessionTabsStore(store: V2MetadataStore(backend: backend)),
    catalog: catalog,
    now: () => DateTime.fromMillisecondsSinceEpoch(clock++),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tabs come back after a restart, the same each time', () async {
    final backend = _MemoryBackend();
    final first = _tabs(backend);
    await first.open(_row('a', 'ses_1', directory: '/p', title: 'One'));
    await first.open(_row('a', 'ses_2', directory: '/p'));
    await first.open(_row('b', 'ses_3'));
    final saved = backend.values[SessionTabsStore.key];
    final writes = backend.writes;
    first.dispose();

    for (var i = 0; i < 2; i++) {
      final restored = _tabs(backend);
      // Concurrent callers share one read.
      await Future.wait([restored.initialize(), restored.initialize()]);
      expect(restored.unreadable, isFalse);
      expect(
        [for (final tab in restored.tabs) tab.ref.nativeId],
        ['ses_1', 'ses_2', 'ses_3'],
      );
      expect(restored.tabs.first.title, 'One');
      expect(restored.tabs.first.project, const ProjectRef(HostId('a'), '/p'));
      expect(restored.selectedFor(const HostId('a'))?.nativeId, 'ses_2');
      expect(restored.selectedFor(const HostId('b'))?.nativeId, 'ses_3');
      restored.dispose();
    }
    // Restoring never writes.
    expect(backend.writes, writes);
    expect(backend.values[SessionTabsStore.key], saved);
  });

  test('two servers with the same session id keep two tabs', () async {
    final backend = _MemoryBackend();
    final tabs = _tabs(backend);
    expect(await tabs.open(_row('a', 'ses_1')), SessionTabOpen.opened);
    expect(await tabs.open(_row('b', 'ses_1')), SessionTabOpen.opened);
    // The same server under another harness instance is another session.
    expect(
      await tabs.open(_row('a', 'ses_1', harness: 'other')),
      SessionTabOpen.opened,
    );
    expect(await tabs.open(_row('a', 'ses_1')), SessionTabOpen.focused);
    expect(tabs.tabs, hasLength(3));
    expect(tabs.visible(const HostId('a'), null), hasLength(2));
    expect(tabs.visible(const HostId('b'), null), hasLength(1));
    expect(
      tabs.selectedFor(const HostId('a')),
      const SessionRef(HostId('a'), HarnessInstanceId('a'), 'ses_1'),
    );
    tabs.dispose();

    final restored = _tabs(backend);
    await restored.initialize();
    expect(restored.tabs.map((tab) => tab.ref).toSet(), hasLength(3));
    restored.dispose();
  });

  test('each project shows its own tabs', () async {
    final tabs = _tabs(_MemoryBackend());
    await tabs.open(_row('a', 'ses_1', directory: '/one'));
    await tabs.open(_row('a', 'ses_2', directory: '/two'));
    await tabs.open(_row('a', 'ses_3', directory: '/one'));
    await tabs.open(_row('a', 'ses_4'));
    const one = ProjectRef(HostId('a'), '/one');
    expect(
      [
        for (final tab in tabs.visible(const HostId('a'), one))
          tab.ref.nativeId,
      ],
      ['ses_1', 'ses_3'],
    );
    expect(tabs.visible(const HostId('a'), null).single.ref.nativeId, 'ses_4');
    expect(tabs.visible(const HostId('b'), one), isEmpty);
    tabs.dispose();
  });

  test('closing a project closes only its tabs on that server', () async {
    final backend = _MemoryBackend();
    final tabs = _tabs(backend);
    await tabs.open(_row('a', 'ses_1', directory: '/one'));
    await tabs.open(_row('a', 'ses_2', directory: '/two'));
    await tabs.open(_row('b', 'ses_3', directory: '/one'));
    expect(await tabs.closeContext('a', '/one'), isTrue);
    expect([for (final tab in tabs.tabs) tab.ref.nativeId], ['ses_2', 'ses_3']);
    // A tab whose open is still being written closes with its project.
    final gate = backend.writeGate = Completer<void>();
    final opening = tabs.open(_row('a', 'ses_4', directory: '/two'));
    await Future<void>.delayed(Duration.zero);
    final closing = tabs.closeContext('a', '/two');
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await opening;
    backend.writeGate = null;
    expect(await closing, isTrue);
    expect([for (final tab in tabs.tabs) tab.ref.nativeId], ['ses_3']);
    // A project without tabs has nothing to close or write.
    final writes = backend.writes;
    expect(await tabs.closeContext('a', '/none'), isTrue);
    expect(backend.writes, writes);
    tabs.dispose();
  });

  test('a project close cannot vouch for unreadable tabs', () async {
    final backend = _MemoryBackend()..failRead = true;
    final tabs = _tabs(backend);
    await tabs.initialize();
    expect(tabs.unreadable, isTrue);
    expect(await tabs.closeContext('a', '/one'), isFalse);
    tabs.dispose();
  });

  test('closing the selected tab selects its neighbour', () async {
    final tabs = _tabs(_MemoryBackend());
    for (final id in ['ses_1', 'ses_2', 'ses_3']) {
      await tabs.open(_row('a', id, directory: '/p'));
    }
    await tabs.open(_row('a', 'ses_2', directory: '/p'));
    const host = HostId('a');
    // The next tab of the project first, then the previous one.
    expect((await tabs.close(tabs.selectedFor(host)!)).next?.nativeId, 'ses_3');
    expect(tabs.selectedFor(host)?.nativeId, 'ses_3');
    expect((await tabs.close(tabs.selectedFor(host)!)).next?.nativeId, 'ses_1');
    expect((await tabs.close(tabs.selectedFor(host)!)).next, isNull);
    expect(tabs.selectedFor(host), isNull);
    expect(tabs.tabs, isEmpty);
    tabs.dispose();
  });

  test('concurrent closes each return their own neighbour', () async {
    final tabs = _tabs(_MemoryBackend());
    await tabs.open(_row('a', 'a1'));
    await tabs.open(_row('a', 'a2'));
    await tabs.open(_row('b', 'b1'));
    await tabs.open(_row('b', 'b2'));
    final results = await Future.wait([
      tabs.close(tabs.selectedFor(const HostId('a'))!),
      tabs.close(tabs.selectedFor(const HostId('b'))!),
    ]);
    expect([for (final result in results) result.next?.nativeId], ['a1', 'b1']);
    tabs.dispose();
  });

  test('closing another tab keeps the selection', () async {
    final tabs = _tabs(_MemoryBackend());
    await tabs.open(_row('a', 'ses_1'));
    await tabs.open(_row('a', 'ses_2'));
    expect((await tabs.close(tabs.tabs.first.ref)).next, isNull);
    expect(tabs.selectedFor(const HostId('a'))?.nativeId, 'ses_2');
    expect(tabs.tabs.single.ref.nativeId, 'ses_2');
    tabs.dispose();
  });

  test('undo puts a closed tab back in its place, selected', () async {
    final tabs = _tabs(_MemoryBackend());
    for (final id in ['ses_1', 'ses_2', 'ses_3']) {
      await tabs.open(_row('a', id));
    }
    final closed = tabs.tabs[1];
    await tabs.close(closed.ref);
    expect(await tabs.reopen(closed, index: 1, select: true), isTrue);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_1', 'ses_2', 'ses_3'],
    );
    expect(tabs.selectedFor(const HostId('a')), closed.ref);
    // Already open again: nothing changes.
    expect(await tabs.reopen(closed, index: 0, select: true), isFalse);
    expect(tabs.tabs, hasLength(3));
  });

  test('a second close of the same tab removes nothing', () async {
    final tabs = _tabs(_MemoryBackend());
    await tabs.open(_row('a', 'ses_1'));
    await tabs.open(_row('a', 'ses_2'));
    final ref = tabs.selectedFor(const HostId('a'))!;
    final results = await Future.wait([tabs.close(ref), tabs.close(ref)]);
    expect([for (final result in results) result.removed], [true, false]);
    expect(results.first.next?.nativeId, 'ses_1');
    tabs.dispose();
  });

  test('undo of a background tab keeps the selection', () async {
    final tabs = _tabs(_MemoryBackend());
    await tabs.open(_row('a', 'ses_1'));
    await tabs.open(_row('a', 'ses_2'));
    final closed = tabs.tabs.first;
    await tabs.close(closed.ref);
    expect(await tabs.reopen(closed, index: 0, select: false), isTrue);
    expect(tabs.tabs.first.ref, closed.ref);
    expect(tabs.selectedFor(const HostId('a'))?.nativeId, 'ses_2');
    tabs.dispose();
  });

  test('only the first launch returns to the last used tab', () async {
    final tabs = _tabs(_MemoryBackend());
    await tabs.open(_row('a', 'ses_1'));
    await tabs.open(_row('b', 'ses_2'));
    await tabs.open(_row('a', 'ses_3'));
    expect(tabs.takeLaunchTab()?.nativeId, 'ses_3');
    expect(tabs.takeLaunchTab(), isNull);
    expect(_tabs(_MemoryBackend()).takeLaunchTab(), isNull);
  });

  test('the recent order puts the selected tab first', () async {
    final tabs = _tabs(_MemoryBackend());
    for (final id in ['ses_1', 'ses_2', 'ses_3']) {
      await tabs.open(_row('a', id));
    }
    await tabs.open(_row('a', 'ses_1'));
    await tabs.open(_row('b', 'ses_9'));
    expect(
      [for (final tab in tabs.recent(const HostId('a'))) tab.ref.nativeId],
      ['ses_1', 'ses_3', 'ses_2'],
    );
    tabs.dispose();
  });

  test('a full set refuses a new tab without dropping one', () async {
    final tabs = _tabs(_MemoryBackend());
    for (var i = 0; i < SessionTabsStore.maxTabs; i++) {
      await tabs.open(_row('a', 'ses_$i'));
    }
    expect(await tabs.open(_row('a', 'ses_new')), SessionTabOpen.full);
    expect(tabs.tabs, hasLength(SessionTabsStore.maxTabs));
    expect(await tabs.open(_row('a', 'ses_0')), SessionTabOpen.focused);
    tabs.dispose();
  });

  test('concurrent opens keep every tab', () async {
    final backend = _MemoryBackend();
    final tabs = _tabs(backend);
    await Future.wait([
      for (final id in ['ses_1', 'ses_2', 'ses_3']) tabs.open(_row('a', id)),
    ]);
    expect(tabs.tabs, hasLength(3));
    tabs.dispose();
    final restored = _tabs(backend);
    await restored.initialize();
    expect(restored.tabs, hasLength(3));
    restored.dispose();
  });

  test('an unreadable record is kept as it was', () async {
    for (final raw in <Object>[
      'not json',
      '{"version":2,"tabs":[],"selected":{}}',
      '{"version":1,"tabs":[{"ref":"bad"}],"selected":{}}',
      7,
    ]) {
      final backend = _MemoryBackend()..values[SessionTabsStore.key] = raw;
      final tabs = _tabs(backend);
      await tabs.initialize();
      expect(tabs.unreadable, isTrue, reason: '$raw');
      expect(tabs.tabs, isEmpty);
      expect(await tabs.open(_row('a', 'ses_1')), SessionTabOpen.unsaved);
      expect(backend.values[SessionTabsStore.key], raw);
      expect(backend.writes, 0);
      tabs.dispose();
    }
  });

  test('a failed read is never overwritten', () async {
    final backend = _MemoryBackend()..failRead = true;
    final tabs = _tabs(backend);
    await tabs.initialize();
    expect(tabs.unreadable, isTrue);
    backend.failRead = false;
    expect(await tabs.open(_row('a', 'ses_1')), SessionTabOpen.unsaved);
    expect(backend.writes, 0);
    tabs.dispose();
  });

  test('a failed write leaves the tabs as they were', () async {
    final backend = _MemoryBackend();
    final tabs = _tabs(backend);
    await tabs.open(_row('a', 'ses_1'));
    backend.failWrite = true;
    expect(await tabs.open(_row('a', 'ses_2')), SessionTabOpen.unsaved);
    expect(tabs.hasPersistenceError, isTrue);
    expect(tabs.tabs.single.ref.nativeId, 'ses_1');
    tabs.dispose();
  });

  test('duplicates and a foreign selection are ignored on read', () {
    const ref = SessionRef(HostId('a'), HarnessInstanceId('a'), 's');
    const other = SessionRef(HostId('b'), HarnessInstanceId('b'), 's');
    final encoded = SessionTabsStore.encode(
      SessionTabsState(
        tabs: const [
          SessionTab(ref: ref, project: null, title: 'x', lastOpenedAtMs: 1),
        ],
      ),
    );
    final doubled = encoded.replaceFirst(
      RegExp(r'\]\s*,\s*"selected"'),
      ',{"ref":${_json(ref.storageKey)},"project":null,"title":"y",'
      '"lastOpenedAtMs":2}],"selected"',
    );
    final withSelection = doubled.replaceFirst(
      '"selected":{}',
      '"selected":{"a":${_json(other.storageKey)}}',
    );
    final state = SessionTabsStore.decode(withSelection)!;
    expect(state.tabs.single.title, 'x');
    expect(state.selected, isEmpty);
  });

  group('restored tabs and the list', () {
    late CatalogRig rig;
    late _MemoryBackend backend;

    setUp(() async {
      rig = CatalogRig();
      backend = _MemoryBackend();
      await rig.save('a');
      await rig.save('b');
    });
    tearDown(() => rig.dispose());

    Future<CatalogSource> selectA() async {
      await rig.sessions.initialize();
      unawaited(rig.sessions.selectProfile('profile_a'));
      await pumpEventQueue();
      return rig.sources.last;
    }

    Future<SessionTabsController> restore(List<SessionSummary> rows) async {
      final seed = _tabs(backend);
      for (final row in rows) {
        await seed.open(row);
      }
      seed.dispose();
      final tabs = _tabs(backend, catalog: rig.sessions);
      await tabs.initialize();
      return tabs;
    }

    test(
      'queued old-binding not-found cannot remove a tab after URL editing',
      () async {
        final source = await selectA();
        final tabs = await restore([source.row('gone', title: 'Gone')]);
        addTearDown(tabs.dispose);
        source.respond(const []);
        await pumpEventQueue();
        final oldRead = source.reads.single.$2;
        final gate = backend.writeGate = Completer<void>();
        final opening = tabs.open(source.row('blocker'));
        await pumpEventQueue();
        oldRead.completion.completeError(
          const SessionCatalogException(SessionCatalogFailure.notFound),
        );
        await pumpEventQueue();
        final original = rig.hosts.profiles.firstWhere(
          (profile) => profile.id == 'profile_a',
        );
        expect(
          await rig.hosts.updateProfile(
            original,
            label: original.label,
            endpoint: original.endpoint.resolve('/other/'),
            expectedRevision: rig.hosts.catalogRevision,
          ),
          isTrue,
        );
        backend.writeGate = null;
        gate.complete();
        await opening;
        await pumpEventQueue();
        expect(tabs.tabs.any((tab) => tab.ref.nativeId == 'ses_gone'), isTrue);
        expect(tabs.takeRemoved(), isEmpty);
        final refreshing = rig.sessions.refresh();
        await pumpEventQueue();
        final currentSource = rig.sources.last;
        currentSource.respond(const []);
        await refreshing;
        await pumpEventQueue();
        final currentRead = currentSource.reads
            .firstWhere((read) => read.$1.nativeId == 'ses_gone')
            .$2;
        currentRead.completion.completeError(
          const SessionCatalogException(SessionCatalogFailure.notFound),
        );
        for (final (ref, task) in currentSource.reads) {
          if (ref.nativeId != 'ses_gone') {
            task.completion.complete(currentSource.row('blocker'));
          }
        }
        await pumpEventQueue();
        expect(tabs.tabs.any((tab) => tab.ref.nativeId == 'ses_gone'), isFalse);
        expect(tabs.takeRemoved(), ['Gone']);
      },
    );

    test('a tab reopened while its read is out is still dropped', () async {
      final source = await selectA();
      final tabs = await restore([source.row('gone', title: 'Gone')]);
      source.respond(const []);
      await pumpEventQueue();
      final (_, task) = source.reads.single;
      // Closed and put back while the server has not answered yet.
      final tab = tabs.tabs.single;
      await tabs.close(tab.ref);
      await tabs.reopen(tab, index: 0, select: true);
      rig.sessions.refresh().ignore();
      await pumpEventQueue();
      source.respond(const []);
      await pumpEventQueue();
      // The read in flight answers for the reopened tab; no second read.
      expect(source.reads, hasLength(1));
      task.completion.completeError(
        const SessionCatalogException(SessionCatalogFailure.notFound),
      );
      await pumpEventQueue();
      expect(tabs.tabs, isEmpty);
      expect(tabs.takeRemoved(), ['Gone']);
      tabs.dispose();
    });

    test(
      'a tab whose session is gone is dropped once, with a notice',
      () async {
        final source = await selectA();
        final tabs = await restore([
          source.row('one', title: 'One'),
          source.row('gone', title: 'Gone'),
          _row('profile_b', 'ses_gone'),
        ]);
        source.respond([source.row('one')]);
        await pumpEventQueue();
        // Absence from the list proves nothing: the session is read.
        final (ref, task) = source.reads.single;
        expect(ref.nativeId, 'ses_gone');
        expect(tabs.tabs, hasLength(3));
        task.completion.completeError(
          const SessionCatalogException(SessionCatalogFailure.notFound),
        );
        await pumpEventQueue();
        expect(
          [for (final tab in tabs.tabs) tab.ref.nativeId],
          ['ses_one', 'ses_gone'],
        );
        // The other server's tab with the same id stays.
        expect(tabs.tabs.last.ref.host, const HostId('profile_b'));
        expect(tabs.takeRemoved(), ['Gone']);
        expect(tabs.takeRemoved(), isEmpty);
        // The drop is saved, and a later list never reads it again.
        rig.sessions.refresh().ignore();
        await pumpEventQueue();
        source.respond([source.row('one')]);
        await pumpEventQueue();
        expect(source.reads, hasLength(1));
        tabs.dispose();
        final restored = _tabs(backend);
        await restored.initialize();
        expect(restored.tabs, hasLength(2));
        restored.dispose();
      },
    );

    test('a session that cannot be read keeps its tab', () async {
      final source = await selectA();
      final tabs = await restore([source.row('far')]);
      source.respond(const []);
      await pumpEventQueue();
      source.reads.single.$2.completion.completeError(
        const SessionCatalogException(
          SessionCatalogFailure.authenticationRequired,
        ),
      );
      await pumpEventQueue();
      expect(tabs.tabs, hasLength(1));
      expect(tabs.takeRemoved(), isEmpty);
      tabs.dispose();
    });

    test('a session that still exists keeps its tab', () async {
      final source = await selectA();
      final tabs = await restore([source.row('far')]);
      source.respond(const []);
      await pumpEventQueue();
      source.reads.single.$2.completion.complete(source.row('far'));
      await pumpEventQueue();
      expect(tabs.tabs, hasLength(1));
      tabs.dispose();
    });

    test('a dropped selected tab hands the selection on', () async {
      final source = await selectA();
      final tabs = await restore([source.row('one'), source.row('gone')]);
      expect(tabs.selectedFor(const HostId('profile_a'))?.nativeId, 'ses_gone');
      source.respond([source.row('one')]);
      await pumpEventQueue();
      source.reads.single.$2.completion.completeError(
        const SessionCatalogException(SessionCatalogFailure.notFound),
      );
      await pumpEventQueue();
      expect(tabs.selectedFor(const HostId('profile_a'))?.nativeId, 'ses_one');
      tabs.dispose();
    });

    test("a removed server's tabs are dropped", () async {
      final source = await selectA();
      final tabs = await restore([
        source.row('one'),
        _row('profile_gone', 'ses_x'),
      ]);
      source.respond([source.row('one')]);
      await pumpEventQueue();
      expect([for (final tab in tabs.tabs) tab.ref.host.value], ['profile_a']);
      // Pruning a server is not a missing session: no notice.
      expect(tabs.takeRemoved(), isEmpty);
      tabs.dispose();
    });

    test('a long title and a foreign project are not kept', () async {
      final tabs = _tabs(backend);
      final long = 'x' * (SessionTabsStore.maxTitleChars + 50);
      final row = SessionSummary(
        info: SessionInfo(
          ref: const SessionRef(HostId('a'), HarnessInstanceId('a'), 's'),
          lineage: const SessionLineage(),
          title: long,
          ownership: const OwnershipInfo.unknown(reason: 'not observed'),
          project: const ProjectRef(HostId('b'), '/p'),
        ),
      );
      await tabs.open(row);
      expect(tabs.tabs.single.title, hasLength(SessionTabsStore.maxTitleChars));
      expect(tabs.tabs.single.project, isNull);
      tabs.dispose();
    });

    test('removing the shown server drops its tabs', () async {
      final source = await selectA();
      final tabs = await restore([source.row('one')]);
      source.respond([source.row('one')]);
      await pumpEventQueue();
      final profile = rig.hosts.profiles.firstWhere((p) => p.id == 'profile_a');
      await rig.hosts.remove(profile);
      await pumpEventQueue();
      expect(tabs.tabs, isEmpty);
      tabs.dispose();
    });

    test('a listed tab takes its new title without being opened', () async {
      final source = await selectA();
      final tabs = await restore([source.row('one', title: 'Old')]);
      final opened = tabs.tabs.single.lastOpenedAtMs;
      source.respond([source.row('one', title: 'New', directory: '/p')]);
      await pumpEventQueue();
      expect(tabs.tabs.single.title, 'New');
      expect(tabs.tabs.single.project?.canonicalDirectory, '/p');
      expect(tabs.tabs.single.lastOpenedAtMs, opened);
      tabs.dispose();
    });

    test('a list that failed checks nothing', () async {
      final source = await selectA();
      final tabs = await restore([source.row('far')]);
      source.fail(SessionCatalogFailure.connection);
      await pumpEventQueue();
      expect(source.reads, isEmpty);
      expect(tabs.tabs, hasLength(1));
      tabs.dispose();
    });
  });
}

String _json(String value) => '"${value.replaceAll('"', r'\"')}"';
