import 'package:codewalk/features/sessions/project_contexts_controller.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/platform/sessions/project_workspace_store.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/sessions/workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/session_activity.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';

/// Lets the reads, the store writes and the reconciliations settle.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final _noon = DateTime.utc(2026, 10, 12, 12);

/// [row] as last updated [hours] before noon.
SessionSummary _at(SessionSummary row, double hours) => SessionSummary(
  info: row.info,
  updatedAt: _noon.subtract(Duration(minutes: (hours * 60).round())),
);

final class _Rig {
  _Rig({MetadataBackend? tabsBackend}) {
    tabs = SessionTabsController(
      store: SessionTabsStore(
        store: V2MetadataStore(backend: tabsBackend ?? backend),
      ),
      catalog: catalog.sessions,
      workspace: projects,
      now: () => clock,
    );
    contexts = ProjectContextsController(
      catalog: catalog.sessions,
      store: projects,
      workspace: workspace,
      tabs: tabs,
    );
  }

  DateTime clock = _noon;
  final catalog = CatalogRig(withFeed: false);
  final backend = FakeMetadataBackend();
  late final projects = ProjectWorkspaceStore(
    store: V2MetadataStore(backend: backend),
  );
  late final workspace = WorkspaceStore(
    store: V2MetadataStore(backend: backend),
  );
  late SessionTabsController tabs;
  late final ProjectContextsController contexts;

  CatalogSource get source => catalog.sources.single;

  List<String> get ids => [
    for (final tab in tabs.tabs) tab.ref.nativeId.substring(4),
  ];

  /// Selects the server, whose activity is known and idle, and answers its
  /// whole-server list with [rows]; the most recent project opens.
  Future<void> open(
    List<SessionSummary> Function(CatalogSource source) rows,
  ) async {
    await catalog.save('a');
    await catalog.sessions.initialize();
    await tabs.initialize();
    await contexts.initialize();
    final read = catalog.sessions.selectProfile('profile_a');
    source.activityAnswer = const SessionActivity(running: {}, waiting: {});
    source.respond(rows(source));
    await read;
    await settle();
  }

  /// Reads the open projects again, each answered with its rows of [rows].
  Future<void> reread(List<SessionSummary> rows) async {
    source.autoContexts = false;
    final read = catalog.sessions.refresh();
    await settle();
    for (final (i, task) in source.tasks.indexed) {
      if (task.completion.isCompleted) continue;
      final directory = source.queries[i].project?.canonicalDirectory;
      task.completion.complete(
        Page(
          items: [
            for (final row in rows)
              if (row.info.project?.canonicalDirectory == directory) row,
          ],
        ),
      );
    }
    await read;
    await settle();
  }

  void dispose() {
    contexts.dispose();
    tabs.dispose();
    catalog.dispose();
    workspace.dispose();
  }
}

/// Fails the first three tab writes, then allows progress so a regression
/// cannot trap the test in an unbounded microtask retry loop.
final class _FailingTabsBackend implements MetadataBackend {
  final delegate = FakeMetadataBackend();
  bool fail = false;
  int attempts = 0;

  @override
  Future<Object?> read(String key) => delegate.read(key);

  @override
  Future<void> write(String key, Object value) async {
    if (key == SessionTabsStore.key && fail && ++attempts <= 3) {
      throw StateError('tab write failed');
    }
    await delegate.write(key, value);
  }

