import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:codewalk/platform/sessions/prompt_outbox_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../storage/storage_fakes.dart';
import 'outbox_fakes.dart';

typedef _Store = OutboxStore;
typedef _Transport = OutboxTransport;
typedef _Server = OutboxServer;
const _json = outboxJson;

const _harness = HarnessRef(HostId('host'), HarnessInstanceId('instance'));
const _session = SessionRef(
  HostId('host'),
  HarnessInstanceId('instance'),
  'ses_one',
);

final class _ThrowingStore extends _Store {
  @override
  Future<String?> read(String key) async => throw StateError('io');
}

/// The native admission for exactly what was sent.
TransportResponse _admit(Map<String, Object?> body) => _json({
  'data': {
    'id': body['id'],
    'sessionID': 'ses_one',
    'time': {'created': 1},
    'type': 'user',
    'payload': {'text': body['text']},
    'delivery': body['delivery'],
  },
});

OpenCodePromptOutbox _outbox(
  PayloadStore store,
  _Transport transport, {
  String version = '2.0.22',
  DateTime Function()? now,
  Future<void> Function(Duration)? wait,
}) => OpenCodePromptOutbox(
  store: store,
  client: OpenCodePromptClient(
    transport,
    harness: _harness,
    connectedVersion: version,
    deadline: const Duration(milliseconds: 200),
  ),
  reader: OpenCodeSessionReader(transport, harness: _harness),
  ids: OpenCodeMessageIds(
    now: () => DateTime.utc(2026, 10, 15),
    random: Random(1),
  ),
  now: now ?? () => DateTime.utc(2026, 10, 15, 12),
  wait: wait ?? (_) async {},
);

Future<OutboxSubmission> _submit(
  PromptOutbox outbox, {
  String command = 'cmd_1',
  String text = 'Hello',
  Delivery delivery = Delivery.steer,
  SessionRef session = _session,
}) => outbox.submit(
  session: session,
  commandId: CommandId(command),
  draft: PromptDraft(text: text),
  delivery: delivery,
);

Map<String, Object?> _ledger(_Store store, [SessionRef session = _session]) =>
    jsonDecode(store.values[OpenCodePromptOutbox.keyFor(session)]!)
        as Map<String, Object?>;

