import 'dart:convert';

import 'package:codewalk/data/session_attention/session_attention_snapshot_file_store.dart';
import 'package:codewalk/data/session_attention/session_attention_snapshot_store.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryKeyStorage implements SessionAttentionSnapshotKeyStorage {
  String? value;
  bool failReads = false;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async {
    if (failReads) {
      throw StateError('secure storage temporarily unavailable');
    }
    return value;
  }

  @override
  Future<void> write(String value) async => this.value = value;
}

class _MemoryFileStore implements SessionAttentionSnapshotFileStore {
  String? value;
  bool failWrites = false;

  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> writeAtomically(String value) async {
    if (failWrites) {
      throw StateError('atomic replacement failed');
    }
    this.value = value;
  }
}

const identity = SessionAttentionIdentity(
  serverId: 'server-a',
  directory: '/work/app',
  rootSessionId: 'session-a',
);

SessionAttentionItem item({String messageId = 'message-a'}) {
  return SessionAttentionItem(
    schemaVersion: 1,
    revision: 1,
    identity: identity,
    title: 'Private title',
    projectLabel: 'Project',
    kind: RootSessionAttentionKind.completed,
    startedAtEpochMs: 1,
    lastObservedAtEpochMs: 2,
    observableBusyElapsedMs: 3,
    assistantMessageId: messageId,
    displayText: 'Private response text',
    speechText: 'Private response text',
    displayTruncated: false,
    speechTruncated: false,
    completedAtEpochMs: 4,
    opened: false,
    dismissed: false,
    transportCapability: SessionAttentionTransportCapability.live,
    contentDigest: 'digest-a',
  );
}

