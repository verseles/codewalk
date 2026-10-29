import 'dart:async';
import 'dart:convert';

import 'package:codewalk/platform/sessions/opencode_turn_action_lane.dart';
import 'package:codewalk/platform/sessions/prompt_outbox_store.dart';
import 'package:codewalk/platform/sessions/turn_action_journal.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/platform/storage/storage_support.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_turn_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'live_fakes.dart';
import 'outbox_fakes.dart';

const _ref = SessionRef(
  HostId('profile_host'),
  HarnessInstanceId('h'),
  'ses_one',
);
const _child = SessionRef(
  HostId('profile_host'),
  HarnessInstanceId('h'),
  'ses_child',
);
const _id = CommandId('turn');

UserInput _turn(
  String message, {
  SessionRef ref = _ref,
  bool confirmed = true,
}) => UserInput(
  meta: ItemMeta(
    id: ItemId(jsonEncode([ref.storageKey, message, 'user', 0])),
    generation: 'history',
    status: const OpenValue.known(ItemStatus.completed),
    source: SourceProvenance(
      harness: ref.harnessRef,
      version: '2.0.22',
      nativeType: 'user',
    ),
    anchor: MessageAnchor(message: MessageRef(message), orderKey: message),
  ),
  text: 'text of $message',
  delivery: const OpenValue.known(DeliveryState.delivered),
  confirmed: confirmed,
);

RevertState _staged(String message) => RevertState(
  kind: const OpenValue.known(RevertKind.staged),
  anchor: MessageAnchor(message: MessageRef(message), orderKey: message),
);

final class _Wire implements EndpointHttpTransport {
  FutureOr<TransportResponse> Function(TransportRequest)? answer;
  final mutations = <TransportRequest>[];
  final reads = <String>[];
  final history = <Map<String, Object?>>[];
  final inbox = <Map<String, Object?>>[];
  String? staged;
  bool incomplete = false;
  bool failReads = false;
  FutureOr<TransportResponse?> Function(TransportRequest)? readAnswer;
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/proxy/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    final uri = Uri.parse(request.path);
    final segments = uri.pathSegments;
    if (request.method == 'GET') {
      reads.add(request.path);
      final override = await readAnswer?.call(request);
      if (override != null) return override;
      if (failReads) return outboxJson({}, status: 503);
      if (segments.last == 'active') {
        return outboxJson({'data': <String, Object?>{}});
      }
      if (segments.length == 3) {
        return outboxJson({
          'data': {
            'id': segments.last,
            'time': {'created': 1, 'updated': 2},
            if (staged != null) 'revert': {'messageID': staged},
          },
        });
      }
      if (segments.last == 'message') {
        return outboxJson({
          'data': history.reversed.toList(),
          'cursor': {'next': incomplete ? 'older' : null},
        });
      }
      return outboxJson({
        'data': segments.last == 'inbox' ? inbox : <Object?>[],
      });
    }
    mutations.add(request);
    if (answer != null) return answer!(request);
    final body = request.body == null
        ? null
        : jsonDecode(utf8.decode(request.body!)) as Map;
    if (segments.last == 'stage') {
      staged = body!['messageID'] as String;
      return outboxJson({
        'data': {'messageID': staged},
      });
    }
    if (segments.last == 'commit' || request.method == 'DELETE') {
      staged = null;
      return outboxEmpty(204);
    }
    return outboxJson({
      'data': {
        'id': body!['id'],
        'sessionID': segments[2],
        'time': {'created': 3},
        'type': segments.last == 'compact' ? 'compaction' : 'user',
        'payload': segments.last == 'compact'
            ? <String, Object?>{}
            : {'text': body['text']},
        'delivery': body['delivery'] ?? 'steer',
      },
    });
  }

  @override
  void close() => isClosed = true;
}

final class _Rig {
  _Rig({OutboxStore? store, _Wire? wire, KeySerialExecutor? queue})
    : store = store ?? OutboxStore(),
      wire = wire ?? _Wire(),
      queue = queue ?? KeySerialExecutor() {
    profile = EndpointProfile(
      id: 'profile_host',
      label: 'Fixture',
      endpoint: this.wire.endpoint,
    );
    reader = OpenCodeSessionReader(this.wire, harness: _ref.harnessRef);
    lane = OpenCodeTurnActionLane(
      queue: this.queue,
      journal: TurnActionJournal(this.store, profile),
      client: OpenCodeSessionTurnClient(
        this.wire,
        harness: _ref.harnessRef,
        connectedVersion: '2.0.22',
      ),
      reader: reader,
      ids: ids,
      commandIds: () => CommandId('commit-${next++}'),
      view: (ref) => views[ref]!,
      publish: (ref) {
        lane.consider(ref, views[ref]!);
      },
      refreshView: (_) {
        refreshes++;
      },
      currentBinding: () => binding,
      selectionHoldsSend: (_) => selectionPending,
      promptRefusal: (ref) => outbox.turnMutationRefusalWithinQueue(ref),
    );
    outbox = newOutbox();
  }
  final OutboxStore store;
  final _Wire wire;
  final KeySerialExecutor queue;
  final ids = OpenCodeMessageIds();
  late final EndpointProfile profile;
  late final OpenCodeSessionReader reader;
  late final OpenCodeTurnActionLane lane;
  late final OpenCodePromptOutbox outbox;
  final views = <SessionRef, SessionLiveView>{};
  bool binding = true;
  bool selectionPending = false;
  int refreshes = 0;
  int next = 0;

