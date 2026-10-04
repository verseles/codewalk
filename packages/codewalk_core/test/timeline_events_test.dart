import 'dart:convert';

import 'package:codewalk_core/src/errors.dart';
import 'package:codewalk_core/src/events.dart';
import 'package:codewalk_core/src/identity.dart';
import 'package:codewalk_core/src/lifecycle.dart';
import 'package:codewalk_core/src/session.dart';
import 'package:codewalk_core/src/timeline.dart';
import 'package:codewalk_core/src/values.dart';
import 'package:codewalk_core/src/work.dart';
import 'package:test/test.dart';

const host = HostId('host');
const harness = HarnessInstanceId('profile');
const harnessRef = HarnessRef(host, harness);
const parent = SessionRef(host, harness, 'parent');
const child = SessionRef(host, harness, 'child');

SourceProvenance source(
  String type, {
  BigInt? seq,
  OpenValue<Durability> durability = const OpenValue.known(
    Durability.ephemeral,
  ),
}) => SourceProvenance(
  harness: harnessRef,
  version: '2.0.22',
  nativeType: type,
  aggregateId: parent.nativeId,
  aggregateSeq: seq,
  durability: durability,
);

ItemMeta itemMeta(
  String id, {
  String generation = 'generation-1',
  int? ordinal,
  String type = 'text',
}) => ItemMeta(
  id: ItemId(id),
  turnId: const TurnId('turn'),
  generation: generation,
  status: const OpenValue.known(ItemStatus.streaming),
  source: source(type),
  ordinal: ordinal,
);

EventMeta eventMeta(
  int seq, {
  DomainOwner owner = const SessionOwner(parent),
  SourceProvenance? provenance,
  DateTime? at,
}) => EventMeta(
  owner: owner,
  position: StreamPosition(
    id: 'observer-stream',
    epoch: 'epoch',
    seq: BigInt.from(seq),
  ),
  receivedAt: at ?? DateTime.utc(2026, 10, 4),
  source: provenance ?? source('test'),
);

