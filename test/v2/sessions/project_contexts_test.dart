import 'dart:async';

import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/project_contexts_controller.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/features/sessions/workspace_draft_controller.dart';
import 'package:codewalk/platform/sessions/project_workspace_store.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';

/// Lets the reads, the store writes and the context passes settle.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<String> _ids(Iterable<SessionSummary> rows) => [
  for (final row in rows) row.info.ref.nativeId.substring(4),
];

final class _Rig {
  _Rig({
    bool unreadable = false,
    bool withDrafts = false,
    bool withTabs = false,
  }) {
    backend.failRead = unreadable;
    if (withTabs) {
      tabs = SessionTabsController(
        store: SessionTabsStore(store: V2MetadataStore(backend: backend)),
        catalog: catalog.sessions,
      );
    }
    workspace = WorkspaceStore(store: V2MetadataStore(backend: backend));
    if (withDrafts) {
      health = EndpointHealthController(hosts: catalog.hosts);
      drafts = WorkspaceDraftController(
        catalog: catalog.sessions,
        health: health!,
        store: WorkspaceDraftStore(
          payloads: PreferencesPayloadStore(V2MetadataStore(backend: backend)),
          index: V2MetadataStore(backend: backend),
          delay: Duration.zero,
        ),
      );
    }
    contexts = ProjectContextsController(
      catalog: catalog.sessions,
      store: ProjectWorkspaceStore(store: V2MetadataStore(backend: backend)),
      workspace: workspace,
      drafts: drafts,
      tabs: tabs,
    );
  }

  final catalog = CatalogRig(withFeed: false);
  final backend = FakeMetadataBackend();
  late final WorkspaceStore workspace;
  EndpointHealthController? health;
  WorkspaceDraftController? drafts;
  SessionTabsController? tabs;
  late ProjectContextsController contexts;

  CatalogSource get source => catalog.sources.single;

  /// Selects the server and answers its whole-server list with [rows].
  Future<void> open(
    List<SessionSummary> Function(CatalogSource source) rows,
  ) async {
    await catalog.save('a');
    await catalog.sessions.initialize();
    await contexts.initialize();
    final read = catalog.sessions.selectProfile('profile_a');
    source.respond(rows(source));
    await read;
    await settle();
  }

  void dispose() {
    contexts.dispose();
    tabs?.dispose();
    drafts?.dispose();
    health?.dispose();
    catalog.dispose();
    workspace.dispose();
  }
}