void main() {
  test('encrypts roundtrip without plaintext in the file envelope', () async {
    final files = _MemoryFileStore();
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: files,
    );

    await store.upsert(item());
    final raw = files.value!;
    final read = await store.read();

    expect(raw, isNot(contains('Private response text')));
    expect(raw, isNot(contains('Private title')));
    expect(read.payload.items.single.displayText, 'Private response text');
  });

  test('uses a fresh nonce for each encrypted write', () async {
    final files = _MemoryFileStore();
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: files,
    );

    await store.upsert(item());
    final first = jsonDecode(files.value!) as Map<String, dynamic>;
    await store.upsert(item(messageId: 'message-b'));
    final second = jsonDecode(files.value!) as Map<String, dynamic>;

    expect(second['nonce'], isNot(first['nonce']));
  });

  test('tampering fails closed and deletes unreadable ciphertext', () async {
    final files = _MemoryFileStore();
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: files,
    );
    await store.upsert(item());
    final envelope = jsonDecode(files.value!) as Map<String, dynamic>;
    envelope['ciphertext'] = '${envelope['ciphertext']}AA';
    files.value = jsonEncode(envelope);

    final read = await store.read();

    expect(read.recoveredFromCorruption, isTrue);
    expect(read.payload.items, isEmpty);
    expect(files.value, isNull);
  });

  test(
    'dismissal tombstone prevents the same completion reappearing',
    () async {
      final store = SessionAttentionSnapshotStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: _MemoryFileStore(),
      );
      await store.upsert(item());
      await store.dismiss(identity: identity, assistantMessageId: 'message-a');
      await store.upsert(item());

      final read = await store.read();
      expect(read.payload.items, isEmpty);
      expect(read.payload.dismissalTombstones, hasLength(1));
    },
  );

  test('live dismissal records the exact observation digest', () async {
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
    );
    const live = SessionAttentionItem(
      schemaVersion: 1,
      revision: 1,
      identity: identity,
      title: 'Session',
      projectLabel: 'Project',
      kind: RootSessionAttentionKind.active,
      startedAtEpochMs: 1,
      lastObservedAtEpochMs: 2,
      observableBusyElapsedMs: 1,
      displayText: '',
      speechText: '',
      displayTruncated: false,
      speechTruncated: false,
      opened: false,
      dismissed: false,
      transportCapability:
          SessionAttentionTransportCapability.backgroundPlainOrBasic,
      contentDigest: 'live:active:1',
    );

    await store.suppressLive(live);

    expect(
      (await store.read()).payload.dismissalTombstones,
      contains('${identity.key}::live:active:1'),
    );
  });

  test(
    'digest tombstone removes and blocks a completion without message ID',
    () async {
      final store = SessionAttentionSnapshotStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: _MemoryFileStore(),
      );
      final withoutMessageId = item(messageId: '');
      await store.upsert(withoutMessageId);

      await store.suppressLive(withoutMessageId);
      await store.upsert(withoutMessageId);

      final payload = (await store.read()).payload;
      expect(payload.items, isEmpty);
      expect(
        payload.dismissalTombstones,
        contains('${identity.key}::digest-a'),
      );
    },
  );

  test(
    'stale dismiss and live suppression preserve a newer completion',
    () async {
      final store = SessionAttentionSnapshotStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: _MemoryFileStore(),
      );
      final newer = item(messageId: 'message-b');
      await store.upsert(newer);

      await store.dismiss(identity: identity, assistantMessageId: 'message-a');
      await store.suppressLive(
        const SessionAttentionItem(
          schemaVersion: 1,
          revision: 2,
          identity: identity,
          title: 'Session',
          projectLabel: 'Project',
          kind: RootSessionAttentionKind.error,
          startedAtEpochMs: 1,
          lastObservedAtEpochMs: 2,
          observableBusyElapsedMs: 1,
          displayText: '',
          speechText: '',
          displayTruncated: false,
          speechTruncated: false,
          opened: false,
          dismissed: false,
          transportCapability: SessionAttentionTransportCapability.live,
          contentDigest: 'live:error:2',
        ),
      );

      expect(
        (await store.read()).payload.items.single.assistantMessageId,
        'message-b',
      );
    },
  );

  test('consume removes only the selected snapshot token', () async {
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
    );
    final stale = item(messageId: 'message-a');
    final current = item(messageId: 'message-b');
    await store.upsert(current);

    await store.consume(stale);
    expect((await store.read()).payload.items, hasLength(1));

    await store.consume(current);
    expect((await store.read()).payload.items, isEmpty);
  });

  test('failed replacement preserves the prior encrypted file', () async {
    final files = _MemoryFileStore();
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: files,
    );
    await store.upsert(item());
    final original = files.value;
    files.failWrites = true;

    await expectLater(
      store.upsert(item(messageId: 'message-b')),
      throwsA(isA<SessionAttentionSnapshotStoreException>()),
    );
    expect(files.value, original);
  });

  test('identity cleanup does not cross directory boundaries', () async {
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
    );
    final other = item().withIdentity(
      const SessionAttentionIdentity(
        serverId: 'server-a',
        directory: '/work/other',
        rootSessionId: 'session-a',
      ),
    );
    await store.upsert(item());
    await store.upsert(other);

    await store.removeIdentity(identity);

    final read = await store.read();
    expect(read.payload.items, hasLength(1));
    expect(read.payload.items.single.identity.directory, '/work/other');
  });

  test('temporary key-storage failure preserves valid ciphertext', () async {
    final keys = _MemoryKeyStorage();
    final files = _MemoryFileStore();
    final store = SessionAttentionSnapshotStore(
      keyStorage: keys,
      fileStore: files,
    );
    await store.upsert(item());
    final encrypted = files.value;
    keys.failReads = true;

    // With in-memory key caching (issue #161 desktop perf), a temporary
    // secure-storage read failure after a successful upsert can still be
    // served from the cached key, preserving ciphertext and returning the
    // payload instead of throwing.
    final result = await store.read();
    expect(result.payload.items, hasLength(1));
    expect(files.value, encrypted);
  });

  test('dismiss with an empty message ID is a safe no-op', () async {
    final store = SessionAttentionSnapshotStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
    );
    await store.upsert(item());

    await store.dismiss(identity: identity, assistantMessageId: '');

    expect((await store.read()).payload.items, hasLength(1));
  });

  test(
    'normalizes separators and trailing slashes in durable identities',
    () async {
      final store = SessionAttentionSnapshotStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: _MemoryFileStore(),
      );
      await store.upsert(
        item().withIdentity(
          const SessionAttentionIdentity(
            serverId: ' server-a ',
            directory: r'\work\app\',
            rootSessionId: ' session-a ',
          ),
        ),
      );

      await store.removeIdentity(identity);

      expect((await store.read()).payload.items, isEmpty);
    },
  );
}
