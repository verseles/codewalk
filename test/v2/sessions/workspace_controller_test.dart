import 'dart:async';
import 'dart:convert';

import 'package:codewalk/app/workspace_controller.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/sessions/workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

final class _MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
  Completer<void>? writeGate;

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object value) async {
    await writeGate?.future;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// A workspace over [rig] whose state lives in [backend].
WorkspaceController _workspace(
  CatalogRig rig,
  _MemoryBackend backend, {
  SessionTabsController? tabs,
}) {
  final workspace = WorkspaceController(
    catalog: rig.sessions,
    store: WorkspaceStore(store: V2MetadataStore(backend: backend)),
    tabs: tabs,
  );
  addTearDown(workspace.dispose);
  return workspace;
}

Map<String, Object?> _saved(_MemoryBackend backend) =>
    jsonDecode(backend.values[WorkspaceStore.key]! as String)
        as Map<String, Object?>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (active, defaultProfile, expected) in [
    ('profile_b', 'profile_c', 'profile_b'),
    ('profile_gone', 'profile_c', 'profile_c'),
    (null, 'profile_gone', 'profile_a'),
  ]) {
    test(
      'restore active=$active default=$defaultProfile selects $expected',
      () async {
        final rig = CatalogRig();
        addTearDown(rig.dispose);
        for (final id in ['a', 'b', 'c']) {
          await rig.save(id);
        }
        final backend = _MemoryBackend()
          ..values[WorkspaceStore.key] = jsonEncode({
            'v': 1,
            'active': active,
            'default': defaultProfile,
          });
        final workspace = _workspace(rig, backend);
        await workspace.initialize();
        workspace.restoreServer();
        await pumpEventQueue();
        expect(rig.sessions.selectedProfile?.id, expected);
        expect(rig.sources, hasLength(1));
      },
    );
  }

  test(
    'default set and clear are single-flight and never select another server',
    () async {
      final rig = CatalogRig();
      addTearDown(rig.dispose);
      for (final id in ['a', 'b', 'c']) {
        await rig.save(id);
      }
      final backend = _MemoryBackend();
      final workspace = _workspace(rig, backend);
      await workspace.initialize();
      workspace.restoreServer();
      await pumpEventQueue();
      final gate = backend.writeGate = Completer<void>();
      final choosing = workspace.setDefaultProfile('profile_b');
      await pumpEventQueue();
      expect(workspace.savingDefault, isTrue);
      expect(await workspace.setDefaultProfile('profile_c'), isFalse);
      backend.writeGate = null;
      gate.complete();
      expect(await choosing, isTrue);
      expect(workspace.defaultProfile, 'profile_b');
      expect(rig.sessions.selectedProfile?.id, 'profile_a');
      expect(rig.sources, hasLength(1));
      expect(await workspace.setDefaultProfile(null), isTrue);
      expect(workspace.defaultProfile, isNull);
      expect(rig.sessions.selectedProfile?.id, 'profile_a');
    },
  );

  test(
    'removing the default clears it while keeping the active server',
    () async {
      final rig = CatalogRig();
      addTearDown(rig.dispose);
      await rig.save('a');
      await rig.save('b');
      final backend = _MemoryBackend();
      final workspace = _workspace(rig, backend);
      await workspace.initialize();
      workspace.restoreServer();
      await pumpEventQueue();
      expect(await workspace.setDefaultProfile('profile_b'), isTrue);
      await rig.hosts.remove(
        rig.hosts.profiles.firstWhere((profile) => profile.id == 'profile_b'),
      );
      await pumpEventQueue();
      expect(workspace.defaultProfile, isNull);
      expect(rig.sessions.selectedProfile?.id, 'profile_a');
      expect(_saved(backend)['active'], 'profile_a');
      expect(_saved(backend)['default'], isNull);
    },
  );

  test('a single saved server opens without being chosen', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    final backend = _MemoryBackend();
    final workspace = _workspace(rig, backend);
    await workspace.initialize();
    workspace.restoreServer();
    // Nothing is read before the saved servers and their credentials.
    expect(rig.sources, isEmpty);
    await pumpEventQueue();
    expect(rig.sessions.selectedProfile?.id, 'profile_a');
    expect(rig.sources, hasLength(1));
    expect(_saved(backend)['active'], 'profile_a');
    // Asking again keeps the same list and its source.
    workspace.restoreServer();
    unawaited(rig.sessions.selectProfile('profile_a'));
    await pumpEventQueue();
    expect(rig.sources, hasLength(1));
  });

  test('no saved server selects nothing and reads nothing', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    final backend = _MemoryBackend();
    final workspace = _workspace(rig, backend);
    await workspace.initialize();
    workspace.restoreServer();
    await pumpEventQueue();
    expect(rig.sessions.selectedProfile, isNull);
    expect(rig.sources, isEmpty);
    expect(backend.values, isEmpty);
  });

  test('the server used last comes back among several', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    await rig.save('b');
    final backend = _MemoryBackend()
      ..values[WorkspaceStore.key] = jsonEncode({
        'v': 1,
        'active': 'profile_b',
      });
    final workspace = _workspace(rig, backend);
    await workspace.initialize();
    workspace.restoreServer();
    await pumpEventQueue();
    expect(rig.sessions.selectedProfile?.id, 'profile_b');
    expect(rig.sources, hasLength(1));
  });

  test('a saved server that was removed falls back to the first', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    final backend = _MemoryBackend()
      ..values[WorkspaceStore.key] = jsonEncode({
        'v': 1,
        'active': 'profile_gone',
        'projects': {'profile_gone': 'project'},
      });
    final workspace = _workspace(rig, backend);
    await workspace.initialize();
    workspace.restoreServer();
    await pumpEventQueue();
    expect(rig.sessions.selectedProfile?.id, 'profile_a');
    expect(_saved(backend), {'v': 1, 'active': 'profile_a', 'projects': {}});
  });

  test('the server of the launch tab wins', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    await rig.save('b');
    final tabsBackend = _MemoryBackend();
    final first = SessionTabsController(
      store: SessionTabsStore(store: V2MetadataStore(backend: tabsBackend)),
    );
    await first.initialize();
    await first.open(CatalogSource(profile('b')).row('x'));
    first.dispose();
    final tabs = SessionTabsController(
      store: SessionTabsStore(store: V2MetadataStore(backend: tabsBackend)),
    );
    addTearDown(tabs.dispose);
    final backend = _MemoryBackend()
      ..values[WorkspaceStore.key] = jsonEncode({
        'v': 1,
        'active': 'profile_a',
        'default': 'profile_a',
      });
    final workspace = _workspace(rig, backend, tabs: tabs);
    await workspace.initialize();
    workspace.restoreServer();
    await pumpEventQueue();
    // It waits for the tabs before it chooses.
    expect(rig.sessions.selectedProfile, isNull);
    await tabs.initialize();
    await pumpEventQueue();
    expect(rig.sessions.selectedProfile?.id, 'profile_b');
    // The launch tab is not spent by the choice.
    expect(tabs.launchTab, isNotNull);
  });

  test('the server in use is replaced when it is removed', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    await rig.save('b');
    final backend = _MemoryBackend();
    final workspace = _workspace(rig, backend);
    await workspace.initialize();
    workspace.restoreServer();
    await pumpEventQueue();
    unawaited(rig.sessions.selectProfile('profile_b'));
    await pumpEventQueue();
    expect(_saved(backend)['active'], 'profile_b');
    await rig.hosts.remove(rig.hosts.profiles.last);
    await pumpEventQueue();
    expect(rig.sessions.selectedProfile?.id, 'profile_a');
    expect(_saved(backend)['active'], 'profile_a');
  });

  test('the last real project comes back once, and a choice is kept', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    final rows = CatalogSource(profile('a'));
    final alpha = rows.row('one', directory: '/work/alpha').info.project!;
    final beta = rows.row('two', directory: '/work/beta').info.project!;
    final backend = _MemoryBackend()
      ..values[WorkspaceStore.key] = jsonEncode({
        'v': 1,
        'active': 'profile_a',
        'projects': {'profile_a': beta.storageKey},
      });
    final workspace = _workspace(rig, backend);
    await workspace.initialize();
    workspace.restoreServer();
    await pumpEventQueue();
    final source = rig.sources.single;
    source.respond([
      source.row('one', directory: '/work/alpha'),
      source.row('two', directory: '/work/beta'),
    ]);
    await pumpEventQueue();
    expect(rig.sessions.selectedProject?.project, beta);
    expect(rig.sessions.projectChosen, isTrue);
    rig.sessions.selectProject(alpha);
    await pumpEventQueue();
    expect(
      (_saved(backend)['projects']! as Map)['profile_a'],
      alpha.storageKey,
    );
  });

  test(
    'a missing chosen project does not persist the shown fallback',
    () async {
      final rig = CatalogRig();
      addTearDown(rig.dispose);
      await rig.save('a');
      final backend = _MemoryBackend();
      final workspace = _workspace(rig, backend);
      await workspace.initialize();
      workspace.restoreServer();
      await pumpEventQueue();
      final source = rig.sources.single;
      final alpha = source.row('one', directory: '/work/alpha');
      final beta = source.row('two', directory: '/work/beta');
      source.respond([alpha, beta]);
      await pumpEventQueue();
      rig.sessions.selectProject(beta.info.project);
      await pumpEventQueue();
      final refresh = rig.sessions.refresh();
      await pumpEventQueue();
      source.respond([alpha]);
      await refresh;
      await pumpEventQueue();
      expect(rig.sessions.selectedProject?.project, alpha.info.project);
      expect(
        (_saved(backend)['projects']! as Map)['profile_a'],
        beta.info.project!.storageKey,
      );
    },
  );

  test('the placeholder root is never restored nor saved', () async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    final rows = CatalogSource(profile('a'));
    final root = rows.row('one', directory: '/').info.project!;
    final alpha = rows.row('two', directory: '/work/alpha').info.project!;
    final backend = _MemoryBackend()
      ..values[WorkspaceStore.key] = jsonEncode({
        'v': 1,
        'active': 'profile_a',
        'projects': {'profile_a': root.storageKey},
      });
    final workspace = _workspace(rig, backend);
    await workspace.initialize();
    workspace.restoreServer();
    await pumpEventQueue();
    final source = rig.sources.single;
    source.respond([
      source.row('one', directory: '/'),
      source.row('two', directory: '/work/alpha'),
    ]);
    await pumpEventQueue();
    expect(rig.sessions.projectChosen, isFalse);
    // A real project is saved; choosing the root afterwards keeps it.
    rig.sessions.selectProject(alpha);
    await pumpEventQueue();
    rig.sessions.selectProject(root);
    await pumpEventQueue();
    expect(
      (_saved(backend)['projects']! as Map)['profile_a'],
      alpha.storageKey,
    );
    expect(WorkspaceController.isRealProject(root), isFalse);
  });
}