void main() {
  group('directory scope', () {
    late CatalogRig rig;
    setUp(() => rig = CatalogRig(withFeed: false));
    tearDown(() => rig.dispose());

    test(
      'a context shows its rows and keeps the other open ones warm',
      () async {
        await rig.save('a');
        await rig.sessions.initialize();
        final read = rig.sessions.selectProfile('profile_a');
        final source = rig.sources.single;
        source.respond([
          source.row('p1', directory: '/p'),
          source.row('q1', directory: '/q'),
        ]);
        await read;
        rig.sessions
          ..setOpenDirectories(['/p', '/q'])
          ..setDirectory('/p');
        await settle();
        expect(rig.sessions.directory, '/p');
        expect(_ids(rig.sessions.sessions), ['p1']);
        expect(rig.sessions.contextComplete('/p'), isTrue);
        // The context the list does not show is read once for its head rows.
        expect(
          source.contextQueries.map((q) => q.project?.canonicalDirectory),
          ['/p', '/q'],
        );
        expect(_ids(rig.sessions.contextRows('/q')!), ['q1']);
        expect(rig.sessions.contextComplete('/q'), isTrue);
        final q1 = source.row('q1').info.ref;
        expect(rig.sessions.findSession(q1)?.info.ref, q1);
        // The list follows the context in its project choice.
        expect(rig.sessions.chosenProject?.project?.canonicalDirectory, '/p');

        // A switch shows the warm rows at once while their head is read
        // again, and keeps the rows it leaves.
        source.autoContexts = false;
        rig.sessions.setDirectory('/q');
        expect(rig.sessions.loaded, isTrue);
        expect(rig.sessions.stale, isTrue);
        expect(_ids(rig.sessions.sessions), ['q1']);
        expect(_ids(rig.sessions.contextRows('/p')!), ['p1']);
        expect(source.queries.last.project?.canonicalDirectory, '/q');
        source.respond([
          source.row('q2', directory: '/q'),
          source.row('q1', directory: '/q'),
        ]);
        await settle();
        expect(rig.sessions.stale, isFalse);
        expect(_ids(rig.sessions.sessions), ['q2', 'q1']);

        // A context that closes forgets its rows.
        rig.sessions.setOpenDirectories(['/q']);
        expect(rig.sessions.contextRows('/p'), isNull);
        expect(rig.sessions.findSession(source.row('p1').info.ref), isNull);
      },
    );

    test('an explicit refresh reads the warm contexts again', () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final read = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      source.respond([
        source.row('p1', directory: '/p'),
        source.row('q1', directory: '/q'),
      ]);
      await read;
      rig.sessions
        ..setOpenDirectories(['/p', '/q'])
        ..setDirectory('/p');
      await settle();
      final before = source.contextQueries
          .where((q) => q.project?.canonicalDirectory == '/q')
          .length;
      // Switching back and forth reads only what changed.
      expect(before, 1);
      await rig.sessions.refresh();
      await settle();
      expect(
        source.contextQueries
            .where((q) => q.project?.canonicalDirectory == '/q')
            .length,
        2,
      );
    });

    test('a row of another directory fails the context read', () async {
      await rig.save('a');
      await rig.sessions.initialize();
      final read = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single..autoContexts = false;
      source.respond([source.row('p1', directory: '/p')]);
      await read;
      rig.sessions.setDirectory('/p');
      source.respond([source.row('x', directory: '/elsewhere')]);
      await settle();
      expect(rig.sessions.failure, SessionCatalogFailure.incompatibleResponse);
      expect(rig.sessions.contextComplete('/p'), isFalse);
    });
  });

  group('project contexts', () {
    late _Rig rig;
    tearDown(() => rig.dispose());

    test(
      'a server without contexts starts in its most recent project',
      () async {
        rig = _Rig();
        await rig.open(
          (source) => [
            source.row('root', directory: '/'),
            source.row('p1', directory: '/p'),
            source.row('q1', directory: '/q'),
          ],
        );
        expect(rig.contexts.available, isTrue);
        expect(rig.contexts.open, ['/p']);
        expect(rig.contexts.active, '/p');
        expect(rig.catalog.sessions.directory, '/p');
        expect(_ids(rig.catalog.sessions.sessions), ['p1']);
      },
    );

    test('the saved filter never chooses where a server starts', () async {
      rig = _Rig();
      final saved = ProjectWorkspaceStore(
        store: V2MetadataStore(backend: rig.backend),
      );
      await saved.initialize();
      await saved.setListPreferences(
        const SessionListPreferences(filter: SessionActionFilter.hidden),
      );
      saved.dispose();
      await rig.open(
        (source) => [
          source.row('q1', directory: '/q'),
          source.row('p1', directory: '/p'),
        ],
      );
      expect(rig.catalog.sessions.filter, SessionActionFilter.hidden);
      expect(rig.contexts.active, '/q');
      expect(rig.source.locationReads, isEmpty);
    });

    test('the project the user left starts even without its rows', () async {
      rig = _Rig();
      await rig.workspace.initialize();
      await rig.workspace.setLastProject(
        'profile_a',
        const ProjectRef(HostId('profile_a'), '/left').storageKey,
      );
      await rig.open((source) => [source.row('p1', directory: '/p')]);
      expect(rig.contexts.active, '/left');
    });

    test('a project opened while the start waits wins over it', () async {
      rig = _Rig();
      await rig.open((_) => []);
      expect(await rig.contexts.openContext('/mine'), isTrue);
      rig.source.locationReads.single.$2.completion.complete(
        const ProjectRef(HostId('profile_a'), '/home/u'),
      );
      await settle();
      expect(rig.contexts.active, '/mine');
      expect(rig.contexts.open, ['/mine']);
    });

    test('no start begins while an explicit open is being saved', () async {
      rig = _Rig();
      await rig.open((_) => []);
      final start = rig.source.locationReads.single.$2;
      rig.backend
        ..blockedKey = ProjectWorkspaceStore.key
        ..entered = Completer<void>()
        ..release = Completer<void>();
      final opening = rig.contexts.openContext('/mine');
      await rig.backend.entered!.future;
      // A catalog change while the write is held starts nothing.
      final refresh = rig.catalog.sessions.refresh();
      rig.source.respond([]);
      await refresh;
      await settle();
      expect(rig.source.locationReads, hasLength(1));
      start.completion.complete(
        const ProjectRef(HostId('profile_a'), '/home/u'),
      );
      await settle();
      rig.backend.release!.complete();
      expect(await opening, isTrue);
      await settle();
      expect(rig.contexts.active, '/mine');
      expect(rig.contexts.open, ['/mine']);
    });

    test('a start that cannot be saved is not retried in a loop', () async {
      rig = _Rig();
      rig.backend.failWrite = ProjectWorkspaceStore.key;
      await rig.open((source) => [source.row('p1', directory: '/p')]);
      int writes() => rig.backend.writes
          .where((key) => key == ProjectWorkspaceStore.key)
          .length;
      final attempted = writes();
      expect(attempted, greaterThan(0));
      expect(rig.contexts.notice, ProjectContextNotice.unavailable);
      final refresh = rig.catalog.sessions.refresh();
      rig.source.respond([rig.source.row('p1', directory: '/p')]);
      await refresh;
      await settle();
      expect(writes(), attempted);
      expect(rig.contexts.active, isNull);
    });

    test(
      'contexts that turn unreadable leave the list on the server',
      () async {
        rig = _Rig();
        await rig.open((source) => [source.row('p1', directory: '/p')]);
        expect(rig.catalog.sessions.directory, '/p');
        rig.backend
          ..failWrite = ProjectWorkspaceStore.key
          ..failRead = true;
        expect(await rig.contexts.openContext('/q'), isFalse);
        await settle();
        expect(rig.contexts.unreadable, isTrue);
        expect(rig.catalog.sessions.directory, isNull);
      },
    );

    test('a close whose tabs cannot be closed says so', () async {
      rig = _Rig(withTabs: true);
      await rig.open(
        (source) => [
          source.row('p1', directory: '/p'),
          source.row('q1', directory: '/q'),
        ],
      );
      expect(await rig.contexts.openContext('/q'), isTrue);
      await rig.tabs!.open(rig.source.row('q1', directory: '/q'));
      rig.backend.failWrite = SessionTabsStore.key;
      expect(await rig.contexts.close('/q'), isFalse);
      expect(rig.contexts.notice, ProjectContextNotice.unavailable);
      expect(rig.contexts.open, ['/p']);
    });

    test('overlapping list changes keep each other', () async {
      rig = _Rig();
      await rig.open((source) => [source.row('p1', directory: '/p')]);
      final filtering = rig.contexts.setFilter(SessionActionFilter.all);
      final sorting = rig.contexts.setSort(SessionListSort.title);
      expect(await filtering, isTrue);
      expect(await sorting, isTrue);
      expect(rig.contexts.preferences.filter, SessionActionFilter.all);
      expect(rig.contexts.preferences.sort, SessionListSort.title);
    });

    test('a query still being typed is saved when the drawer closes', () async {
      rig = _Rig();
      await rig.open((source) => [source.row('p1', directory: '/p')]);
      rig.contexts.setQuery('half typed');
      rig.contexts.dispose();
      await settle();
      final reopened = ProjectWorkspaceStore(
        store: V2MetadataStore(backend: rig.backend),
      );
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.listPreferences.query, 'half typed');
      // The rig's own teardown must not dispose the controller twice.
      rig.contexts = ProjectContextsController(
        catalog: rig.catalog.sessions,
        store: ProjectWorkspaceStore(
          store: V2MetadataStore(backend: rig.backend),
        ),
      );
    });

    test(
      'a query save queued behind another write survives the close',
      () async {
        rig = _Rig();
        await rig.open((source) => [source.row('p1', directory: '/p')]);
        rig.backend
          ..blockedKey = ProjectWorkspaceStore.key
          ..entered = Completer<void>()
          ..release = Completer<void>();
        final filtering = rig.contexts.setFilter(SessionActionFilter.all);
        await rig.backend.entered!.future;
        rig.contexts.setQuery('queued');
        // The debounce fires; its save waits behind the held filter write.
        await Future<void>.delayed(
          ProjectContextsController.queryWriteDelay +
              const Duration(milliseconds: 50),
        );
        rig.contexts.dispose();
        rig.backend.release!.complete();
        await filtering;
        await settle();
        final reopened = ProjectWorkspaceStore(
          store: V2MetadataStore(backend: rig.backend),
        );
        addTearDown(reopened.dispose);
        await reopened.initialize();
        expect(reopened.listPreferences.query, 'queued');
        expect(reopened.listPreferences.filter, SessionActionFilter.all);
        rig.contexts = ProjectContextsController(
          catalog: rig.catalog.sessions,
          store: ProjectWorkspaceStore(
            store: V2MetadataStore(backend: rig.backend),
          ),
        );
      },
    );

    test(
      'a refused query never lets the store close before queued writes',
      () async {
        rig = _Rig();
        await rig.open((source) => [source.row('p1', directory: '/p')]);
        rig.backend
          ..blockedKey = ProjectWorkspaceStore.key
          ..entered = Completer<void>()
          ..release = Completer<void>();
        final filtering = rig.contexts.setFilter(SessionActionFilter.all);
        await rig.backend.entered!.future;
        final sorting = rig.contexts.setSort(SessionListSort.title);
        // Over the store's bound: refused at once, outside its queue.
        rig.contexts.setQuery('x' * 300);
        await Future<void>.delayed(
          ProjectContextsController.queryWriteDelay +
              const Duration(milliseconds: 50),
        );
        rig.contexts.dispose();
        rig.backend.release!.complete();
        await filtering;
        await sorting;
        await settle();
        final reopened = ProjectWorkspaceStore(
          store: V2MetadataStore(backend: rig.backend),
        );
        addTearDown(reopened.dispose);
        await reopened.initialize();
        expect(reopened.listPreferences.filter, SessionActionFilter.all);
        expect(reopened.listPreferences.sort, SessionListSort.title);
        rig.contexts = ProjectContextsController(
          catalog: rig.catalog.sessions,
          store: ProjectWorkspaceStore(
            store: V2MetadataStore(backend: rig.backend),
          ),
        );
      },
    );

    test('the project the user left wins over the most recent', () async {
      rig = _Rig();
      await rig.workspace.initialize();
      await rig.workspace.setLastProject(
        'profile_a',
        const ProjectRef(HostId('profile_a'), '/q').storageKey,
      );
      await rig.open(
        (source) => [
          source.row('p1', directory: '/p'),
          source.row('q1', directory: '/q'),
        ],
      );
      expect(rig.contexts.active, '/q');
    });

    test(
      'an empty server starts in its default location, once on failure',
      () async {
        rig = _Rig();
        await rig.open((_) => []);
        final (asked, location) = rig.source.locationReads.single;
        expect(asked, isNull);
        location.completion.complete(
          const ProjectRef(HostId('profile_a'), '/home/u'),
        );
        await settle();
        expect(rig.contexts.active, '/home/u');

        final failing = _Rig();
        addTearDown(failing.dispose);
        await failing.open((_) => []);
        failing.source.locationReads.single.$2.completion.completeError(
          const SessionCatalogException(SessionCatalogFailure.unavailable),
        );
        await settle();
        expect(failing.contexts.notice, ProjectContextNotice.unavailable);
        final refresh = failing.catalog.sessions.refresh();
        failing.source.respond([]);
        await refresh;
        await settle();
        expect(failing.source.locationReads, hasLength(1));
        expect(failing.contexts.active, isNull);
      },
    );

    test('contexts open, switch and close; the last one stays open', () async {
      rig = _Rig();
      await rig.open(
        (source) => [
          source.row('p1', directory: '/p'),
          source.row('q1', directory: '/q'),
        ],
      );
      // Rapid repeated taps do not overlap.
      final first = rig.contexts.openContext('/q');
      expect(await rig.contexts.openContext('/r'), isFalse);
      expect(await first, isTrue);
      await settle();
      expect(rig.contexts.open, ['/p', '/q']);
      expect(rig.catalog.sessions.directory, '/q');
      expect(_ids(rig.catalog.sessions.sessions), ['q1']);

      expect(await rig.contexts.activate('/p'), isTrue);
      await settle();
      expect(rig.catalog.sessions.directory, '/p');
      expect(_ids(rig.catalog.sessions.contextRows('/q')!), ['q1']);

      expect(await rig.contexts.close('/q'), isTrue);
      await settle();
      expect(rig.contexts.open, ['/p']);
      expect(rig.contexts.closed, ['/q']);
      expect(rig.catalog.sessions.contextRows('/q'), isNull);

      expect(await rig.contexts.close('/p'), isFalse);
      expect(rig.contexts.notice, ProjectContextNotice.soleContext);
      rig.contexts.clearNotice();
      expect(rig.contexts.notice, ProjectContextNotice.none);
    });

    test(
      'pins stay with their context; a viewed session opens its context',
      () async {
        rig = _Rig();
        await rig.open(
          (source) => [
            source.row('p1', directory: '/p'),
            source.row('z1', directory: '/z'),
            source.row('bare'),
          ],
        );
        final p1 = rig.source.row('p1', directory: '/p');
        expect(await rig.contexts.setPinned(p1, pinned: true), isTrue);
        expect(rig.contexts.isPinned(p1), isTrue);
        expect(
          await rig.contexts.setPinned(rig.source.row('bare'), pinned: true),
          isFalse,
        );

        final z1 = rig.source.row('z1', directory: '/z');
        rig.contexts.recordView(z1);
        await settle();
        expect(rig.contexts.active, '/z');
        expect(rig.contexts.viewOf('/z'), z1.info.ref);
        expect(rig.contexts.isPinned(p1), isTrue);
        rig.contexts.recordHome();
        expect(rig.contexts.viewOf('/z'), isNull);
      },
    );

    test(
      'unreadable contexts are never written; the list reads it all',
      () async {
        rig = _Rig(unreadable: true);
        await rig.catalog.save('a');
        await rig.catalog.sessions.initialize();
        final read = rig.catalog.sessions.selectProfile('profile_a');
        rig.source.respond([rig.source.row('p1', directory: '/p')]);
        await read;
        await rig.contexts.initialize();
        await settle();
        expect(rig.contexts.unreadable, isTrue);
        expect(rig.contexts.available, isFalse);
        expect(await rig.contexts.openContext('/p'), isFalse);
        expect(rig.catalog.sessions.directory, isNull);
        expect(_ids(rig.catalog.sessions.sessions), ['p1']);
        expect(rig.backend.writes, isNot(contains(ProjectWorkspaceStore.key)));
      },
    );

    test('an empty project opens its draft once', () async {
      rig = _Rig(withDrafts: true);
      await rig.open((_) => []);
      rig.source.locationReads.single.$2.completion.complete(
        const ProjectRef(HostId('profile_a'), '/home/u'),
      );
      await settle();
      final drafts = rig.drafts!;
      expect(drafts.isDraftActive, isTrue);
      expect(drafts.currentKey?.canonicalDirectory, '/home/u');
      drafts.exitDraft();
      final refresh = rig.catalog.sessions.refresh();
      await settle();
      await refresh;
      await settle();
      expect(drafts.isDraftActive, isFalse);
    });
  });
}
