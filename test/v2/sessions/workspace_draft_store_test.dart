import 'dart:async';
import 'dart:convert';

import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

WorkspaceDraftKey _key(String dir, {String host = 'a'}) => WorkspaceDraftKey(
  profileId: host,
  harnessId: host,
  canonicalDirectory: dir,
);

final class _ReadGatePayloads implements PayloadStore {
  _ReadGatePayloads(this.delegate);
  final PayloadStore delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool holdRead = false;

  @override
  Future<String?> read(String key) async {
    if (holdRead) {
      holdRead = false;
      entered.complete();
      await release.future;
    }
    return delegate.read(key);
  }

  @override
  Future<bool> contains(String key) => delegate.contains(key);
  @override
  Future<PayloadWriteResult> write(String key, String value) =>
      delegate.write(key, value);
  @override
  Future<void> remove(String key) => delegate.remove(key);
}

final class _Device {
  final backend = FakeMetadataBackend();
  late final metadata = V2MetadataStore(backend: backend);

  WorkspaceDraftStore store({
    Duration delay = const Duration(milliseconds: 10),
  }) => WorkspaceDraftStore(
    payloads: PreferencesPayloadStore(metadata),
    index: metadata,
    delay: delay,
  );

  Object? raw(WorkspaceDraftKey key) =>
      backend.values[WorkspaceDraftStore.keyFor(key)];
}