  @override
  Future<void> remove(String key) => delegate.remove(key);
}

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());
  tearDown(() => rig.dispose());

  test('the recent root sessions of the open project become tabs', () async {
    await rig.open(
      (source) => [
        _at(source.row('recent', directory: '/p'), 1),
        _at(source.row('child', directory: '/p', parent: 'recent'), 0.5),
        _at(source.row('old', directory: '/p'), 5),
      ],
    );
    expect(rig.catalog.sessions.directory, '/p');
    expect(rig.ids, ['recent']);
    // Nothing was opened, so no tab is selected and nothing navigated.
    expect(rig.tabs.selectedFor(const HostId('profile_a')), isNull);
  });

  test('a failed automatic tab write waits for external input', () async {
    rig.dispose();
    final backend = _FailingTabsBackend();
    rig = _Rig(tabsBackend: backend);
    await rig.open((source) => [_at(source.row('s', directory: '/p'), 1)]);
    backend.fail = true;
    rig.clock = _noon.add(const Duration(hours: 4));
    // One input after the catalog settles triggers expiry. Subsequent
    // failure notifications must not cause additional write attempts.
    rig.tabs.requestFallback('profile_a', '/not-loaded');
    await settle();
    expect(backend.attempts, 1);
    expect(rig.tabs.hasPersistenceError, isTrue);
    expect(rig.ids, ['s']);
  });

  test('a cached project cannot resurrect an authoritative deletion', () async {
    await rig.open((source) => [_at(source.row('p', directory: '/p'), 1)]);
    final q = _at(rig.source.row('q', directory: '/q'), 1.5);
    await rig.tabs.open(q);
    await rig.reread([_at(rig.source.row('p', directory: '/p'), 1)]);
    final ref = q.info.ref;
    final read = rig.source.reads.firstWhere((entry) => entry.$1 == ref).$2;
    // The direct read began before this context had a snapshot. A later
    // snapshot must not override its subsequent authoritative not-found.
    expect(await rig.contexts.openContext('/q'), isTrue);
    await settle();
    for (final (i, task) in rig.source.tasks.indexed) {
      if (!task.completion.isCompleted &&
          rig.source.queries[i].project?.canonicalDirectory == '/q') {
        task.completion.complete(Page(items: [q]));
      }
    }
    await settle();
    expect(await rig.contexts.activate('/p'), isTrue);
    await settle();
    expect(rig.catalog.sessions.contextRows('/q'), isNotEmpty);
    read.completion.completeError(
      const SessionCatalogException(SessionCatalogFailure.notFound),
    );
    await settle();
    expect(rig.tabs.deleted(ref), isTrue);
    expect(rig.ids, isNot(contains('q')));
    // Another input must not admit the stale snapshot either.
    rig.tabs.requestFallback('profile_a', '/q');
    await settle();
    expect(rig.ids, isNot(contains('q')));
  });

  test('known context rows do not need a full session read', () async {
    await rig.open(
      (source) => [
        _at(source.row('p', directory: '/p'), 1),
        _at(source.row('q', directory: '/q'), 1.5),
      ],
    );
    expect(await rig.contexts.openContext('/q'), isTrue);
    await settle();
    expect(await rig.contexts.activate('/p'), isTrue);
    await settle();
    expect(rig.ids, containsAll(['p', 'q']));
    expect(rig.source.reads, isEmpty);
  });

  test('a tab leaves once its window ends', () async {
    await rig.open(
      (source) => [_at(source.row('recent', directory: '/p'), 2.5)],
    );
    expect(rig.ids, ['recent']);
    rig.clock = _noon.add(const Duration(minutes: 31));
    await rig.reread([_at(rig.source.row('recent', directory: '/p'), 2.5)]);
    expect(rig.ids, isEmpty);
  });

  test('a project opened with only old sessions gets its latest', () async {
    await rig.open(
      (source) => [
        _at(source.row('p1', directory: '/p'), 1),
        _at(source.row('q_old', directory: '/q'), 10),
        _at(source.row('q_latest', directory: '/q'), 8),
      ],
    );
    expect(rig.ids, ['p1']);
    expect(await rig.contexts.openContext('/q'), isTrue);
    await settle();
    expect(rig.ids, ['p1', 'q_latest']);
    // It stays its window, as if opened when the project opened.
    await rig.reread([
      _at(rig.source.row('p1', directory: '/p'), 1),
      _at(rig.source.row('q_old', directory: '/q'), 10),
      _at(rig.source.row('q_latest', directory: '/q'), 8),
    ]);
    expect(rig.ids, ['p1', 'q_latest']);
  });

  test('a closed tab stays closed until its session is updated', () async {
    await rig.open((source) => [_at(source.row('s', directory: '/p'), 1)]);
    final tab = rig.tabs.tabs.single;
    final (:removed, next: _, :unpinned) = await rig.tabs.close(tab.ref);
    expect(removed, isTrue);
    expect(unpinned, isFalse);
    await rig.reread([_at(rig.source.row('s', directory: '/p'), 1)]);
    expect(rig.ids, isEmpty);
    await rig.reread([_at(rig.source.row('s', directory: '/p'), 0.5)]);
    expect(rig.ids, ['s']);
  });

  test('opening a closed session ends its close', () async {
    await rig.open((source) => [_at(source.row('s', directory: '/p'), 1)]);
    final row = rig.catalog.sessions.loadedSessions.single;
    await rig.tabs.close(row.info.ref);
    expect(await rig.tabs.open(row), SessionTabOpen.opened);
    await settle();
    expect(rig.tabs.tabs.single.lastOpenedAtMs, _noon.millisecondsSinceEpoch);
    rig.tabs.dispose();
    final restored = SessionTabsStore(
      store: V2MetadataStore(backend: rig.backend),
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.state.suppressed, isEmpty);
    expect(restored.state.tabs.single.updatedAtMs, isNotNull);
    rig.tabs = SessionTabsController(
      store: SessionTabsStore(store: V2MetadataStore(backend: rig.backend)),
    );
  });

  /// Opens a project holding a recent session and an old pinned one.
  Future<SessionSummary> pinnedOld() async {
    await rig.open(
      (source) => [
        _at(source.row('r', directory: '/p'), 1),
        _at(source.row('s', directory: '/p'), 30),
      ],
    );
    expect(rig.ids, ['r']);
    final row = rig.catalog.sessions.loadedSessions.last;
    expect(await rig.contexts.setPinned(row, pinned: true), isTrue);
    await settle();
    // A pin keeps its tab whatever its age.
    expect(rig.ids, ['r', 's']);
    return row;
  }

  test('closing a pinned tab unpins it; undo pins it back first', () async {
    final row = await pinnedOld();
    final tab = rig.tabs.tabs.last;
    final (:removed, next: _, :unpinned) = await rig.tabs.close(tab.ref);
    expect((removed, unpinned), (true, true));
    expect(rig.contexts.isPinned(row), isFalse);
    await settle();
    expect(rig.ids, ['r']);
    expect(
      await rig.tabs.reopen(tab, index: 1, select: false, pin: true),
      isTrue,
    );
    await settle();
    expect(rig.contexts.isPinned(row), isTrue);
    expect(rig.ids, ['r', 's']);
  });

  for (final unreadable in [false, true]) {
    test(
      'close refuses an unknown pin catalog, unreadable=$unreadable',
      () async {
        final row = await pinnedOld();
        final ref = row.info.ref;
        rig.tabs.dispose();
        final projects = ProjectWorkspaceStore(
          store: V2MetadataStore(
            backend: unreadable
                ? (FakeMetadataBackend()..failRead = true)
                : rig.backend,
          ),
        );
        addTearDown(projects.dispose);
        if (unreadable) await projects.initialize();
        rig.tabs = SessionTabsController(
          store: SessionTabsStore(store: V2MetadataStore(backend: rig.backend)),
          workspace: projects,
        );
        await rig.tabs.initialize();
        expect((await rig.tabs.close(ref)).removed, isFalse);
        expect(rig.tabs.tabs.any((tab) => tab.ref == ref), isTrue);
        expect(rig.contexts.isPinned(row), isTrue);
      },
    );
  }

  test('a close that cannot be saved puts the pin back', () async {
    final row = await pinnedOld();
    rig.backend.failWrite = SessionTabsStore.key;
    final (:removed, next: _, unpinned: _) = await rig.tabs.close(
      rig.tabs.tabs.last.ref,
    );
    expect(removed, isFalse);
    expect(rig.contexts.isPinned(row), isTrue);
    rig.backend.failWrite = null;
    await settle();
    expect(rig.ids, ['r', 's']);
  });

  test('a concurrent second close leaves the pin alone', () async {
    final row = await pinnedOld();
    final ref = rig.tabs.tabs.last.ref;
    final first = rig.tabs.close(ref);
    final second = await rig.tabs.close(ref);
    expect(second.removed, isFalse);
    expect((await first).removed, isTrue);
    await settle();
    expect(rig.contexts.isPinned(row), isFalse);
    expect(rig.ids, ['r']);
  });

  test('closing a project forgets the tabs closed in it', () async {
    await rig.open(
      (source) => [
        _at(source.row('p1', directory: '/p'), 1),
        _at(source.row('q1', directory: '/q'), 1.5),
      ],
    );
    expect(await rig.contexts.openContext('/q'), isTrue);
    await settle();
    final q1 = rig.tabs.tabs.firstWhere((tab) => tab.ref.nativeId == 'ses_q1');
    await rig.tabs.close(q1.ref);
    expect(rig.tabs.tabs.map((tab) => tab.ref), isNot(contains(q1.ref)));
    expect(await rig.contexts.close('/q'), isTrue);
    await settle();
    expect(await rig.contexts.openContext('/q'), isTrue);
    await settle();
    // Opened again, the project starts afresh: its recent session is back.
    expect(rig.ids, containsAll(['p1', 'q1']));
  });

  test('a tab closed here is not a session the server lost', () async {
    await rig.open((source) => [_at(source.row('s', directory: '/p'), 1)]);
    final ref = rig.tabs.tabs.single.ref;
    await rig.tabs.close(ref);
    expect(rig.tabs.deleted(ref), isFalse);
  });
}