void main() {
  test('the exact payload is durable before the POST', () async {
    final store = _Store();
    final transport = _Transport(_admit);
    transport.onSend = () {
      final entry = (_ledger(store)['entries']! as List).single as Map;
      expect(entry['state'], 'sending');
      expect(jsonDecode(entry['payload']! as String), {
        'id': entry['messageId'],
        'text': 'Hello',
        'delivery': 'steer',
        'resume': true,
      });
    };
    final result = await _submit(_outbox(store, transport));
    expect(result.sent, isTrue);
    expect(result.entry!.state, SubmissionKind.admitted);
    expect(transport.bodies, hasLength(1));
    final saved = (_ledger(store)['entries']! as List).single as Map;
    expect(saved['state'], 'admitted');
    // The exact body is kept for a later same-id replay.
    expect(jsonDecode(saved['payload']! as String), transport.bodies.single);
    expect(store.values.keys.single, startsWith('cw2.outbox.v1.'));
  });

  test('a failed write sends nothing and keeps the draft', () async {
    final store = _Store()..failWrite = true;
    final transport = _Transport(_admit);
    final result = await _submit(_outbox(store, transport));
    expect(result.entry, isNull);
    expect(result.refusal, 'notPersisted');
    expect(transport.bodies, isEmpty);
  });

  test(
    'a write that committed before failing is confirmed by reading',
    () async {
      final store = _Store()..commitThenThrow = true;
      final transport = _Transport(_admit);
      final result = await _submit(_outbox(store, transport));
      expect(result.sent, isTrue);
      expect(transport.bodies, hasLength(1));
    },
  );

  test('a draft the client refuses is neither recorded nor sent', () async {
    final store = _Store();
    final transport = _Transport(_admit);
    final result = await _submit(_outbox(store, transport), text: '   ');
    expect(result.refusal, 'emptyText');
    expect(store.writes, 0);
    expect(transport.bodies, isEmpty);
  });

  test('after a restart a sending record is uncertain, never unsent', () async {
    final store = _Store();
    // Crash between persist and POST: the response never arrives.
    final hanging = _Transport((_) => Completer<TransportResponse>().future);
    final first = _outbox(store, hanging);
    unawaited(_submit(first));
    await pumpEventQueue();
    expect(
      ((_ledger(store)['entries']! as List).single as Map)['state'],
      'sending',
    );
    final restarted = _outbox(store, _Transport((_) => fail('no network')));
    // A prompt that may be on the wire cannot be dismissed.
    expect(
      await restarted.dismiss(_session, const CommandId('cmd_1')),
      isFalse,
    );
    final entries = await restarted.entries(_session);
    expect(entries.single.state, SubmissionKind.uncertain);
    expect(entries.single.reason, 'interrupted');
    expect(
      ((_ledger(store)['entries']! as List).single as Map)['state'],
      'uncertain',
    );
  });

  test('outcomes are kept: rejected, uncertain, refused locally', () async {
    final store = _Store();
    final transport = _Transport(
      (_) => _json({'_tag': 'ConflictError'}, status: 409),
    );
    final outbox = _outbox(store, transport);
    final conflict = await _submit(outbox);
    expect(conflict.entry!.state, SubmissionKind.rejected);
    expect(conflict.entry!.reason, 'ConflictError');
    transport.respond = (_) =>
        throw const TransportException(TransportFailure.connection);
    final lost = await _submit(outbox, command: 'cmd_2');
    expect(lost.entry!.state, SubmissionKind.uncertain);
    expect(lost.sent, isTrue);
    transport.isClosed = true;
    final closed = await _submit(outbox, command: 'cmd_3');
    expect(closed.sent, isFalse);
    expect(closed.entry!.state, SubmissionKind.rejected);
    expect(closed.entry!.reason, 'closed');
    final all = await outbox.entries(_session);
    expect(
      [for (final e in all) e.commandId.value],
      ['cmd_1', 'cmd_2', 'cmd_3'],
    );
    // Resolved or abandoned entries can be dismissed.
    expect(await outbox.dismiss(_session, const CommandId('cmd_2')), isTrue);
    expect(await outbox.dismiss(_session, const CommandId('cmd_1')), isTrue);
    expect((await outbox.entries(_session)), hasLength(1));
  });

  test('a known command is never posted again', () async {
    final store = _Store();
    final transport = _Transport(_admit);
    final outbox = _outbox(store, transport);
    final first = await _submit(outbox);
    final again = await _submit(outbox, text: 'Different');
    expect(again.sent, isFalse);
    expect(again.entry!.messageId, first.entry!.messageId);
    expect(transport.bodies, hasLength(1));
  });

  test('identical text under two commands is two prompts', () async {
    final transport = _Transport(_admit);
    final outbox = _outbox(_Store(), transport);
    final a = await _submit(outbox, command: 'cmd_a');
    final b = await _submit(outbox, command: 'cmd_b');
    expect(a.entry!.messageId, isNot(b.entry!.messageId));
    expect(transport.bodies, hasLength(2));
  });

  test('submits of one session are serialized', () async {
    final gate = Completer<void>();
    var inFlight = 0;
    var maxInFlight = 0;
    final transport = _Transport((body) async {
      inFlight++;
      maxInFlight = max(maxInFlight, inFlight);
      await gate.future;
      inFlight--;
      return _admit(body);
    });
    final outbox = _outbox(_Store(), transport);
    final a = _submit(outbox, command: 'cmd_a');
    final b = _submit(outbox, command: 'cmd_b');
    await pumpEventQueue();
    expect(transport.bodies, hasLength(1));
    gate.complete();
    await Future.wait([a, b]);
    expect(maxInFlight, 1);
    expect(transport.bodies, hasLength(2));
  });

  test('a full ledger refuses; it never evicts the user\'s text', () async {
    final store = _Store();
    final transport = _Transport(
      (_) => _json({'_tag': 'ConflictError'}, status: 409),
    );
    final outbox = _outbox(store, transport);
    for (var i = 0; i < OpenCodePromptOutbox.maxEntries; i++) {
      await _submit(outbox, command: 'cmd_$i');
    }
    final full = await _submit(outbox, command: 'cmd_extra');
    expect(full.refusal, 'full');
    expect(transport.bodies, hasLength(OpenCodePromptOutbox.maxEntries));
    // Dismissing a rejected entry makes room.
    expect(await outbox.dismiss(_session, const CommandId('cmd_0')), isTrue);
    transport.respond = _admit;
    expect((await _submit(outbox, command: 'cmd_extra')).sent, isTrue);
  });

  test('admitted entries make room; uncertain ones never do', () async {
    final store = _Store();
    final transport = _Transport(_admit);
    final outbox = _outbox(store, transport);
    for (var i = 0; i < OpenCodePromptOutbox.maxEntries + 3; i++) {
      expect((await _submit(outbox, command: 'cmd_$i')).sent, isTrue);
    }
    final kept = [
      for (final e in await outbox.entries(_session)) e.commandId.value,
    ];
    expect(kept, hasLength(OpenCodePromptOutbox.maxEntries));
    expect(kept.first, 'cmd_3');
    // A ledger full of possibly unresolved prompts refuses.
    final uncertain = _Store();
    transport.respond = (_) =>
        throw const TransportException(TransportFailure.connection);
    final blocked = _outbox(uncertain, transport);
    for (var i = 0; i < OpenCodePromptOutbox.maxEntries; i++) {
      await _submit(blocked, command: 'u_$i');
    }
    expect((await _submit(blocked, command: 'u_extra')).refusal, 'full');
    // Abandoning one restores a way forward without a repost.
    expect(await blocked.dismiss(_session, const CommandId('u_0')), isTrue);
    transport.respond = _admit;
    expect((await _submit(blocked, command: 'u_extra')).sent, isTrue);
    expect(
      (await _submit(blocked, command: 'u_0')).refusal,
      'alreadySubmitted',
    );
    transport.respond = (_) =>
        throw const TransportException(TransportFailure.connection);
    // An admitted entry can also be dismissed.
    expect(await outbox.dismiss(_session, const CommandId('cmd_3')), isTrue);
    // A command no longer recorded was submitted: never posted again.
    final posts = transport.bodies.length;
    for (final forgotten in ['cmd_0', 'cmd_3']) {
      final again = await _submit(outbox, command: forgotten);
      expect(again.refusal, 'alreadySubmitted');
    }
    expect(transport.bodies, hasLength(posts));
  });

  test('resubmitting an interrupted command reports it uncertain', () async {
    final store = _Store();
    final hanging = _Transport((_) => Completer<TransportResponse>().future);
    unawaited(_submit(_outbox(store, hanging)));
    await pumpEventQueue();
    final transport = _Transport(_admit);
    final again = await _submit(_outbox(store, transport));
    expect(again.sent, isFalse);
    expect(again.entry!.state, SubmissionKind.uncertain);
    expect(again.entry!.reason, 'interrupted');
    expect(transport.bodies, isEmpty);
    expect(
      ((_ledger(store)['entries']! as List).single as Map)['state'],
      'uncertain',
    );
  });

  test('ids minted before a restart stay below the next one', () async {
    final store = _Store();
    final transport = _Transport(_admit);
    final before = await _submit(_outbox(store, transport), command: 'a');
    // Same clock after the restart: the counter alone would repeat ordinals.
    final after = await _submit(_outbox(store, transport), command: 'b');
    expect(
      after.entry!.messageId.compareTo(before.entry!.messageId),
      greaterThan(0),
    );
    final saved = (_ledger(store)['entries']! as List).first as Map;
    expect(saved['resume'], isTrue);
  });

  test('an unreadable ledger is never overwritten', () async {
    final store = _Store();
    final key = OpenCodePromptOutbox.keyFor(_session);
    store.unreadable.add(key);
    final transport = _Transport(_admit);
    final outbox = _outbox(store, transport);
    expect((await _submit(outbox)).refusal, 'unreadable');
    expect(store.writes, 0);
    expect(transport.bodies, isEmpty);
    await expectLater(outbox.entries(_session), throwsStateError);
    // Another schema or another session's ledger under this key too.
    store.unreadable.clear();
    store.values[key] = jsonEncode({'schema': 2, 'entries': []});
    expect((await _submit(outbox)).refusal, 'unreadable');
    expect(transport.bodies, isEmpty);
  });

  test('a failing store is unreadable, not an error', () async {
    final outbox = _outbox(_ThrowingStore(), _Transport(_admit));
    expect((await _submit(outbox)).refusal, 'unreadable');
    await expectLater(outbox.entries(_session), throwsStateError);
  });

  test('sessions keep separate ledgers', () async {
    final store = _Store();
    final outbox = _outbox(store, _Transport(_admit));
    const other = SessionRef(
      HostId('host'),
      HarnessInstanceId('instance'),
      'ses_two',
    );
    await _submit(outbox);
    await _submit(outbox, session: other);
    expect(store.values, hasLength(2));
    expect(await outbox.entries(other), hasLength(1));
  });

  test('works over the real preference payload store', () async {
    final backend = FakeMetadataBackend();
    PayloadStore store() =>
        PreferencesPayloadStore(V2MetadataStore(backend: backend));
    final transport = _Transport(_admit);
    final sent = await _submit(_outbox(store(), transport));
    expect(sent.entry!.state, SubmissionKind.admitted);
    final entries = await _outbox(store(), transport).entries(_session);
    expect(entries.single.messageId, sent.entry!.messageId);
    expect(entries.single.text, 'Hello');
  });

  group('reconcile', () {
    test(
      'timeout after admission yields one message, without a repost',
      () async {
        final server = _Server()..loseResponse = true;
        final store = _Store();
        final outbox = _outbox(store, server.transport);
        final lost = await _submit(outbox);
        expect(lost.entry!.state, SubmissionKind.uncertain);
        server.loseResponse = false;
        final result = await outbox.reconcile(
          _session,
          const CommandId('cmd_1'),
        );
        expect(result.posts, 0);
        expect(result.entry!.state, SubmissionKind.admitted);
        expect(result.entry!.replays, 0);
        expect(server.transport.bodies, hasLength(1));
        expect(server.inbox, hasLength(1));
        expect(server.inbox.single['id'], lost.entry!.messageId);
        // A resolved entry is never checked again.
        server.transport.reads.clear();
        final again = await outbox.reconcile(
          _session,
          const CommandId('cmd_1'),
        );
        expect(again.entry!.state, SubmissionKind.admitted);
        expect(server.transport.reads, isEmpty);
      },
    );

    test(
      'a lost request is replayed once with the exact payload and id',
      () async {
        final server = _Server()..reachServer = false;
        final store = _Store();
        final outbox = _outbox(store, server.transport);
        await _submit(outbox);
        server.reachServer = true;
        final result = await outbox.reconcile(
          _session,
          const CommandId('cmd_1'),
        );
        expect(result.posts, 1);
        expect(result.entry!.state, SubmissionKind.admitted);
        expect(result.entry!.replays, 1);
        expect(server.transport.bodies, hasLength(2));
        expect(server.transport.bodies.last, server.transport.bodies.first);
        final saved = (_ledger(store)['entries']! as List).single as Map;
        expect(server.transport.raw.last, saved['payload']);
        expect(server.inbox, hasLength(1));
        // The inbox is read before the history page, newest first.
        expect(
          [for (final u in server.transport.reads) u.pathSegments.last],
          ['inbox', 'message'],
        );
      },
    );

    test('a promoted id is delivered and never posted again', () async {
      final server = _Server()..loseResponse = true;
      final outbox = _outbox(_Store(), server.transport);
      final lost = await _submit(outbox);
      server.promote(lost.entry!.messageId);
      final result = await outbox.reconcile(_session, const CommandId('cmd_1'));
      expect(result.posts, 0);
      expect(result.entry!.state, SubmissionKind.delivered);
      expect(server.transport.bodies, hasLength(1));
      expect(server.history, hasLength(1));
    });

    test(
      'any cancellation fence blocks the replay but not the check',
      () async {
        for (final fence in CancellationFence.values) {
          if (fence == CancellationFence.none) continue;
          final server = _Server()..reachServer = false;
          final outbox = _outbox(_Store(), server.transport);
          await _submit(outbox);
          expect(
            await outbox.setCancellationFence(
              _session,
              const CommandId('cmd_1'),
              fence,
            ),
            isTrue,
          );
          server.reachServer = true;
          final result = await outbox.reconcile(
            _session,
            const CommandId('cmd_1'),
          );
          expect(result.posts, 0, reason: fence.name);
          expect(result.entry!.state, SubmissionKind.uncertain);
          expect(result.entry!.reason, 'cancellationFence');
          expect(result.entry!.fence, fence);
          expect(server.transport.bodies, hasLength(1));
          expect(server.transport.reads, isNotEmpty);
        }
      },
    );

    test('at most three replays, with backoff between them', () async {
      final server = _Server()..reachServer = false;
      var clock = DateTime.utc(2026, 10, 15, 12);
      final waits = <Duration>[];
      final store = _Store();
      final outbox = _outbox(
        store,
        server.transport,
        now: () => clock,
        wait: (d) async {
          waits.add(d);
          clock = clock.add(d);
        },
      );
      await _submit(outbox);
      final result = await outbox.reconcile(_session, const CommandId('cmd_1'));
      expect(result.posts, 3);
      expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      expect(result.entry!.state, SubmissionKind.uncertain);
      expect(result.entry!.replays, OpenCodePromptOutbox.maxReplays);
      expect(server.transport.bodies, hasLength(4));
      expect(server.transport.raw.toSet(), hasLength(1));
      // Exhausted: still checked, never posted again.
      final later = await _outbox(
        store,
        server.transport,
        now: () => clock.add(const Duration(minutes: 1)),
      ).reconcile(_session, const CommandId('cmd_1'));
      expect(later.posts, 0);
      expect(later.entry!.reason, 'replayExhausted');
      expect(server.transport.bodies, hasLength(4));
      // A late admission still resolves it.
      server.inbox.add(server.row(server.transport.bodies.first));
      final resolved = await outbox.reconcile(
        _session,
        const CommandId('cmd_1'),
      );
      expect(resolved.entry!.state, SubmissionKind.admitted);
    });

    test('a clock set back never parks the caller', () async {
      final server = _Server()..reachServer = false;
      var clock = DateTime.utc(2026, 10, 15, 12);
      final waits = <Duration>[];
      final store = _Store();
      await _submit(_outbox(store, server.transport));
      final outbox = _outbox(
        store,
        server.transport,
        now: () => clock,
        wait: (d) async {
          waits.add(d);
          // The device clock jumps back an hour during the first wait.
          clock = clock.subtract(const Duration(hours: 1));
        },
      );
      final result = await outbox.reconcile(_session, const CommandId('cmd_1'));
      expect(waits, [const Duration(seconds: 1)]);
      expect(result.posts, 1);
      expect(result.entry!.state, SubmissionKind.uncertain);
      expect(result.entry!.replays, 1);
    });

    test('a failed or incomplete read keeps the entry uncertain', () async {
      final server = _Server()..reachServer = false;
      final outbox = _outbox(_Store(), server.transport);
      await _submit(outbox);
      server.reachServer = true;
      for (final (status, reason) in [
        (401, 'authenticationRequired'),
        (404, 'notFound'),
        (500, 'unavailable'),
      ]) {
        server.failReads = status;
        final result = await outbox.reconcile(
          _session,
          const CommandId('cmd_1'),
        );
        expect(result.posts, 0);
        expect(result.entry!.state, SubmissionKind.uncertain);
        expect(result.entry!.reason, reason);
        expect(result.entry!.replays, 0);
      }
      server.failReads = null;
      server.history.addAll([
        for (var i = 0; i < 200; i++)
          {
            'id': 'msg_${i.toString().padLeft(26, '0')}',
            'time': {'created': 1},
            'type': 'assistant',
          },
      ]);
      server.next = 'older';
      final incomplete = await outbox.reconcile(
        _session,
        const CommandId('cmd_1'),
      );
      expect(incomplete.posts, 0);
      expect(incomplete.entry!.reason, 'historyIncomplete');
      expect(server.transport.bodies, hasLength(1));
    });

    test('identical text under two commands stays two messages', () async {
      final server = _Server()..reachServer = false;
      final outbox = _outbox(_Store(), server.transport);
      await _submit(outbox, command: 'a');
      await _submit(outbox, command: 'b');
      server.reachServer = true;
      await outbox.reconcile(_session, const CommandId('a'));
      await outbox.reconcile(_session, const CommandId('b'));
      expect(server.inbox, hasLength(2));
      expect({for (final r in server.inbox) r['id']}, hasLength(2));
      expect(
        {for (final r in server.inbox) (r['payload']! as Map)['text']},
        {'Hello'},
      );
    });

    test('a pending id holding another text is occupied, not ours', () async {
      final server = _Server()..loseResponse = true;
      final outbox = _outbox(_Store(), server.transport);
      final lost = await _submit(outbox);
      (server.inbox.single['payload']! as Map)['text'] = 'Other';
      final result = await outbox.reconcile(_session, const CommandId('cmd_1'));
      expect(result.entry!.state, SubmissionKind.uncertain);
      expect(result.entry!.reason, 'identityOccupied');
      expect(result.posts, 0);
      expect(lost.entry!.messageId, server.inbox.single['id']);
    });

    test('an id held by another record is never cancelled', () async {
      final server = _Server()..loseResponse = true;
      final outbox = _outbox(_Store(), server.transport);
      await _submit(outbox);
      (server.inbox.single['payload']! as Map)['text'] = 'Other';
      await outbox.reconcile(_session, const CommandId('cmd_1'));
      final result = await outbox.cancel(_session, const CommandId('cmd_1'));
      expect(result.refusal, 'identityOccupied');
      expect(server.transport.changes, isEmpty);
      expect(server.inbox, hasLength(1));
    });

    test('a pending id switched to another delivery is still ours', () async {
      final server = _Server()..loseResponse = true;
      final outbox = _outbox(_Store(), server.transport);
      await _submit(outbox);
      server.inbox.single['delivery'] = 'queue';
      final result = await outbox.reconcile(_session, const CommandId('cmd_1'));
      expect(result.entry!.state, SubmissionKind.admitted);
      expect(result.posts, 0);
    });

    test('another connected version neither reads nor posts', () async {
      final server = _Server()..reachServer = false;
      final store = _Store();
      await _submit(_outbox(store, server.transport));
      final reads = server.transport.reads.length;
      final result = await _outbox(
        store,
        server.transport,
        version: '2.0.23',
      ).reconcile(_session, const CommandId('cmd_1'));
      expect(result.entry!.state, SubmissionKind.uncertain);
      expect(server.transport.reads, hasLength(reads));
      expect(server.transport.bodies, hasLength(1));
    });

    test('a crash during a replay keeps the counted attempt', () async {
      final server = _Server()..reachServer = false;
      final store = _Store();
      final outbox = _outbox(store, server.transport);
      await _submit(outbox);
      // The replay is recorded, then the result can no longer be written.
      server.onPost = () => store.failWrite = true;
      final result = await outbox.reconcile(_session, const CommandId('cmd_1'));
      expect(result.posts, 1);
      final saved = (_ledger(store)['entries']! as List).single as Map;
      expect(saved['state'], 'sending');
      expect(saved['replays'], 1);
      store.failWrite = false;
      server.onPost = null;
      final entries = await _outbox(store, server.transport).entries(_session);
      expect(entries.single.state, SubmissionKind.uncertain);
      expect(entries.single.reason, 'interrupted');
      expect(entries.single.replays, 1);
    });

    test('a ledger written before replays existed still loads', () async {
      final server = _Server()..reachServer = false;
      final store = _Store();
      await _submit(_outbox(store, server.transport));
      final ledger = _ledger(store);
      for (final entry in (ledger['entries']! as List).cast<Map>()) {
        entry
          ..remove('replays')
          ..remove('fence')
          ..remove('notBefore');
      }
      store.values[OpenCodePromptOutbox.keyFor(_session)] = jsonEncode(ledger);
      server.reachServer = true;
      final result = await _outbox(
        store,
        server.transport,
      ).reconcile(_session, const CommandId('cmd_1'));
      expect(result.posts, 1);
      expect(result.entry!.state, SubmissionKind.admitted);
      // An out-of-range count makes the ledger unreadable, never rewritten.
      final bad = _ledger(store);
      ((bad['entries']! as List).single as Map)['replays'] = 9;
      final raw = jsonEncode(bad);
      store.values[OpenCodePromptOutbox.keyFor(_session)] = raw;
      final refused = await _outbox(
        store,
        server.transport,
      ).reconcile(_session, const CommandId('cmd_1'));
      expect(refused.refusal, 'unreadable');
      expect(store.values[OpenCodePromptOutbox.keyFor(_session)], raw);
    });

    test('an unknown command is refused without network', () async {
      final server = _Server();
      final result = await _outbox(
        _Store(),
        server.transport,
      ).reconcile(_session, const CommandId('nope'));
      expect(result.refusal, 'unknownCommand');
      expect(server.transport.reads, isEmpty);
    });

    test('delivered entries make room in a full ledger', () async {
      final server = _Server()..loseResponse = true;
      final outbox = _outbox(_Store(), server.transport);
      for (var i = 0; i < OpenCodePromptOutbox.maxEntries; i++) {
        await _submit(outbox, command: 'u_$i');
      }
      expect((await _submit(outbox, command: 'extra')).refusal, 'full');
      server.promote(server.inbox.first['id']! as String);
      final delivered = await outbox.reconcile(
        _session,
        const CommandId('u_0'),
      );
      expect(delivered.entry!.state, SubmissionKind.delivered);
      server.loseResponse = false;
      expect((await _submit(outbox, command: 'extra')).sent, isTrue);
    });
  });

  group('cancel and switch', () {
    Future<(_Server, OpenCodePromptOutbox, _Store)> queued({
      Delivery delivery = Delivery.queue,
    }) async {
      final server = _Server();
      final store = _Store();
      final outbox = _outbox(store, server.transport);
      final sent = await _submit(outbox, delivery: delivery);
      expect(sent.entry!.state, SubmissionKind.admitted);
      return (server, outbox, store);
    }

    Map<dynamic, dynamic> saved(_Store store) =>
        (_ledger(store)['entries']! as List).single as Map;

    test('cancel of a pending prompt: fenced first, cancelled after', () async {
      final (server, outbox, store) = await queued();
      server.beforeChange = () =>
          expect(saved(store)['fence'], CancellationFence.submitting.name);
      final result = await outbox.cancel(_session, const CommandId('cmd_1'));
      expect(server.transport.changes.single.method, 'DELETE');
      expect(server.inbox, isEmpty);
      expect(result.entry!.state, SubmissionKind.cancelled);
      expect(result.entry!.fence, CancellationFence.cancelled);
      // Never sent again, and a repeated cancel sends nothing.
      final again = await outbox.cancel(_session, const CommandId('cmd_1'));
      expect(again.entry!.state, SubmissionKind.cancelled);
      expect(server.transport.changes, hasLength(1));
      final checked = await outbox.reconcile(
        _session,
        const CommandId('cmd_1'),
      );
      expect(checked.posts, 0);
      expect(server.transport.bodies, hasLength(1));
    });

    test('cancel racing delivery shows the delivery', () async {
      final (server, outbox, _) = await queued();
      // Delivered just before the DELETE arrives: 2.0.22 still answers 204.
      server.beforeChange = () =>
          server.promote(server.inbox.single['id']! as String);
      final result = await outbox.cancel(_session, const CommandId('cmd_1'));
      expect(result.entry!.state, SubmissionKind.delivered);
      expect(result.entry!.fence, CancellationFence.settled);
      expect(server.history, hasLength(1));
    });

    test(
      'a lost cancel response keeps the fence until a check decides',
      () async {
        final (server, outbox, store) = await queued();
        server.changeAnswer = (request) {
          server.inbox.clear();
          throw const TransportException(TransportFailure.timeout);
        };
        server.failReads = 500;
        final result = await outbox.cancel(_session, const CommandId('cmd_1'));
        expect(result.entry!.state, SubmissionKind.admitted);
        expect(result.entry!.fence, CancellationFence.uncertain);
        expect(result.entry!.reason, 'unavailable');
        // A later check finds it gone; nothing is ever posted again.
        server.failReads = null;
        final checked = await outbox.reconcile(
          _session,
          const CommandId('cmd_1'),
        );
        expect(checked.posts, 0);
        expect(checked.entry!.state, SubmissionKind.cancelled);
        expect(checked.entry!.fence, CancellationFence.cancelled);
        expect(saved(store)['fence'], 'cancelled');
        expect(server.transport.bodies, hasLength(1));
      },
    );

    test(
      'cancel of an unconfirmed prompt is never claimed nor replayed',
      () async {
        final server = _Server()..reachServer = false;
        final outbox = _outbox(_Store(), server.transport);
        await _submit(outbox);
        // The id is unknown to the server: its DELETE is a 204 no-op.
        final result = await outbox.cancel(_session, const CommandId('cmd_1'));
        expect(result.entry!.state, SubmissionKind.uncertain);
        expect(result.entry!.fence, CancellationFence.uncertain);
        expect(result.entry!.reason, 'cancellationFence');
        // The lost request arrives late; the check records it, still fenced.
        server.inbox.add(server.row(server.transport.bodies.single));
        final checked = await outbox.reconcile(
          _session,
          const CommandId('cmd_1'),
        );
        expect(checked.posts, 0);
        expect(checked.entry!.state, SubmissionKind.admitted);
        expect(checked.entry!.fence, CancellationFence.uncertain);
        // A second cancel removes it.
        final cancelled = await outbox.cancel(
          _session,
          const CommandId('cmd_1'),
        );
        expect(cancelled.entry!.state, SubmissionKind.cancelled);
        expect(server.inbox, isEmpty);
        expect(server.transport.bodies, hasLength(1));
      },
    );

    test(
      'a cancel that never left keeps the fence and sends nothing',
      () async {
        final (server, outbox, _) = await queued();
        server.transport.isClosed = true;
        final result = await outbox.cancel(_session, const CommandId('cmd_1'));
        expect(server.transport.changes, isEmpty);
        expect(result.entry!.state, SubmissionKind.admitted);
        expect(result.entry!.fence, CancellationFence.requested);
        expect(result.entry!.reason, 'closed');
      },
    );

    test('a fence that cannot be written sends nothing', () async {
      final (server, outbox, store) = await queued();
      store.failWrite = true;
      final result = await outbox.cancel(_session, const CommandId('cmd_1'));
      expect(result.refusal, 'notPersisted');
      expect(server.transport.changes, isEmpty);
    });

    test('a fence is never cleared or reopened', () async {
      final (_, outbox, _) = await queued();
      await outbox.cancel(_session, const CommandId('cmd_1'));
      for (final fence in CancellationFence.values) {
        expect(
          await outbox.setCancellationFence(
            _session,
            const CommandId('cmd_1'),
            fence,
          ),
          isFalse,
          reason: fence.name,
        );
      }
    });

    test('switch queue to steer follows the inbox, payload kept', () async {
      final (server, outbox, store) = await queued();
      final payload = saved(store)['payload'];
      final result = await outbox.switchDelivery(
        _session,
        const CommandId('cmd_1'),
        Delivery.steer,
      );
      final patch = server.transport.changes.single;
      expect(patch.method, 'PATCH');
      expect(jsonDecode(utf8.decode(patch.body!)), {'delivery': 'steer'});
      expect(result.entry!.delivery, Delivery.steer);
      expect(result.entry!.state, SubmissionKind.admitted);
      expect(saved(store)['payload'], payload);
      expect(saved(store)['delivery'], 'steer');
      // Already steered: nothing is sent.
      await outbox.switchDelivery(
        _session,
        const CommandId('cmd_1'),
        Delivery.steer,
      );
      expect(server.transport.changes, hasLength(1));
    });

    test(
      'switch of a delivered prompt shows the delivery, not a 409',
      () async {
        final (server, outbox, _) = await queued();
        server.promote(server.inbox.single['id']! as String);
        final result = await outbox.switchDelivery(
          _session,
          const CommandId('cmd_1'),
          Delivery.steer,
        );
        expect(server.transport.changes.single.method, 'PATCH');
        expect(result.entry!.state, SubmissionKind.delivered);
        expect(result.entry!.delivery, Delivery.queue);
      },
    );

    test('a 409 still pending keeps the delivery and says why', () async {
      final (server, outbox, _) = await queued();
      server.changeAnswer = (_) =>
          _json({'_tag': 'ConflictError'}, status: 409);
      final result = await outbox.switchDelivery(
        _session,
        const CommandId('cmd_1'),
        Delivery.steer,
      );
      expect(result.entry!.state, SubmissionKind.admitted);
      expect(result.entry!.delivery, Delivery.queue);
      expect(result.entry!.reason, 'ConflictError');
      // A failed check never makes an admitted prompt replayable.
      server.failReads = 500;
      final unchecked = await outbox.switchDelivery(
        _session,
        const CommandId('cmd_1'),
        Delivery.steer,
      );
      expect(unchecked.entry!.state, SubmissionKind.admitted);
      expect(unchecked.entry!.reason, 'unavailable');
    });

    test(
      'switch is refused for fenced, unconfirmed or unknown entries',
      () async {
        final (server, outbox, _) = await queued();
        expect(
          (await outbox.switchDelivery(
            _session,
            const CommandId('cmd_1'),
            Delivery.immediate,
          )).refusal,
          'unsupportedDelivery',
        );
        expect(
          (await outbox.switchDelivery(
            _session,
            const CommandId('nope'),
            Delivery.steer,
          )).refusal,
          'unknownCommand',
        );
        server.failReads = 500;
        await outbox.cancel(_session, const CommandId('cmd_1'));
        expect(
          (await outbox.switchDelivery(
            _session,
            const CommandId('cmd_1'),
            Delivery.steer,
          )).refusal,
          'cancellationFence',
        );
        final lost = _Server()..reachServer = false;
        final unconfirmed = _outbox(_Store(), lost.transport);
        await _submit(unconfirmed);
        expect(
          (await unconfirmed.switchDelivery(
            _session,
            const CommandId('cmd_1'),
            Delivery.steer,
          )).refusal,
          'notPending',
        );
        expect(lost.transport.changes, isEmpty);
      },
    );

    test('an unsettled cancel is never evicted', () async {
      final server = _Server();
      final outbox = _outbox(_Store(), server.transport);
      for (var i = 0; i < OpenCodePromptOutbox.maxEntries; i++) {
        await _submit(outbox, command: 'q_$i', delivery: Delivery.queue);
      }
      // The oldest prompt's cancel cannot be confirmed.
      server.failReads = 500;
      final open = await outbox.cancel(_session, const CommandId('q_0'));
      expect(open.entry!.fence, CancellationFence.uncertain);
      server.failReads = null;
      expect((await _submit(outbox, command: 'extra')).sent, isTrue);
      final kept = [
        for (final e in await outbox.entries(_session)) e.commandId.value,
      ];
      expect(kept, contains('q_0'));
      expect(kept, isNot(contains('q_1')));
    });

    test('cancelled entries make room in a full ledger', () async {
      final server = _Server();
      final outbox = _outbox(_Store(), server.transport);
      server.changeAnswer = null;
      for (var i = 0; i < OpenCodePromptOutbox.maxEntries; i++) {
        await _submit(outbox, command: 'c_$i', delivery: Delivery.queue);
        await outbox.cancel(_session, CommandId('c_$i'));
      }
      expect((await _submit(outbox, command: 'extra')).sent, isTrue);
      // The evicted command is forgotten, never sent again.
      expect(
        (await _submit(outbox, command: 'c_0')).refusal,
        'alreadySubmitted',
      );
    });
  });
}