void main() {
  test('unknown item keeps raw type and nested content as a neutral item', () {
    final nested = <Object?>['unchanged'];
    final raw = <String, Object?>{'future': nested};
    final item = UnknownItem(
      meta: ItemMeta(
        id: const ItemId('future-item'),
        generation: 'generation-unknown',
        status: OpenValue.unknown('paused-by-future-harness'),
        source: source(
          'future.item',
          durability: OpenValue.unknown('future-durability'),
        ),
      ),
      rawType: 'future.item',
      raw: CanonicalValue(raw),
      fallbackText: 'future content',
    );
    nested[0] = 'changed';
    raw['replacement'] = true;

    expect(item, isA<UnknownItem>());
    expect(item, isNot(isA<AssistantText>()));
    expect(item.rawType, 'future.item');
    expect(item.raw.toJson(), {
      'future': ['unchanged'],
    });
    expect(item.status.known, isNull);
    expect(item.status.value, 'paused-by-future-harness');
    expect(item.source.durability.value, 'future-durability');
    final retained = item.raw.value as Map<String, Object?>;
    expect(
      () => (retained['future'] as List<Object?>).add('x'),
      throwsUnsupportedError,
    );
  });

  test(
    'user input copies attachment and mention lists without rewriting refs',
    () {
      final output = OutputRef(id: 'phone-local:opaque/ref', sizeBytes: 17);
      final attachment = AttachmentRef(
        id: 'attachment',
        mimeType: 'image/png',
        content: output,
      );
      final mention = MentionRef(
        id: 'mention',
        kind: const OpenValue.known(MentionKind.file),
        label: 'A, B',
        target: 'host-file:../opaque,not-normalized',
      );
      final attachments = [attachment];
      final mentions = [mention];
      final item = UserInput(
        meta: itemMeta('user'),
        text: 'hello',
        attachments: attachments,
        mentions: mentions,
        commandId: const CommandId('command'),
        delivery: const OpenValue.known(DeliveryState.uncertain),
      );
      attachments.clear();
      mentions.clear();

      expect(item.attachments.single.content.id, output.id);
      expect(item.mentions.single.target, mention.target);
      expect(item.delivery.known, DeliveryState.uncertain);
      expect(() => item.attachments.clear(), throwsUnsupportedError);
      expect(() => item.mentions.clear(), throwsUnsupportedError);
    },
  );

  test('text and reasoning preserve independent ordinal-zero identities', () {
    final reasoning = Reasoning(
      meta: itemMeta(
        'message/reasoning/0',
        ordinal: 0,
        type: 'reasoning.started',
      ),
      text: 'visible reasoning',
      complete: false,
    );
    final text = AssistantText(
      meta: itemMeta('message/text/0', ordinal: 0, type: 'text.started'),
      text: 'response',
      complete: false,
      prefixMissing: true,
    );

    expect(reasoning.meta.ordinal, 0);
    expect(text.meta.ordinal, 0);
    expect(reasoning.id, isNot(text.id));
    expect(reasoning.generation, text.generation);
    expect(text.prefixMissing, isTrue);
    expect(reasoning.source.nativeType, 'reasoning.started');
    expect(text.source.nativeType, 'text.started');
  });

  test(
    'tool retains unknown classification and fully qualified child identity',
    () {
      final input = {
        'paths': <Object?>['a'],
      };
      final item = ToolCall(
        meta: itemMeta('tool'),
        kind: OpenValue.unknown('future-tool-category'),
        rawName: 'Future.Tool',
        input: CanonicalValue(input),
        output: CanonicalValue({'status': 'future'}),
        child: child,
      );
      (input['paths'] as List<Object?>).clear();

      expect(item.kind.known, isNull);
      expect(item.kind.value, 'future-tool-category');
      expect(item.rawName, 'Future.Tool');
      expect(item.input?.toJson(), {
        'paths': ['a'],
      });
      expect(item.child, child);
      expect(
        item.child,
        isNot(
          const SessionRef(host, HarnessInstanceId('other-profile'), 'child'),
        ),
      );
    },
  );

  test('reference and stream constraints use runtime validation', () {
    expect(() => OutputRef(id: ''), throwsArgumentError);
    expect(() => OutputRef(id: 'output', sizeBytes: -1), throwsArgumentError);
    expect(() => OutputRef(id: 'output', mimeType: ''), throwsArgumentError);
    final content = OutputRef(id: 'output');
    expect(
      () => AttachmentRef(id: '', mimeType: 'image/png', content: content),
      throwsArgumentError,
    );
    expect(
      () => AttachmentRef(id: 'attachment', mimeType: '', content: content),
      throwsArgumentError,
    );
    expect(
      () => MentionRef(
        id: 'mention',
        kind: const OpenValue.known(MentionKind.file),
        label: 'file',
        target: '',
      ),
      throwsArgumentError,
    );
    expect(() => itemMeta('item', generation: ''), throwsArgumentError);
    expect(() => itemMeta('item', ordinal: -1), throwsArgumentError);
    expect(
      () => ItemDelta(
        meta: eventMeta(1),
        itemId: const ItemId('item'),
        field: const OpenValue.known(DeltaField.text),
        text: '',
        generation: '',
      ),
      throwsArgumentError,
    );
    expect(
      () => RetryScheduled(
        meta: eventMeta(1),
        attempt: -1,
        at: DateTime.utc(2026),
        error: ErrorInfo(
          kind: const OpenValue.known(ErrorKind.network),
          rawType: 'network',
          rawMessage: '',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('canonical sequence round-trips above JavaScript integer precision', () {
    final seq = BigInt.parse('900719925474099312345678901234567890');
    final position = StreamPosition(id: 'stream/☃', epoch: 'epoch:1', seq: seq);
    final encoded = jsonEncode(position.toJson());

    expect(position.toJson()['seq'], seq.toString());
    expect(StreamPosition.fromJson(jsonDecode(encoded)), position);
    expect(
      StreamPosition.fromJson(position.toJson()).hashCode,
      position.hashCode,
    );
    expect(
      StreamPosition(id: position.id, epoch: 'epoch:2', seq: seq),
      isNot(position),
    );
    expect(
      StreamPosition(id: 'another', epoch: position.epoch, seq: seq),
      isNot(position),
    );
  });

  test('sequence decoding rejects lossy numbers and malformed positions', () {
    final valid = {'version': 1, 'id': 'stream', 'epoch': 'epoch', 'seq': '0'};
    for (final badSeq in <Object?>[
      0,
      9007199254740992.0,
      '-1',
      '+1',
      '01',
      '1.0',
      '1\n',
      ' 1',
      '1 ',
      '',
      null,
    ]) {
      expect(
        () => StreamPosition.fromJson({...valid, 'seq': badSeq}),
        throwsFormatException,
      );
    }
    for (final invalid in <Object?>[
      null,
      [],
      {...valid, 'version': 2},
      {...valid, 'version': 1.0},
      {...valid, 'id': ''},
      {...valid, 'epoch': ''},
      {...valid, 'id': 1},
      {...valid, 1: 'invalid key'},
    ]) {
      expect(() => StreamPosition.fromJson(invalid), throwsFormatException);
    }
    expect(
      () => StreamPosition(id: 's', epoch: 'e', seq: BigInt.from(-1)),
      throwsArgumentError,
    );
    expect(
      () => StreamPosition(id: '', epoch: 'e', seq: BigInt.zero),
      throwsArgumentError,
    );
    expect(
      () => StreamPosition(id: 's', epoch: '', seq: BigInt.zero),
      throwsArgumentError,
    );
  });

  test(
    'canonical contiguous positions do not reinterpret upstream skipped records',
    () {
      final first = UnknownEvent(
        meta: eventMeta(
          1,
          provenance: source('native-a', seq: BigInt.from(17)),
        ),
        rawType: 'native-a',
        raw: CanonicalValue(null),
      );
      final second = UnknownEvent(
        meta: eventMeta(
          2,
          provenance: source('native-b', seq: BigInt.from(23)),
        ),
        rawType: 'native-b',
        raw: CanonicalValue(null),
      );

      expect(second.meta.position.seq - first.meta.position.seq, BigInt.one);
      expect(
        second.meta.source.aggregateSeq! - first.meta.source.aggregateSeq!,
        BigInt.from(6),
      );
    },
  );

  test(
    'global and unresolved observations never fabricate a session owner',
    () {
      final global = ResyncRequired(
        meta: eventMeta(1, owner: const GlobalOwner(harnessRef)),
        reason: 'authoritative hydration required',
      );
      final unknown = UnknownEvent(
        meta: eventMeta(
          2,
          owner: UnknownOwner(reason: 'unresolved-native-scope'),
        ),
        rawType: 'future.global',
        raw: CanonicalValue({'value': 'preserved'}),
      );

      expect(global.meta.owner, isA<GlobalOwner>());
      expect(global.meta.owner.harness, harnessRef);
      expect(global.meta.owner, isNot(isA<SessionOwner>()));
      expect(unknown.meta.owner.isKnown, isFalse);
      expect(unknown.meta.owner, isNot(isA<SessionOwner>()));
    },
  );

  test('known event owner rejects a different source harness', () {
    final anotherHarness = SourceProvenance(
      harness: const HarnessRef(host, HarnessInstanceId('other-profile')),
      version: '2.0.22',
      nativeType: 'test',
    );
    expect(() => eventMeta(1, provenance: anotherHarness), throwsArgumentError);
    expect(
      () => eventMeta(
        1,
        owner: const GlobalOwner(harnessRef),
        provenance: anotherHarness,
      ),
      throwsArgumentError,
    );
    final unknown = eventMeta(
      1,
      owner: UnknownOwner(reason: 'owner-not-yet-resolved'),
      provenance: anotherHarness,
    );
    expect(unknown.owner.isKnown, isFalse);
    expect(unknown.source, same(anotherHarness));
  });

  test(
    'watermark and bounded diagnostics stay separate from canonical position',
    () {
      final provenance = source(
        'log.synced',
        seq: BigInt.from(31),
        durability: const OpenValue.known(Durability.watermarkOnly),
      );
      final regular = eventMeta(1, provenance: provenance);
      final diagnostic = DiagnosticRef(
        id: 'redacted-capture',
        byteLength: 64,
        redacted: true,
      );
      final captured = EventMeta(
        owner: regular.owner,
        position: regular.position,
        receivedAt: regular.receivedAt,
        source: provenance,
        rawRef: diagnostic,
      );

      expect(regular.rawRef, isNull);
      expect(captured.rawRef, same(diagnostic));
      expect(captured.source.durability.known, Durability.watermarkOnly);
      expect(captured.source.aggregateSeq, BigInt.from(31));
      expect(captured.position.seq, BigInt.one);
    },
  );

  test('parent notice can precede a child-owned terminal observation', () {
    final notice = ItemUpserted(
      meta: eventMeta(1, at: DateTime.utc(2026, 10, 4, 8, 0, 0, 648)),
      item: Notice(
        meta: itemMeta('completion-notice', type: 'synthetic'),
        kind: const OpenValue.known(NoticeKind.workCompletion),
        text: 'Child was cancelled',
        relatedSession: child,
      ),
    );
    final terminal = ExecutionChanged(
      meta: eventMeta(
        2,
        owner: const SessionOwner(child),
        at: DateTime.utc(2026, 10, 4, 8, 0, 0, 650),
      ),
      state: const ExecutionState(
        kind: OpenValue.known(ExecutionKind.idle),
        lastOutcome: ExecutionOutcome(
          OpenValue.known(ExecutionOutcomeKind.interrupted),
          reason: 'user',
        ),
      ),
    );

    expect(notice.meta.receivedAt.isBefore(terminal.meta.receivedAt), isTrue);
    expect((notice.meta.owner as SessionOwner).session, parent);
    expect((notice.item as Notice).relatedSession, child);
    expect((terminal.meta.owner as SessionOwner).session, child);
    expect(
      terminal.state.lastOutcome?.kind.known,
      ExecutionOutcomeKind.interrupted,
    );
    expect(notice, isNot(isA<ExecutionChanged>()));
  });

  test(
    'pending and work level-sets copy collections and support empty replacement',
    () {
      final pending = <PendingInput>[
        const PendingInput(
          id: ItemId('pending'),
          text: 'queued',
          delivery: OpenValue.known(Delivery.queue),
        ),
      ];
      final work = <WorkItem>[
        const WorkItem(
          id: WorkId('work'),
          owner: SessionOwner(parent),
          child: child,
          parent: parent,
          status: OpenValue.known(WorkStatus.running),
          completionScope: OpenValue.known(CompletionScope.child),
        ),
      ];
      final pendingEvent = PendingInputChanged(
        meta: eventMeta(1),
        items: pending,
      );
      final workEvent = WorkChanged(meta: eventMeta(2), items: work);
      pending.clear();
      work.clear();

      expect(pendingEvent.items.single.id, const ItemId('pending'));
      expect(workEvent.items.single.child, child);
      expect(() => pendingEvent.items.clear(), throwsUnsupportedError);
      expect(() => workEvent.items.clear(), throwsUnsupportedError);
      expect(
        PendingInputChanged(meta: eventMeta(3), items: const []).items,
        isEmpty,
      );
      expect(WorkChanged(meta: eventMeta(4), items: const []).items, isEmpty);
    },
  );

  test('delta retains explicit generation and open field classification', () {
    final delta = ItemDelta(
      meta: eventMeta(1),
      itemId: const ItemId('text'),
      field: OpenValue.unknown('future-field'),
      text: 'fragment',
      generation: 'generation-2',
    );
    final completed = ItemUpserted(
      meta: eventMeta(2),
      item: AssistantText(
        meta: ItemMeta(
          id: delta.itemId,
          generation: delta.generation,
          status: const OpenValue.known(ItemStatus.completed),
          source: source('text.ended'),
        ),
        text: 'authoritative full content',
        complete: true,
      ),
    );

    expect(delta.field.value, 'future-field');
    expect(delta.generation, 'generation-2');
    expect(completed.item.id, delta.itemId);
    expect(completed.item.generation, delta.generation);
    expect(
      (completed.item as AssistantText).text,
      'authoritative full content',
    );
    expect((completed.item as AssistantText).prefixMissing, isFalse);
  });
}
