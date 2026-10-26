import 'dart:convert';

import 'package:codewalk/platform/sessions/project_workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
  bool failRead = false;
  bool throwAfterWrite = false;
  bool unreadableAfterWrite = false;
  int writes = 0;

  @override
  Future<Object?> read(String key) async {
    if (failRead) throw StateError('unreadable');
    return values[key];
  }

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
    if (key != ProjectWorkspaceStore.key) return;
    writes++;
    if (throwAfterWrite) {
      throwAfterWrite = false;
      if (unreadableAfterWrite) failRead = true;
      throw StateError('committed without acknowledgement');
    }
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

Future<ProjectWorkspaceStore> _open(_MemoryBackend backend) async {
  final store = ProjectWorkspaceStore(store: V2MetadataStore(backend: backend));
  addTearDown(store.dispose);
  await store.initialize();
  return store;
}

const _a = 'profile_a';

void main() {
  test(
    'open contexts, the active one and the history survive restart',
    () async {
      final backend = _MemoryBackend();
      final store = await _open(backend);
      expect(await store.open(_a, '/work/one'), ProjectStoreResult.saved);
      expect(await store.open(_a, '/work/two'), ProjectStoreResult.saved);
      expect(
        await store.open(_a, '/work/three', activate: false),
        ProjectStoreResult.saved,
      );
      expect(await store.open(_a, '/work/two'), ProjectStoreResult.unchanged);
      // Closing the active context hands over to the first remaining one.
      expect(await store.close(_a, '/work/two'), ProjectStoreResult.saved);
      expect(await store.close(_a, '/work/three'), ProjectStoreResult.saved);
      final reloaded = (await _open(backend)).workspace(_a);
      expect(reloaded.open, ['/work/one']);
      expect(reloaded.active, '/work/one');
      expect(reloaded.closed, ['/work/three', '/work/two']);
      expect(store.workspace('profile_b'), same(ProjectWorkspace.empty));
    },
  );

  test('the sole open context stays open; a reopen leaves history', () async {
    final store = await _open(_MemoryBackend());
    await store.open(_a, '/work/one');
    expect(await store.close(_a, '/work/one'), ProjectStoreResult.soleContext);
    expect(await store.close(_a, '/work/none'), ProjectStoreResult.notOpen);
    await store.open(_a, '/work/two');
    await store.close(_a, '/work/one');
    expect(store.workspace(_a).closed, ['/work/one']);
    await store.open(_a, '/work/one');
    expect(store.workspace(_a).closed, isEmpty);
    expect(store.workspace(_a).active, '/work/one');
    await store.close(_a, '/work/two');
    expect(await store.forgetClosed(_a, '/work/two'), ProjectStoreResult.saved);
    expect(store.workspace(_a).closed, isEmpty);
    expect(
      await store.forgetClosed(_a, '/work/two'),
      ProjectStoreResult.unchanged,
    );
  });

  test('pins belong to one open context and leave with its close', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    await store.open(_a, '/work/one');
    await store.open(_a, '/work/two');
    expect(
      await store.setPinned(_a, '/work/one', 'ses-key', pinned: true),
      ProjectStoreResult.saved,
    );
    expect(
      await store.setPinned(_a, '/work/none', 'ses-key', pinned: true),
      ProjectStoreResult.notOpen,
    );
    expect(store.workspace(_a).isPinned('/work/one', 'ses-key'), isTrue);
    expect(store.workspace(_a).isPinned('/work/two', 'ses-key'), isFalse);
    final writes = backend.writes;
    await store.close(_a, '/work/one');
    // One write closes the context and drops its pins.
    expect(backend.writes, writes + 1);
    await store.open(_a, '/work/one');
    expect(store.workspace(_a).isPinned('/work/one', 'ses-key'), isFalse);
    expect((await _open(backend)).workspace(_a).pins, isEmpty);
  });

  test('a bound refuses the change instead of dropping a choice', () async {
    final store = await _open(_MemoryBackend());
    for (var i = 0; i < ProjectWorkspaceStore.maxOpen; i++) {
      expect(await store.open(_a, '/work/$i'), ProjectStoreResult.saved);
    }
    expect(await store.open(_a, '/work/extra'), ProjectStoreResult.capacity);
    expect(store.workspace(_a).open, hasLength(ProjectWorkspaceStore.maxOpen));
    for (var i = 0; i < ProjectWorkspaceStore.maxPins; i++) {
      await store.setPinned(_a, '/work/${i % 4}', 'ses-$i', pinned: true);
    }
    expect(
      await store.setPinned(_a, '/work/5', 'ses-extra', pinned: true),
      ProjectStoreResult.capacity,
    );
    expect(
      await store.setListPreferences(SessionListPreferences(query: 'q' * 257)),
      ProjectStoreResult.capacity,
    );
  });

  test('list preferences persist and unknown choices fall back', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    const prefs = SessionListPreferences(
      query: 'fix',
      filter: SessionActionFilter.hidden,
      sort: SessionListSort.title,
    );
    expect(await store.setListPreferences(prefs), ProjectStoreResult.saved);
    expect(await store.setListPreferences(prefs), ProjectStoreResult.unchanged);
    expect((await _open(backend)).listPreferences, prefs);
    backend.values[ProjectWorkspaceStore.key] = jsonEncode({
      'v': 1,
      'list': {'query': 'x', 'filter': 'future', 'sort': 'future'},
    });
    expect(
      (await _open(backend)).listPreferences,
      const SessionListPreferences(query: 'x'),
    );
  });

  test('an unreadable state is never overwritten', () async {
    for (final raw in [
      '{',
      jsonEncode({'v': 2}),
      jsonEncode({
        'v': 1,
        'servers': {
          _a: {
            'open': ['/a'],
            'active': '/b',
          },
        },
      }),
      jsonEncode({
        'v': 1,
        'servers': {
          _a: {
            'open': ['/a'],
            'active': '/a',
            'pins': {
              '/closed': ['k'],
            },
          },
        },
      }),
    ]) {
      final backend = _MemoryBackend()..values[ProjectWorkspaceStore.key] = raw;
      final store = await _open(backend);
      expect(store.unreadable, isTrue, reason: raw);
      expect(await store.open(_a, '/c'), ProjectStoreResult.unavailable);
      expect(backend.values[ProjectWorkspaceStore.key], raw);
    }
    final failing = _MemoryBackend()..failRead = true;
    expect((await _open(failing)).unreadable, isTrue);
  });

  test('unknown fields of the record and of a server are kept', () async {
    final backend = _MemoryBackend()
      ..values[ProjectWorkspaceStore.key] = jsonEncode({
        'v': 1,
        'future': {'kept': true},
        'servers': {
          _a: {
            'open': ['/a'],
            'active': '/a',
            'icon': 'kept',
          },
        },
      });
    final store = await _open(backend);
    await store.open(_a, '/b');
    final saved =
        jsonDecode(backend.values[ProjectWorkspaceStore.key]! as String)
            as Map<String, Object?>;
    expect(saved['future'], {'kept': true});
    expect((saved['servers']! as Map)[_a]['icon'], 'kept');
    expect(await store.forget(_a), ProjectStoreResult.saved);
    expect(store.workspace(_a), same(ProjectWorkspace.empty));
  });

  test('a lost acknowledgment is settled by reading the state back', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    await store.open(_a, '/a');
    backend.throwAfterWrite = true;
    expect(await store.open(_a, '/b'), ProjectStoreResult.saved);
    expect(store.hasPersistenceError, isFalse);
    backend
      ..throwAfterWrite = true
      ..unreadableAfterWrite = true;
    expect(await store.open(_a, '/c'), ProjectStoreResult.failed);
    expect(store.unreadable, isTrue);
    expect(store.hasPersistenceError, isTrue);
    expect(await store.open(_a, '/d'), ProjectStoreResult.unavailable);
  });
}
