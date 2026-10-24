import 'dart:async';
import 'dart:convert';

import 'package:codewalk/platform/sessions/workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MemoryBackend implements MetadataBackend {
  final values = <String, Object>{};
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
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

Future<WorkspaceStore> _open(_MemoryBackend backend) async {
  final store = WorkspaceStore(store: V2MetadataStore(backend: backend));
  addTearDown(store.dispose);
  await store.initialize();
  return store;
}

void main() {
  test('the server and its last project come back', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    expect(store.unreadable, isFalse);
    expect(store.activeProfile, isNull);
    expect(await store.setActiveProfile('profile_a'), isTrue);
    expect(await store.setLastProject('profile_a', 'project_alpha'), isTrue);
    expect(store.activeProfile, 'profile_a');
    expect(store.lastProject('profile_a'), 'project_alpha');
    // They survive a restart.
    final reloaded = await _open(backend);
    expect(reloaded.activeProfile, 'profile_a');
    expect(reloaded.lastProject('profile_a'), 'project_alpha');
    expect(reloaded.lastProject('profile_b'), isNull);
  });

  for (final (name, raw) in [
    ('not JSON', 'not json'),
    ('another version', jsonEncode({'v': 2, 'active': 'profile_a'})),
    ('a wrong active', jsonEncode({'v': 1, 'active': 3})),
    ('an empty active', jsonEncode({'v': 1, 'active': ''})),
    (
      'a wrong project',
      jsonEncode({
        'v': 1,
        'projects': {'profile_a': 3},
      }),
    ),
    ('a list', jsonEncode(['profile_a'])),
  ]) {
    test('a state with $name is never overwritten', () async {
      final backend = _MemoryBackend()..values[WorkspaceStore.key] = raw;
      final store = await _open(backend);
      expect(store.unreadable, isTrue);
      expect(store.activeProfile, isNull);
      expect(await store.setActiveProfile('profile_b'), isFalse);
      expect(await store.setLastProject('profile_b', 'project_beta'), isFalse);
      expect(backend.values[WorkspaceStore.key], raw);
    });
  }

  test('a failed read leaves the state unreadable', () async {
    final backend = _MemoryBackend()..failRead = true;
    final store = await _open(backend);
    expect(store.loaded, isTrue);
    expect(store.unreadable, isTrue);
    expect(await store.setActiveProfile('profile_a'), isFalse);
  });

  test('a failed write keeps the state as it was', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    await store.setActiveProfile('profile_a');
    backend.failWrite = true;
    expect(await store.setActiveProfile('profile_b'), isFalse);
    expect(await store.setLastProject('profile_a', 'project_alpha'), isFalse);
    expect(store.activeProfile, 'profile_a');
    expect(store.lastProject('profile_a'), isNull);
    expect(store.hasPersistenceError, isTrue);
    backend.failWrite = false;
    expect(await store.setActiveProfile('profile_b'), isTrue);
    expect(store.hasPersistenceError, isFalse);
  });

  test('the oldest server leaves the projects first', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    for (var i = 0; i < WorkspaceStore.maxProjects; i++) {
      expect(await store.setLastProject('profile_$i', 'project_$i'), isTrue);
    }
    // A server used again moves to the newest end.
    expect(await store.setLastProject('profile_0', 'project_again'), isTrue);
    expect(await store.setLastProject('profile_new', 'project_new'), isTrue);
    expect(store.lastProject('profile_0'), 'project_again');
    expect(store.lastProject('profile_1'), isNull);
    expect(store.lastProject('profile_new'), 'project_new');
    final reloaded = await _open(backend);
    expect(reloaded.unreadable, isFalse);
    expect(reloaded.lastProject('profile_new'), 'project_new');
  });

  test('a removed server is forgotten', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    await store.setActiveProfile('profile_a');
    await store.setLastProject('profile_a', 'project_alpha');
    await store.setLastProject('profile_b', 'project_beta');
    expect(await store.forget('profile_a'), isTrue);
    expect(store.activeProfile, isNull);
    expect(store.lastProject('profile_a'), isNull);
    expect(store.lastProject('profile_b'), 'project_beta');
    expect(await store.forget('profile_a'), isFalse);
  });

  test('rapid A-B-A server choices persist the final A', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    await store.setActiveProfile('profile_a');
    final gate = backend.writeGate = Completer<void>();
    final b = store.setActiveProfile('profile_b');
    await pumpEventQueue();
    final a = store.setActiveProfile('profile_a');
    gate.complete();
    expect(await b, isTrue);
    expect(await a, isTrue);
    expect((await _open(backend)).activeProfile, 'profile_a');
  });

  test('rapid A-B-A project choices persist the final A', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    await store.setLastProject('profile_a', 'project_alpha');
    final gate = backend.writeGate = Completer<void>();
    final b = store.setLastProject('profile_a', 'project_beta');
    await pumpEventQueue();
    final a = store.setLastProject('profile_a', 'project_alpha');
    gate.complete();
    expect(await b, isTrue);
    expect(await a, isTrue);
    expect((await _open(backend)).lastProject('profile_a'), 'project_alpha');
  });

  test('forget follows queued server and project writes', () async {
    final backend = _MemoryBackend();
    final store = await _open(backend);
    final gate = backend.writeGate = Completer<void>();
    final active = store.setActiveProfile('profile_a');
    final project = store.setLastProject('profile_a', 'project_alpha');
    final forgotten = store.forget('profile_a');
    gate.complete();
    expect(await active, isTrue);
    expect(await project, isTrue);
    expect(await forgotten, isTrue);
    final restored = await _open(backend);
    expect(restored.activeProfile, isNull);
    expect(restored.lastProject('profile_a'), isNull);
  });

  test('a queued write finishes safely after disposal', () async {
    final backend = _MemoryBackend();
    final store = WorkspaceStore(store: V2MetadataStore(backend: backend));
    await store.initialize();
    final gate = backend.writeGate = Completer<void>();
    final write = store.setActiveProfile('profile_a');
    await pumpEventQueue();
    store.dispose();
    gate.complete();
    expect(await write, isTrue);
    expect((await _open(backend)).activeProfile, 'profile_a');
  });
}