  OpenCodePromptOutbox newOutbox() => OpenCodePromptOutbox(
    store: store,
    client: OpenCodePromptClient(
      wire,
      harness: _ref.harnessRef,
      connectedVersion: '2.0.22',
    ),
    reader: reader,
    ids: ids,
    queue: queue,
    profile: profile,
    isCurrentBinding: () => binding,
    beforeSubmit: lane.beforeSubmit,
    beforeReplay: lane.beforeReplay,
    wait: (_) async {},
  );

  void show({
    SessionRef ref = _ref,
    RevertState? revert,
    List<TimelineItem>? items,
    List<PendingInput> pending = const [],
    bool more = false,
    bool stale = false,
    ExecutionKind execution = ExecutionKind.idle,
  }) {
    views[ref] = SessionLiveView(
      session: ref,
      phase: SessionLivePhase.live,
      stale: stale,
      state: liveState(
        ref,
        items: items ?? [_turn('msg_1', ref: ref), _turn('msg_2', ref: ref)],
        pending: pending,
        execution: ExecutionState(kind: OpenValue.known(execution)),
        revert:
            revert ?? const RevertState(kind: OpenValue.known(RevertKind.none)),
        hasMore: more,
      ),
    );
    lane.consider(ref, views[ref]!);
  }

  Future<SessionTurnActionPort> open({SessionRef ref = _ref}) async {
    if (!views.containsKey(ref)) show(ref: ref);
    lane.open(ref);
    await queue.drain();
    return lane.port(ref, () => binding);
  }

  Future<void> dispose() async {
    lane.close();
    await queue.drain();
    reader.dispose();
  }
}

Future<Object> _send(OpenCodePromptOutbox outbox, String id) => outbox.submit(
  session: _ref,
  commandId: CommandId(id),
  draft: PromptDraft(text: 'replacement'),
  delivery: Delivery.steer,
);

