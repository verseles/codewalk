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

const _harness = HarnessRef(HostId('host'), HarnessInstanceId('instance'));
const _session = SessionRef(
  HostId('host'),
  HarnessInstanceId('instance'),
  'ses_one',
);

/// Map-backed store whose writes can fail before or after committing.
final class _Store implements PayloadStore {
  final values = <String, String>{};
  final unreadable = <String>{};
  bool failWrite = false;
  bool commitThenThrow = false;
  int writes = 0;
  @override
  Future<bool> contains(String key) async =>
      values.containsKey(key) || unreadable.contains(key);
  @override
  Future<String?> read(String key) async =>
      unreadable.contains(key) ? null : values[key];
  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    writes++;
    if (failWrite) throw StateError('disk full');
    final same = values[key] == value;
    values[key] = value;
    if (commitThenThrow) throw StateError('failed after rename');
    return same ? PayloadWriteResult.unchanged : PayloadWriteResult.written;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

final class _ThrowingStore extends _Store {
  @override
  Future<String?> read(String key) async => throw StateError('io');
}

final class _Transport implements EndpointHttpTransport {
  _Transport(this.respond);
  FutureOr<TransportResponse> Function(Map<String, Object?> body) respond;
  final bodies = <Map<String, Object?>>[];
  void Function()? onSend;
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    onSend?.call();
    final body = jsonDecode(utf8.decode(request.body!)) as Map<String, Object?>;
    bodies.add(body);
    return respond(body);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse _json(Object? body, {int status = 200}) => TransportResponse(
  statusCode: status,
  headers: {
    'content-type': ['application/json'],
  },
  body: Stream.value(utf8.encode(jsonEncode(body))),
  cancel: () {},
);

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

OpenCodePromptOutbox _outbox(PayloadStore store, _Transport transport) =>
    OpenCodePromptOutbox(
      store: store,
      client: OpenCodePromptClient(
        transport,
        harness: _harness,
        connectedVersion: '2.0.22',
        deadline: const Duration(milliseconds: 200),
      ),
      ids: OpenCodeMessageIds(
        now: () => DateTime.utc(2026, 10, 15),
        random: Random(1),
      ),
      now: () => DateTime.utc(2026, 10, 15, 12),
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
}