void main() {
  group('WorkspaceDraftKey', () {
    test('roundtrips storageKey', () {
      final key = _key('/work/project-a');
      final serialized = key.storageKey;
      final parsed = WorkspaceDraftKey.fromStorageKey(serialized);
      expect(parsed, equals(key));
      expect(parsed.profileId, 'a');
      expect(parsed.harnessId, 'a');
      expect(parsed.canonicalDirectory, '/work/project-a');
    });

    test('equality and hash code follow properties', () {
      final k1 = _key('/work/a');
      final k2 = _key('/work/a');
      final k3 = _key('/work/b');
      expect(k1, equals(k2));
      expect(k1.hashCode, equals(k2.hashCode));
      expect(k1, isNot(equals(k3)));
    });
  });

  group('WorkspaceDraftStore', () {
    test(
      'cold attempt stays uncertain across repeated reads and contexts',
      () async {
        final device = _Device();
        final key = _key('/work/alpha');
        final first = device.store();
        expect(
          await first.setAttemptFence(key, commandId: 'cold', text: 'Keep me'),
          isTrue,
        );
        expect((await first.read(key))?.status, WorkspaceDraftStatus.creating);
        expect((await first.read(key))?.status, WorkspaceDraftStatus.creating);
        final restarted = device.store();
        expect(
          (await restarted.read(key))?.status,
          WorkspaceDraftStatus.uncertain,
        );
        await restarted.read(_key('/work/beta'));
        expect(
          (await restarted.read(key))?.status,
          WorkspaceDraftStatus.uncertain,
        );
        expect((await restarted.read(key))?.fenceCommandId, 'cold');
      },
    );

    test(
      'a flush queued during a slow read keeps the latest edit visible',
      () async {
        final device = _Device();
        final key = _key('/work/alpha');
        final payloads = _ReadGatePayloads(
          PreferencesPayloadStore(device.metadata),
        );
        final store = WorkspaceDraftStore(
          payloads: payloads,
          index: device.metadata,
          delay: const Duration(days: 1),
        );
        addTearDown(() async {
          if (!payloads.release.isCompleted) payloads.release.complete();
          await store.flush();
        });
        store.save(key, 'Saved text');
        await store.flush();
        store.save(key, 'Latest text');
        payloads.holdRead = true;
        final reading = store.read(key);
        await payloads.entered.future;
        final flushing = store.flush();
        payloads.release.complete();

        expect((await reading)?.text, 'Latest text');
        await flushing;
        expect((await device.store().read(key))?.text, 'Latest text');
      },
    );

    test(
      'read includes pending edits before the debounce writes them',
      () async {
        final device = _Device();
        final key = _key('/work/alpha');
        final store = device.store(delay: const Duration(days: 1));
        addTearDown(store.flush);

        store.save(key, 'Latest unsaved text');
        expect((await store.read(key))?.text, 'Latest unsaved text');
        expect(device.raw(key), isNull);
      },
    );

    test('failed writes keep pending edits and the attempt fence', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final store = device.store(delay: const Duration(days: 1));
      addTearDown(() async {
        device.backend.failWrite = null;
        await store.flush();
      });
      expect(
        await store.setAttemptFence(key, commandId: 'first', text: 'Original'),
        isTrue,
      );
      final persisted = device.raw(key);
      store.save(key, 'Later edit');
      device.backend.failWrite = WorkspaceDraftStore.keyFor(key);
      await store.flush();

      final entry = await store.read(key);
      expect(entry?.text, 'Later edit');
      expect(entry?.status, WorkspaceDraftStatus.creating);
      expect(entry?.fenceCommandId, 'first');
      expect(device.raw(key), persisted);
    });

    test('a draft survives a new store on the same device', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final first = device.store();

      first.save(key, 'First draft message');
      await first.flush();

      final second = device.store();
      final entry = await second.read(key);
      expect(entry, isNotNull);
      expect(entry!.text, 'First draft message');
      expect(entry.status, WorkspaceDraftStatus.ready);
    });

    test('project contexts are isolated', () async {
      final device = _Device();
      final keyA = _key('/work/project-a');
      final keyB = _key('/work/project-b');
      final store = device.store();

      store.save(keyA, 'Draft in A');
      store.save(keyB, 'Draft in B');
      await store.flush();

      final entryA = await store.read(keyA);
      final entryB = await store.read(keyB);
      expect(entryA?.text, 'Draft in A');
      expect(entryB?.text, 'Draft in B');
    });

    test('empty text removes ready draft', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final store = device.store();

      store.save(key, 'Hello');
      await store.flush();
      expect(await store.read(key), isNotNull);

      store.save(key, '');
      await store.flush();
      expect(await store.read(key), isNull);
    });

    test('setAttemptFence persists status creating and commandId', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final store = device.store();

      final ok = await store.setAttemptFence(
        key,
        commandId: 'cmd-123',
        text: 'Prompt to send',
      );
      expect(ok, isTrue);

      final entry = await store.read(key);
      expect(entry, isNotNull);
      expect(entry!.status, WorkspaceDraftStatus.creating);
      expect(entry.fenceCommandId, 'cmd-123');
      expect(entry.text, 'Prompt to send');
    });

    test('restart with fence settles creating to uncertain', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final first = device.store();

      await first.setAttemptFence(
        key,
        commandId: 'cmd-123',
        text: 'In flight prompt',
      );

      // Simulates app process kill and restart with fresh store instance:
      final second = device.store();
      final entry = await second.read(key);
      expect(entry, isNotNull);
      expect(entry!.status, WorkspaceDraftStatus.uncertain);
      expect(entry.text, 'In flight prompt');
      expect(entry.fenceCommandId, 'cmd-123');
    });

    test('fence write failure returns false and blocks', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final store = device.store();

      // Put backend in failing mode for this key
      device.backend.failWrite = WorkspaceDraftStore.keyFor(key);

      final ok = await store.setAttemptFence(
        key,
        commandId: 'cmd-fail',
        text: 'Should not create',
      );
      expect(ok, isFalse);

      device.backend.failWrite = null;
      expect(await store.read(key), isNull);
    });

    test('updateStatus updates status and created session', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final store = device.store();

      await store.setAttemptFence(key, commandId: 'cmd-1', text: 'Test');

      const createdRef = SessionRef(
        HostId('a'),
        HarnessInstanceId('a'),
        'session-xyz',
      );

      final updated = await store.updateStatus(
        key,
        WorkspaceDraftStatus.confirming,
        createdSession: createdRef,
      );
      expect(updated, isTrue);

      final entry = await store.read(key);
      expect(entry?.status, WorkspaceDraftStatus.confirming);
      expect(entry?.createdSession, createdRef);

      await store.updateStatus(key, WorkspaceDraftStatus.bound);
      final boundEntry = await store.read(key);
      expect(boundEntry?.status, WorkspaceDraftStatus.bound);
    });

    test('clear removes draft', () async {
      final device = _Device();
      final key = _key('/work/alpha');
      final store = device.store();

      store.save(key, 'Pending text');
      await store.flush();
      expect(await store.read(key), isNotNull);

      await store.clear(key);
      expect(await store.read(key), isNull);
    });
  });
  test('typing after a fence never resets permission to create', () async {
    final device = _Device();
    final store = device.store();
    final key = _key('/fenced');
    await store.setAttemptFence(key, commandId: 'attempt', text: 'original');
    store.save(key, 'edited');
    await store.flush();
    expect((await store.read(key))?.status, WorkspaceDraftStatus.creating);
    expect(
      await store.setAttemptFence(key, commandId: 'again', text: 'edited'),
      isFalse,
    );
    expect(
      (await device.store().read(key))?.status,
      WorkspaceDraftStatus.uncertain,
    );
    store.save(key, '');
    await store.flush();
    expect((await store.read(key))?.fenceCommandId, 'attempt');
  });
  test('unknown record and invalid index are never overwritten', () async {
    final device = _Device();
    final key = _key('/unknown');
    final data =
        jsonDecode(
              WorkspaceDraftStore.encode(
                WorkspaceDraftEntry(key: key, text: 'protected'),
              ),
            )
            as Map<String, dynamic>;
    data['status'] = 'future-state';
    final raw = jsonEncode(data);
    device.backend.values[WorkspaceDraftStore.keyFor(key)] = raw;
    final store = device.store();
    expect(
      await store.setAttemptFence(key, commandId: 'id', text: 'new'),
      isFalse,
    );
    expect(device.raw(key), raw);
    device.backend.values[WorkspaceDraftStore.indexKey] = 'invalid index';
    final other = _key('/other');
    expect(
      await store.setAttemptFence(other, commandId: 'id', text: 'new'),
      isFalse,
    );
    expect(
      device.backend.values[WorkspaceDraftStore.indexKey],
      'invalid index',
    );
  });
  test('an unreadable draft is protected even before a first read', () async {
    final device = _Device();
    final key = _key('/corrupt');
    device.backend.values[WorkspaceDraftStore.keyFor(key)] = 'not-json';
    final store = device.store();
    store.save(key, 'replacement');
    await store.flush();
    expect(device.raw(key), 'not-json');
    expect(store.isUnreadable(key), isTrue);
  });
  test('capacity never evicts an unresolved attempt fence', () async {
    final device = _Device();
    final store = device.store();
    for (var i = 0; i < WorkspaceDraftStore.maxDrafts; i++) {
      expect(
        await store.setAttemptFence(
          _key('/project/$i'),
          commandId: 'id-$i',
          text: 'kept',
        ),
        isTrue,
      );
    }
    expect(
      await store.setAttemptFence(
        _key('/extra'),
        commandId: 'extra',
        text: 'new',
      ),
      isFalse,
    );
    expect(
      (await device.store().read(_key('/project/0')))?.fenceCommandId,
      'id-0',
    );
  });
  test(
    'discard clears fence and finishing a prompt preserves a later edit',
    () async {
      final device = _Device();
      final store = device.store();
      final key = _key('/edits');
      await store.setAttemptFence(key, commandId: 'first', text: 'original');
      await store.updateStatus(key, WorkspaceDraftStatus.ready);
      expect((await store.read(key))?.fenceCommandId, isNull);
      await store.setAttemptFence(key, commandId: 'second', text: 'original');
      store.save(key, 'later edit');
      await store.finishAttempt(key, 'second', 'original');
      await store.flush();
      final entry = await device.store().read(key);
      expect(entry?.text, 'later edit');
      expect(entry?.status, WorkspaceDraftStatus.ready);
      expect(entry?.fenceCommandId, isNull);
    },
  );
}