void main() {
  test('only persisted, adapter-anchored users are turn targets', () async {
    final rig = _Rig();
    addTearDown(rig.dispose);
    rig.show(items: [_turn('msg_local', confirmed: false)]);
    final port = await rig.open();
    expect(
      port.unavailable(SessionTurnAction.undo),
      SessionTurnUnavailable.targetUnknown,
    );
    expect((await port.stage(_turn('msg_local').id, id: _id)).applied, isFalse);
    expect(rig.wire.mutations, isEmpty);
  });

  test('stage hides by typed anchor without deleting canonical rows', () async {
    final rig = _Rig();
    addTearDown(rig.dispose);
    final port = await rig.open();
    final result = await port.stage(_turn('msg_2').id, id: _id);
    expect(result.applied, isTrue);
    expect(result.restored!.text, 'text of msg_2');
    expect(port.state.revert!.anchor, _staged('msg_2').anchor);
    expect(rig.views[_ref]!.state!.timeline, hasLength(2));
    expect(
      port.unavailable(SessionTurnAction.compact),
      SessionTurnUnavailable.revertStaged,
    );
    expect(jsonDecode(utf8.decode(rig.wire.mutations.single.body!)), {
      'messageID': 'msg_2',
      'files': true,
    });
  });

  test(
    'shared queue orders stage, commit, replacement prompt across outboxes',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      final stageEntered = Completer<void>();
      final releaseStage = Completer<void>();
      rig.wire.answer = (request) async {
        if (request.path.endsWith('/stage')) {
          stageEntered.complete();
          await releaseStage.future;
          return outboxJson({
            'data': {'messageID': 'msg_2'},
          });
        }
        if (request.path.endsWith('/commit')) return outboxEmpty(204);
        final body = jsonDecode(utf8.decode(request.body!)) as Map;
        return outboxJson({
          'data': {
            'id': body['id'],
            'sessionID': 'ses_one',
            'time': {'created': 3},
            'type': 'user',
            'payload': {'text': body['text']},
            'delivery': 'steer',
          },
        });
      };
      final stage = port.stage(_turn('msg_2').id, id: _id);
      await stageEntered.future;
      final secondLease = rig.lane.port(_ref, () => true);
      expect(
        (await secondLease.redoAll(id: const CommandId('tap2'))).unavailable,
        SessionTurnUnavailable.pending,
      );
      final submission = _send(rig.newOutbox(), 'send');
      await Future<void>.delayed(Duration.zero);
      expect(rig.wire.mutations, hasLength(1));
      releaseStage.complete();
      await stage;
      await submission;
      expect(
        rig.wire.mutations.map((r) => Uri.parse(r.path).pathSegments.last),
        ['stage', 'commit', 'prompt'],
      );
    },
  );

  test(
    'uncertain commit never sends a prompt and survives lane replacement',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.show(revert: _staged('msg_2'));
      final port = await rig.open();
      rig.wire.incomplete = true;
      rig.wire.answer = (_) =>
          throw const TransportException(TransportFailure.timeout);
      final result = await rig.outbox.submit(
        session: _ref,
        commandId: const CommandId('send'),
        draft: PromptDraft(text: 'replacement'),
        delivery: Delivery.steer,
      );
      expect(result.sent, isFalse);
      expect(
        rig.wire.mutations.map((r) => Uri.parse(r.path).pathSegments.last),
        ['commit'],
      );
      expect(port.state.phase, SessionTurnPhase.unconfirmed);
      expect(await rig.store.contains(TurnActionJournal.keyFor(_ref)), isTrue);
      rig.lane.close();
      final successor = _Rig(
        store: rig.store,
        wire: rig.wire,
        queue: rig.queue,
      );
      addTearDown(successor.dispose);
      successor.wire.incomplete = true;
      final reopened = await successor.open();
      expect(reopened.state.phase, SessionTurnPhase.unconfirmed);
      await _send(successor.outbox, 'send-again');
      expect(
        rig.wire.mutations,
        hasLength(1),
        reason: 'journal is read, never replayed',
      );
    },
  );

  test(
    'positive staged read settles uncertainty; absent stage does not',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      rig.wire.answer = (_) {
        rig.wire.staged = 'msg_2';
        throw const TransportException(TransportFailure.timeout);
      };
      final result = await port.stage(_turn('msg_2').id, id: _id);
      expect(result.receipt!.state.known, ReceiptState.uncertain);
      expect(result.applied, isTrue);
      expect(port.state.phase, SessionTurnPhase.idle);
      expect(port.state.revert!.anchor, _staged('msg_2').anchor);
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test(
    'redo next needs the actual cut, keeps partial redo staged, then clears',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.show(revert: _staged('msg_0'), more: true);
      final port = await rig.open();
      expect(
        port.unavailable(SessionTurnAction.redoNext),
        SessionTurnUnavailable.historyIncomplete,
      );
      expect((await port.redoNext(id: _id)).applied, isFalse);
      expect(rig.wire.mutations, isEmpty);
      rig.show(revert: _staged('msg_1'));
      final next = await port.redoNext(id: _id);
      expect(next.restored!.text, 'text of msg_2');
      expect(port.state.revert!.anchor, _staged('msg_2').anchor);
      final all = await port.redoNext(id: const CommandId('last'));
      expect(all.cleared, isTrue);
      expect(port.state.staged, isFalse);
      expect(rig.wire.mutations.last.method, 'DELETE');
    },
  );

  test('none alone cannot settle uncertain clear', () async {
    final rig = _Rig();
    addTearDown(rig.dispose);
    rig.show(revert: _staged('msg_2'));
    final port = await rig.open();
    rig.wire.incomplete = true;
    rig.wire.answer = (_) =>
        throw const TransportException(TransportFailure.timeout);
    final result = await port.redoAll(id: _id);
    expect(result.applied, isFalse);
    expect(port.state.phase, SessionTurnPhase.unconfirmed);
    await port.refresh();
    expect(port.state.phase, SessionTurnPhase.unconfirmed);
    expect(rig.wire.mutations, hasLength(1));
  });

  test(
    'busy, stale and selection-pending actions refuse before the wire',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      for (final kind in [
        ExecutionKind.running,
        ExecutionKind.retrying,
        ExecutionKind.waitingForInput,
        ExecutionKind.interruptedPendingResume,
      ]) {
        rig.show(execution: kind);
        expect(
          (await port.compact(id: _id)).unavailable,
          SessionTurnUnavailable.busy,
        );
      }
      rig.show(stale: true);
      expect(
        (await port.compact(id: _id)).unavailable,
        SessionTurnUnavailable.offline,
      );
      rig.show();
      rig.selectionPending = true;
      expect(
        (await port.compact(id: _id)).unavailable,
        SessionTurnUnavailable.selectionPending,
      );
      expect(rig.wire.mutations, isEmpty);
    },
  );

  test(
    'child actions stay in that child session and duplicate taps do not post',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open(ref: _child);
      await port.stage(_turn('msg_2', ref: _child).id, id: _id);
      expect(
        rig.wire.mutations.single.path,
        'api/session/ses_child/revert/stage',
      );
      expect(rig.views.containsKey(_ref), isFalse);
    },
  );

  test(
    'failed journal write sends nothing, including a commit-then-throw write',
    () async {
      for (final after in [false, true]) {
        final rig = _Rig();
        addTearDown(rig.dispose);
        final port = await rig.open();
        rig.store.failWrite = !after;
        rig.store.commitThenThrow = after;
        expect(
          (await port.stage(_turn('msg_2').id, id: _id)).unavailable,
          SessionTurnUnavailable.storage,
        );
        expect(rig.wire.mutations, isEmpty);
        expect(port.state.holdsSend, isTrue);
      }
    },
  );

  test('late reply never overwrites a newer remote boundary', () async {
    final rig = _Rig();
    addTearDown(rig.dispose);
    final port = await rig.open();
    final entered = Completer<void>();
    final release = Completer<void>();
    rig.wire.answer = (_) async {
      entered.complete();
      await release.future;
      return outboxJson({
        'data': {'messageID': 'msg_2'},
      });
    };
    final pending = port.stage(_turn('msg_2').id, id: _id);
    await entered.future;
    rig.show(revert: _staged('msg_2'));
    rig.show(revert: _staged('msg_1'));
    release.complete();
    expect((await pending).applied, isFalse);
    expect(port.state.revert!.anchor, _staged('msg_1').anchor);
  });

  test(
    'an admitted compaction is busy until its own terminal, never completed by HTTP',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      final result = await port.compact(id: _id);
      expect(result.applied, isTrue);
      expect(port.state.compacting, isTrue);
      expect(
        port.unavailable(SessionTurnAction.compact),
        SessionTurnUnavailable.busy,
      );
      expect(rig.wire.mutations, hasLength(1));
      final admitted = result.receipt!.nativeRef!;
      rig.show(
        items: [
          _turn('msg_1'),
          _turn('msg_2'),
          Notice(
            meta: _turn(admitted).meta,
            kind: const OpenValue.known(NoticeKind.compaction),
            text: 'summary',
          ),
        ],
      );
      await rig.queue.drain();
      expect(port.state.compacting, isFalse);
      expect(port.unavailable(SessionTurnAction.compact), isNull);
    },
  );

  test(
    'a complete commit proof releases the fence without sending the failed prompt',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.show(revert: _staged('msg_2'));
      final port = await rig.open();
      rig.wire.answer = (_) =>
          throw const TransportException(TransportFailure.timeout);
      final result = await rig.outbox.submit(
        session: _ref,
        commandId: _id,
        draft: PromptDraft(text: 'keep this draft'),
        delivery: Delivery.steer,
      );
      expect(result.sent, isFalse);
      expect(port.state.phase, SessionTurnPhase.idle);
      expect(port.state.staged, isFalse);
      expect(
        rig.wire.mutations.map((r) => Uri.parse(r.path).pathSegments.last),
        ['commit'],
      );
    },
  );

  test(
    'automatic admission reconciliation can read but never commit a remote revert',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.open();
      rig.wire.answer = (_) =>
          throw const TransportException(TransportFailure.timeout);
      await _send(rig.outbox, 'lost');
      rig.show(revert: _staged('msg_2'));
      final result = await rig.newOutbox().reconcile(
        _ref,
        const CommandId('lost'),
      );
      expect(result.posts, 0);
      expect(result.entry!.state, SubmissionKind.uncertain);
      expect(rig.wire.mutations, hasLength(1));
      expect(rig.wire.reads, isNotEmpty);
    },
  );

  test(
    'an action queued while reconciliation reads fences that step replay',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      rig.wire.answer = (_) =>
          throw const TransportException(TransportFailure.timeout);
      await _send(rig.outbox, 'lost');
      final entered = Completer<void>();
      final release = Completer<void>();
      var held = false;
      rig.wire.readAnswer = (request) async {
        if (!held && request.path.endsWith('/inbox')) {
          held = true;
          entered.complete();
          await release.future;
        }
        return null;
      };
      final reconcile = rig.newOutbox().reconcile(
        _ref,
        const CommandId('lost'),
      );
      await entered.future;
      final stage = port.stage(_turn('msg_2').id, id: _id);
      release.complete();
      expect((await reconcile).posts, 0);
      expect((await stage).unavailable, SessionTurnUnavailable.unconfirmed);
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test('a closed lease cannot mutate after an awaited journal write', () async {
    final store = _JournalGateStore();
    final rig = _Rig(store: store);
    addTearDown(rig.dispose);
    await rig.open();
    var open = true;
    final port = rig.lane.port(_ref, () => open);
    final stage = port.stage(_turn('msg_2').id, id: _id);
    await store.entered.future;
    open = false;
    store.release.complete();
    expect((await stage).applied, isFalse);
    expect(rig.wire.mutations, isEmpty);
    expect(await store.contains(TurnActionJournal.keyFor(_ref)), isFalse);
  });

  test(
    'a different binding preserves the pending journal and refuses mutations',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final journal = TurnActionJournal(rig.store, rig.profile);
      await journal.write(
        _ref,
        TurnActionRecord(
          operation: MutationOperation.revertStage,
          id: _id,
          anchor: _staged('msg_2').anchor,
        ),
      );
      final raw = rig.store.values[TurnActionJournal.keyFor(_ref)]!;
      final value = jsonDecode(raw) as Map<String, Object?>;
      value['binding'] = 1;
      rig.store.values[TurnActionJournal.keyFor(_ref)] = jsonEncode(value);
      final port = await rig.open();
      expect(port.state.unavailable, SessionTurnUnavailable.storage);
      await port.compact(id: _id);
      expect(rig.wire.mutations, isEmpty);
      expect(await rig.store.contains(TurnActionJournal.keyFor(_ref)), isTrue);
    },
  );
  test(
    'a typed committed cut settles uncertainty even with older history trimmed',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      rig.show(revert: _staged('msg_2'), more: true);
      final port = await rig.open();
      rig.wire.incomplete = true;
      rig.wire.answer = (_) {
        rig.show(
          revert: RevertState(
            kind: const OpenValue.known(RevertKind.committed),
            anchor: _staged('msg_2').anchor,
          ),
          items: [_turn('msg_1')],
          more: true,
        );
        throw const TransportException(TransportFailure.timeout);
      };
      final result = await rig.outbox.submit(
        session: _ref,
        commandId: _id,
        draft: PromptDraft(text: 'preserve'),
        delivery: Delivery.steer,
      );
      expect(result.sent, isFalse);
      expect(port.state.phase, SessionTurnPhase.idle);
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test('unknown revert identity fences actions and sends', () async {
    final rig = _Rig();
    addTearDown(rig.dispose);
    rig.show(
      revert: const RevertState(kind: OpenValue.known(RevertKind.unknown)),
    );
    final port = await rig.open();
    expect(
      port.unavailable(SessionTurnAction.compact),
      SessionTurnUnavailable.targetUnknown,
    );
    await _send(rig.outbox, 'unknown');
    expect(rig.wire.mutations, isEmpty);
    rig.show(
      revert: const RevertState(kind: OpenValue.known(RevertKind.staged)),
    );
    expect(
      port.unavailable(SessionTurnAction.undo),
      SessionTurnUnavailable.targetUnknown,
    );
  });
  test(
    'settled old-binding prompt records do not block new current-binding actions',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.open();
      rig.wire.answer = (request) {
        final body = jsonDecode(utf8.decode(request.body!)) as Map;
        rig.wire.history.add({
          'id': body['id'],
          'type': 'user',
          'text': body['text'],
          'time': {'created': 3},
        });
        throw const TransportException(TransportFailure.timeout);
      };
      await _send(rig.outbox, 'old-command');
      final old = await rig.outbox.reconcile(
        _ref,
        const CommandId('old-command'),
      );
      expect(old.entry!.state, SubmissionKind.delivered);
      rig.lane.close();
      rig.wire.endpoint = Uri.parse('http://127.0.0.1/changed/');
      rig.wire.answer = null;
      final successor = _Rig(
        store: rig.store,
        wire: rig.wire,
        queue: rig.queue,
      );
      addTearDown(successor.dispose);
      final port = await successor.open();
      final result = await port.stage(_turn('msg_2').id, id: _id);
      expect(result.applied, isTrue);
      expect(rig.wire.mutations.last.path, 'api/session/ses_one/revert/stage');
    },
  );
  test('unresolved old-binding prompts still fence new turn actions', () async {
    final rig = _Rig();
    addTearDown(rig.dispose);
    await rig.open();
    rig.wire.answer = (_) =>
        throw const TransportException(TransportFailure.timeout);
    await _send(rig.outbox, 'old-unknown');
    rig.lane.close();
    rig.wire.endpoint = Uri.parse('http://127.0.0.1/changed/');
    rig.wire.answer = null;
    final successor = _Rig(store: rig.store, wire: rig.wire, queue: rig.queue);
    addTearDown(successor.dispose);
    final port = await successor.open();
    expect(
      (await port.stage(_turn('msg_2').id, id: _id)).unavailable,
      SessionTurnUnavailable.unconfirmed,
    );
    expect(
      port.unavailable(SessionTurnAction.undo),
      SessionTurnUnavailable.unconfirmed,
    );
    expect(rig.wire.mutations, hasLength(1));
  });

  test(
    'an uncertain admission remains disabled until a read proves promotion',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      rig.wire.answer = (_) =>
          throw const TransportException(TransportFailure.timeout);
      await _send(rig.outbox, 'unknown');
      expect(
        (await port.stage(_turn('msg_2').id, id: _id)).unavailable,
        SessionTurnUnavailable.unconfirmed,
      );
      expect(
        port.unavailable(SessionTurnAction.undo),
        SessionTurnUnavailable.unconfirmed,
      );
      final original = (await rig.outbox.entries(_ref)).single;
      rig.wire.history.add({
        'id': original.messageId,
        'type': 'user',
        'text': 'replacement',
        'time': {'created': 3},
      });
      rig.show();
      await rig.queue.drain();
      expect(port.unavailable(SessionTurnAction.undo), isNull);
      expect(
        rig.wire.mutations,
        hasLength(1),
        reason: 'reconciliation only read',
      );
    },
  );
  test('R1 staged replacement refuses a canonical pending input', () async {
    final rig = _Rig();
    addTearDown(rig.dispose);
    rig.show(
      revert: _staged('msg_2'),
      pending: [
        PendingInput(
          id: const ItemId('pending'),
          text: 'another client input',
          delivery: const OpenValue.known(Delivery.queue),
          anchor: _turn('msg_3').meta.anchor,
        ),
      ],
    );
    final port = await rig.open();
    final result = await rig.outbox.submit(
      session: _ref,
      commandId: _id,
      draft: PromptDraft(text: 'replacement'),
      delivery: Delivery.steer,
    );
    expect(result.sent, isFalse);
    expect(rig.wire.mutations, isEmpty);
    expect(port.state.holdsSend, isTrue);
  });

  test(
    'R1 implicit commit checks another unresolved outbox admission',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.open();
      rig.wire.answer = (_) =>
          throw const TransportException(TransportFailure.timeout);
      await _send(rig.outbox, 'unknown-original');
      rig.wire.answer = null;
      rig.show(revert: _staged('msg_2'));
      final result = await rig.outbox.submit(
        session: _ref,
        commandId: _id,
        draft: PromptDraft(text: 'replacement'),
        delivery: Delivery.steer,
      );
      expect(result.sent, isFalse);
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test('R1 commit revalidates the cut after journal persistence', () async {
    final store = _JournalGateStore();
    final rig = _Rig(store: store);
    addTearDown(rig.dispose);
    rig.show(revert: _staged('msg_2'));
    await rig.open();
    final sending = rig.outbox.submit(
      session: _ref,
      commandId: _id,
      draft: PromptDraft(text: 'replacement'),
      delivery: Delivery.steer,
    );
    await store.entered.future;
    rig.show(revert: _staged('msg_1'));
    store.release.complete();
    expect((await sending).sent, isFalse);
    expect(rig.wire.mutations, isEmpty);
  });

  for (final change in ['execution', 'selection']) {
    test('R1 revalidates $change after journal persistence', () async {
      final store = _JournalGateStore();
      final rig = _Rig(store: store);
      addTearDown(rig.dispose);
      final port = await rig.open();
      final action = port.stage(_turn('msg_2').id, id: _id);
      await store.entered.future;
      if (change == 'execution') {
        rig.show(execution: ExecutionKind.running);
      } else {
        rig.selectionPending = true;
      }
      store.release.complete();
      expect((await action).applied, isFalse);
      expect(rig.wire.mutations, isEmpty);
    });
  }

  test(
    'R1 conflicting canonical cut beats HTTP without a matching echo',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      final entered = Completer<void>();
      final release = Completer<void>();
      rig.wire.answer = (_) async {
        entered.complete();
        await release.future;
        return outboxJson({
          'data': {'messageID': 'msg_2'},
        });
      };
      final action = port.stage(_turn('msg_2').id, id: _id);
      await entered.future;
      rig.show(revert: _staged('msg_1'));
      release.complete();
      final result = await action;
      expect(result.applied, isFalse);
      expect(result.restored, isNull);
      expect(port.state.revert!.anchor, _staged('msg_1').anchor);
    },
  );

  test(
    'R1 redo next refuses a successor that appears during preflight',
    () async {
      final store = _OutboxReadGateStore();
      final rig = _Rig(store: store);
      addTearDown(rig.dispose);
      rig.show(revert: _staged('msg_2'));
      final port = await rig.open();
      store.armed = true;
      final action = port.redoNext(id: _id);
      await store.entered.future;
      rig.show(
        revert: _staged('msg_2'),
        items: [_turn('msg_1'), _turn('msg_2'), _turn('msg_3')],
      );
      store.release.complete();
      expect((await action).applied, isFalse);
      expect(rig.wire.mutations, isEmpty);
      expect(port.state.staged, isTrue);
    },
  );

  test(
    'R1 accepted compaction keeps a durable fence across reopened leases',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      expect((await port.compact(id: _id)).applied, isTrue);
      expect(await rig.store.contains(TurnActionJournal.keyFor(_ref)), isTrue);
      rig.lane.release(_ref);
      final reopened = await rig.open();
      expect(reopened.state.compacting, isTrue);
      expect(
        reopened.unavailable(SessionTurnAction.undo),
        SessionTurnUnavailable.busy,
      );
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test(
    'R1 coalesced compaction terminal retries journal cleanup safely',
    () async {
      final store = _FailRemoveStore();
      final rig = _Rig(store: store);
      addTearDown(rig.dispose);
      final port = await rig.open();
      rig.wire.answer = (_) => outboxJson({
        'data': {
          'id': 'msg_coalesced',
          'sessionID': 'ses_one',
          'time': {'created': 3},
          'type': 'compaction',
          'payload': <String, Object?>{},
          'delivery': 'steer',
        },
      });
      await port.compact(id: _id);
      store.failRemove = true;
      rig.show(
        items: [_turn('msg_1'), _turn('msg_2'), _compaction('msg_coalesced')],
      );
      await rig.queue.drain();
      expect(await store.contains(TurnActionJournal.keyFor(_ref)), isTrue);
      store.failRemove = false;
      await port.refresh();
      await rig.queue.drain();
      expect(port.state.phase, SessionTurnPhase.idle);
      expect(port.state.compacting, isFalse);
      expect(await store.contains(TurnActionJournal.keyFor(_ref)), isFalse);
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test(
    'R1 uncertain compaction start latches busy without blocking ordinary prompts',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      final port = await rig.open();
      rig.wire.answer = (request) {
        final input =
            (jsonDecode(utf8.decode(request.body!)) as Map)['id'] as String;
        rig.show(
          items: [
            _turn('msg_1'),
            _turn('msg_2'),
            _compaction(input, running: true),
          ],
        );
        throw const TransportException(TransportFailure.timeout);
      };
      await port.compact(id: _id);
      expect(port.state.compacting, isTrue);
      expect(await rig.store.contains(TurnActionJournal.keyFor(_ref)), isTrue);
      expect(port.state.holdsSend, isFalse);
      rig.wire.answer = null;
      final sent = await rig.outbox.submit(
        session: _ref,
        commandId: const CommandId('normal-send'),
        draft: PromptDraft(text: 'queued while compacting'),
        delivery: Delivery.queue,
      );
      expect(sent.sent, isTrue);
      expect(
        port.unavailable(SessionTurnAction.undo),
        SessionTurnUnavailable.busy,
      );
    },
  );

  test(
    'R1 reopening probes unresolved admission before enabling turn actions',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.open();
      rig.wire.answer = (_) =>
          throw const TransportException(TransportFailure.timeout);
      await _send(rig.outbox, 'unknown');
      rig.lane.release(_ref);
      final reopened = await rig.open();
      expect(
        reopened.unavailable(SessionTurnAction.undo),
        SessionTurnUnavailable.unconfirmed,
      );
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test(
    'R1 refused replacement cannot replay after its rejected write fails',
    () async {
      final store = _FailRefusalStore();
      final rig = _Rig(store: store);
      addTearDown(rig.dispose);
      rig.show(revert: _staged('msg_2'));
      await rig.open();
      rig.wire.answer = (_) => outboxJson({}, status: 409);
      final result = await rig.outbox.submit(
        session: _ref,
        commandId: _id,
        draft: PromptDraft(text: 'keep unsent'),
        delivery: Delivery.steer,
      );
      expect(result.sent, isFalse);
      expect(store.failedWrites, 1);
      rig.wire.answer = null;
      rig.show();
      final checked = await rig.outbox.reconcile(_ref, _id);
      expect(checked.posts, 0);
      expect(rig.wire.mutations, hasLength(1));
    },
  );

  test(
    'R1 commit preserves older admission settlements made by its guard',
    () async {
      final rig = _Rig();
      addTearDown(rig.dispose);
      await rig.open();
      late String originalMessage;
      rig.wire.answer = (request) {
        final body = jsonDecode(utf8.decode(request.body!)) as Map;
        originalMessage = body['id'] as String;
        rig.wire.history.add({
          'id': originalMessage,
          'type': 'user',
          'text': body['text'],
          'time': {'created': 3},
        });
        throw const TransportException(TransportFailure.timeout);
      };
      await _send(rig.outbox, 'original-admission');
      expect(
        (await rig.outbox.entries(_ref)).single.state,
        SubmissionKind.uncertain,
      );
      rig.show(
        revert: _staged(originalMessage),
        items: [_turn('msg_1'), _turn(originalMessage)],
      );
      rig.wire.answer = (request) {
        if (request.path.endsWith('/commit')) {
          rig.wire.history.clear();
          return outboxEmpty(204);
        }
        final body = jsonDecode(utf8.decode(request.body!)) as Map;
        return outboxJson({
          'data': {
            'id': body['id'],
            'sessionID': 'ses_one',
            'type': 'user',
            'time': {'created': 4},
            'payload': {'text': body['text']},
            'delivery': body['delivery'],
          },
        });
      };
      final replacement = await rig.outbox.submit(
        session: _ref,
        commandId: _id,
        draft: PromptDraft(text: 'replacement'),
        delivery: Delivery.steer,
      );
      expect(replacement.sent, isTrue);
      final checked = await rig.outbox.reconcile(
        _ref,
        const CommandId('original-admission'),
      );
      expect(checked.entry!.state, SubmissionKind.delivered);
      expect(checked.posts, 0);
      expect(rig.wire.mutations, hasLength(3));
    },
  );

  test(
    'R1 a crash in preflight does not authorize later prompt replay',
    () async {
      final store = _OutboxWriteGateStore();
      final rig = _Rig(store: store);
      addTearDown(rig.dispose);
      rig.show(revert: _staged('msg_2'));
      await rig.open();
      store.armed = true;
      final sending = rig.outbox.submit(
        session: _ref,
        commandId: _id,
        draft: PromptDraft(text: 'still unsent'),
        delivery: Delivery.steer,
      );
      await store.entered.future;
      final snapshot = OutboxStore()..values.addAll(store.values);
      final successor = _Rig(store: snapshot);
      addTearDown(successor.dispose);
      try {
        await successor.open();
        final checked = await successor.outbox.reconcile(_ref, _id);
        expect(checked.posts, 0);
        expect(successor.wire.mutations, isEmpty);
      } finally {
        rig.binding = false;
        store.release.complete();
        await sending;
      }
    },
  );
}

final class _JournalGateStore extends OutboxStore {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    final result = await super.write(key, value);
    if (key.startsWith('cw2.turn.') && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return result;
  }
}

Notice _compaction(String id, {bool running = false}) {
  final meta = _turn(id).meta;
  return Notice(
    meta: ItemMeta(
      id: meta.id,
      generation: 'compaction',
      status: OpenValue.known(
        running ? ItemStatus.streaming : ItemStatus.completed,
      ),
      source: meta.source,
      anchor: meta.anchor,
    ),
    kind: const OpenValue.known(NoticeKind.compaction),
    text: running ? '' : 'summary',
  );
}

final class _OutboxReadGateStore extends OutboxStore {
  bool armed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> contains(String key) async {
    if (armed && key.startsWith('cw2.outbox.')) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return super.contains(key);
  }
}

final class _OutboxWriteGateStore extends OutboxStore {
  bool armed = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    final result = await super.write(key, value);
    if (armed && key.startsWith('cw2.outbox.')) {
      armed = false;
      entered.complete();
      await release.future;
    }
    return result;
  }
}

final class _FailRemoveStore extends OutboxStore {
  bool failRemove = false;
  @override
  Future<void> remove(String key) async {
    if (failRemove) throw StateError('owned fixture storage failure');
    await super.remove(key);
  }
}

final class _FailRefusalStore extends OutboxStore {
  int failedWrites = 0;
  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    if (key.startsWith('cw2.outbox.')) {
      final data = jsonDecode(value) as Map;
      if ((data['entries'] as List).any(
        (row) => (row as Map)['reason'] == 'turnUnconfirmed',
      )) {
        failedWrites++;
        throw StateError('owned fixture refused-write failure');
      }
    }
    return super.write(key, value);
  }
}
