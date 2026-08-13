import 'dart:convert';

import 'package:codewalk/data/car_messaging/car_messaging_file_store.dart';
import 'package:codewalk/data/car_messaging/car_messaging_store.dart';
import 'package:codewalk/domain/entities/car_messaging.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryKeyStorage implements CarMessagingKeyStorage {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _MemoryFileStore implements CarMessagingFileStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();

  @override
  Future<void> writeAtomically(String value) async => this.value = value;
}

class _ThrowingKeyStorage implements CarMessagingKeyStorage {
  @override
  Future<void> delete() async {}

  @override
  Future<String?> read() => throw StateError('keystore unavailable');

  @override
  Future<void> write(String value) async {}
}

const identity = SessionAttentionIdentity(
  serverId: 'server-a',
  directory: r'\work\app\',
  rootSessionId: 'session-a',
);

void main() {
  test(
    'encrypts threads and replies while preserving normalized identity',
    () async {
      final files = _MemoryFileStore();
      final store = CarMessagingStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: files,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      await store.upsertThread(
        const CarMessagingThread(
          identity: identity,
          title: 'Private conversation',
          entries: <CarMessagingEntry>[
            CarMessagingEntry(
              role: CarMessagingRole.agent,
              text: 'Private response',
              timestampEpochMs: 900,
            ),
          ],
          updatedAtEpochMs: 900,
          unread: true,
        ),
      );
      await store.enqueueReply(
        const CarMessagingReply(
          id: 'reply-a',
          identity: identity,
          text: 'Private reply',
          createdAtEpochMs: 950,
        ),
      );

      expect(files.value, isNot(contains('Private')));
      final state = await store.read();
      expect(state.threads.single.identity.directory, '/work/app');
      expect(state.replies.single.text, 'Private reply');
    },
  );

  test('bounds retained thread entries and reply queue', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(100000),
    );
    await store.upsertThread(
      CarMessagingThread(
        identity: identity,
        title: 'Thread',
        entries: List<CarMessagingEntry>.generate(
          12,
          (index) => CarMessagingEntry(
            role: CarMessagingRole.agent,
            text: '$index',
            timestampEpochMs: 90000 + index,
          ),
        ),
        updatedAtEpochMs: 90000,
      ),
    );
    for (var index = 0; index < 8; index += 1) {
      await store.enqueueReply(
        CarMessagingReply(
          id: 'reply-$index',
          identity: identity,
          text: 'reply $index',
          createdAtEpochMs: 90000 + index,
        ),
      );
    }

    final state = await store.read();
    expect(
      state.threads.single.entries,
      hasLength(kCarMessagingMaxEntriesPerThread),
    );
    expect(state.threads.single.entries.first.text, '4');
    expect(state.replies, hasLength(kCarMessagingMaxQueuedReplies));
    expect(state.replies.first.id, 'reply-0');
    expect(state.replies.last.id, 'reply-4');
  });

  test('tampering fails closed and deletes unreadable state', () async {
    final files = _MemoryFileStore();
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: files,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await store.upsertThread(
      const CarMessagingThread(
        identity: identity,
        title: 'Thread',
        entries: <CarMessagingEntry>[],
        updatedAtEpochMs: 900,
      ),
    );
    final envelope = jsonDecode(files.value!) as Map<String, dynamic>;
    envelope['ciphertext'] = '${envelope['ciphertext']}AA';
    files.value = jsonEncode(envelope);

    expect((await store.read()).threads, isEmpty);
    expect(files.value, isNull);
  });

  test('transient key storage failure preserves encrypted state', () async {
    final files = _MemoryFileStore();
    final keys = _MemoryKeyStorage();
    final writer = CarMessagingStore(
      keyStorage: keys,
      fileStore: files,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await writer.upsertThread(
      const CarMessagingThread(
        identity: identity,
        title: 'Thread',
        entries: <CarMessagingEntry>[],
        updatedAtEpochMs: 900,
      ),
    );
    final encrypted = files.value;
    final reader = CarMessagingStore(
      keyStorage: _ThrowingKeyStorage(),
      fileStore: files,
    );

    await expectLater(reader.read(), throwsStateError);
    expect(files.value, encrypted);
  });

  test('clear removes encrypted state and its secure key', () async {
    final files = _MemoryFileStore();
    final keys = _MemoryKeyStorage();
    final store = CarMessagingStore(
      keyStorage: keys,
      fileStore: files,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await store.upsertThread(
      const CarMessagingThread(
        identity: identity,
        title: 'Thread',
        entries: <CarMessagingEntry>[],
        updatedAtEpochMs: 900,
      ),
    );

    await store.clear();

    expect(files.value, isNull);
    expect(keys.value, isNull);
  });

  test('claim is a compare-and-swap won by a single caller', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 950,
      ),
    );

    final first = await store.claimReply(
      replyId: 'reply-a',
      from: CarMessagingReplyState.queued,
      to: CarMessagingReplyState.sending,
    );
    final second = await store.claimReply(
      replyId: 'reply-a',
      from: CarMessagingReplyState.queued,
      to: CarMessagingReplyState.sending,
    );

    expect(first, isNotNull);
    expect(second, isNull);
    expect((await store.read()).replies.single.attempts, 1);
  });

  test(
    'enqueue never evicts in-flight replies and rejects when full',
    () async {
      final store = CarMessagingStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: _MemoryFileStore(),
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      for (var index = 0; index < 3; index += 1) {
        await store.enqueueReply(
          CarMessagingReply(
            id: 'reply-$index',
            identity: identity,
            text: 'reply $index',
            createdAtEpochMs: 900 + index,
          ),
        );
        await store.claimReply(
          replyId: 'reply-$index',
          from: CarMessagingReplyState.queued,
          to: CarMessagingReplyState.sending,
        );
      }

      final accepted = await store.enqueueReply(
        const CarMessagingReply(
          id: 'reply-3',
          identity: identity,
          text: 'reply 3',
          createdAtEpochMs: 903,
        ),
      );
      expect(accepted, isTrue);

      expect(
        await store.enqueueReply(
          const CarMessagingReply(
            id: 'reply-4',
            identity: identity,
            text: 'reply 4',
            createdAtEpochMs: 904,
          ),
        ),
        isTrue,
      );
      expect(
        await store.enqueueReply(
          const CarMessagingReply(
            id: 'reply-5',
            identity: identity,
            text: 'reply 5',
            createdAtEpochMs: 905,
          ),
        ),
        isFalse,
      );
      expect(
        await store.enqueueReply(
          const CarMessagingReply(
            id: 'reply-7',
            identity: identity,
            text: 'reply 7',
            createdAtEpochMs: 907,
          ),
        ),
        isFalse,
      );
      final state = await store.read();
      expect(state.replies, hasLength(5));
      expect(
        state.replies.any(
          (reply) =>
              reply.id == 'reply-0' &&
              reply.state == CarMessagingReplyState.sending,
        ),
        isTrue,
      );
    },
  );

  test('removeServer and removeIdentity clean threads and replies', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    const other = SessionAttentionIdentity(
      serverId: 'server-b',
      directory: '/work/app',
      rootSessionId: 'session-b',
    );
    await store.upsertThread(
      const CarMessagingThread(
        identity: identity,
        title: 'A',
        entries: <CarMessagingEntry>[],
        updatedAtEpochMs: 900,
      ),
    );
    await store.upsertThread(
      const CarMessagingThread(
        identity: other,
        title: 'B',
        entries: <CarMessagingEntry>[],
        updatedAtEpochMs: 900,
      ),
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 950,
      ),
    );

    await store.removeIdentity(identity);
    var state = await store.read();
    expect(state.threads, hasLength(1));
    expect(state.threads.single.identity.serverId, 'server-b');
    expect(state.replies, isEmpty);

    await store.removeServer('server-b');
    state = await store.read();
    expect(state.threads, isEmpty);
  });

  test('read persists pruning and deletes empty expired envelope', () async {
    final files = _MemoryFileStore();
    final keys = _MemoryKeyStorage();
    final store = CarMessagingStore(
      keyStorage: keys,
      fileStore: files,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 950,
      ),
    );
    expect(files.value, isNotNull);

    final later = CarMessagingStore(
      keyStorage: keys,
      fileStore: files,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000 + 60 * 60 * 1000),
    );
    final state = await later.read();

    expect(state.replies, isEmpty);
    expect(files.value, isNull);
  });

  test('read does not prune in-flight replies by age', () async {
    final files = _MemoryFileStore();
    final keys = _MemoryKeyStorage();
    final store = CarMessagingStore(
      keyStorage: keys,
      fileStore: files,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 950,
      ),
    );
    await store.claimReply(
      replyId: 'reply-a',
      from: CarMessagingReplyState.queued,
      to: CarMessagingReplyState.awaitingFinal,
    );
    final later = CarMessagingStore(
      keyStorage: keys,
      fileStore: files,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000 + 60 * 60 * 1000),
    );

    expect(
      (await later.read()).replies.single.state,
      CarMessagingReplyState.awaitingFinal,
    );
  });
}
