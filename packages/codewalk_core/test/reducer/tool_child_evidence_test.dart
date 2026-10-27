import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

const _harness = HarnessRef(HostId('host'), HarnessInstanceId('native'));
const _ref = SessionRef(HostId('host'), HarnessInstanceId('native'), 'ses_p');
const _child = SessionRef(HostId('host'), HarnessInstanceId('native'), 'ses_c');
const _other = HarnessRef(HostId('host'), HarnessInstanceId('other'));

SourceProvenance _source(
  Durability durability, {
  HarnessRef harness = _harness,
}) => SourceProvenance(
  harness: harness,
  version: '1',
  nativeType: 'tool',
  durability: OpenValue.known(durability),
);

ToolCall _tool({
  SessionRef? child,
  ToolChildEvidence? evidence,
  String generation = 'g1',
  CanonicalValue? input,
}) => ToolCall(
  meta: ItemMeta(
    id: const ItemId('tool'),
    generation: generation,
    status: const OpenValue.known(ItemStatus.streaming),
    source: _source(Durability.durable),
  ),
  kind: const OpenValue.known(ToolKind.subagent),
  rawName: 'subagent',
  input: input,
  child: child,
  childEvidence: evidence,
);

ToolChildEvidence _evidence(
  ToolChildEvidenceKind kind, {
  String generation = 'g1',
  Durability durability = Durability.ephemeral,
  HarnessRef harness = _harness,
}) => ToolChildEvidence(
  kind: kind,
  origin: _source(durability, harness: harness),
  generation: generation,
);

EventMeta _meta(int seq) => EventMeta(
  owner: const SessionOwner(_ref),
  position: StreamPosition(id: 'stream', epoch: 'e', seq: BigInt.from(seq)),
  receivedAt: DateTime.utc(2026),
  source: _source(Durability.durable),
);

SessionState _upsert(SessionState state, ToolCall tool, int seq) =>
    reduce(state, ItemUpserted(meta: _meta(seq), item: tool)).state;

ToolCall _single(SessionState state) => state.timeline.single as ToolCall;

void main() {
  test('evidence fits only its own generation, harness and child', () {
    const observed = ToolChildEvidenceKind.observed;
    const rejected = ToolChildEvidenceKind.rejected;
    expect(_tool().childEvidenceValid, isTrue);
    // An unproven child without evidence stays allowed.
    expect(_tool(child: _child).childEvidenceValid, isTrue);
    expect(
      _tool(child: _child, evidence: _evidence(observed)).childEvidenceValid,
      isTrue,
    );
    expect(_tool(evidence: _evidence(rejected)).childEvidenceValid, isTrue);
    for (final invalid in [
      _tool(evidence: _evidence(observed)),
      _tool(child: _child, evidence: _evidence(rejected)),
      _tool(
        child: _child,
        evidence: _evidence(observed, generation: 'g0'),
      ),
      _tool(
        child: _child,
        evidence: _evidence(observed, harness: _other),
      ),
      _tool(
        child: const SessionRef(
          HostId('host'),
          HarnessInstanceId('other'),
          'ses_c',
        ),
        evidence: _evidence(observed),
      ),
    ]) {
      expect(invalid.childEvidenceValid, isFalse);
    }
  });

  test('an upsert with unfit evidence is refused and re-read', () {
    final result = reduce(
      SessionState(_ref),
      ItemUpserted(
        meta: _meta(1),
        item: _tool(evidence: _evidence(ToolChildEvidenceKind.observed)),
      ),
    );
    expect(result.state.timeline, isEmpty);
    expect(result.effects, isNotEmpty);
  });

  test('an input delta keeps the child and its evidence', () {
    var state = _upsert(
      SessionState(_ref),
      _tool(
        child: _child,
        evidence: _evidence(ToolChildEvidenceKind.observed),
        input: CanonicalValue('{"a":'),
      ),
      1,
    );
    state = reduce(
      state,
      ItemDelta(
        meta: _meta(2),
        itemId: const ItemId('tool'),
        field: const OpenValue.known(DeltaField.toolInput),
        text: '1}',
        generation: 'g1',
      ),
    ).state;
    expect(_single(state).input!.value, '{"a":1}');
    expect(_single(state).child, _child);
    expect(_single(state).childEvidence, isNotNull);
  });

  test('recovery forgets only ephemeral evidence', () {
    for (final (durability, kept) in [
      (Durability.ephemeral, false),
      (Durability.durable, true),
      (Durability.unknown, true),
    ]) {
      final state = _upsert(
        SessionState(_ref),
        _tool(
          child: _child,
          evidence: _evidence(
            ToolChildEvidenceKind.observed,
            durability: durability,
          ),
        ),
        1,
      );
      for (final recovered in [
        disconnect(state),
        beginHydration(
          state,
          generation: 'h2',
          readStart: StreamPosition(id: 'stream', epoch: 'e', seq: BigInt.one),
        ),
      ]) {
        expect(_single(recovered).child, kept ? _child : isNull);
        expect(
          _single(recovered).childEvidence == null,
          !kept,
          reason: '$durability',
        );
        // Everything else of the call stays.
        expect(_single(recovered).rawName, 'subagent');
        expect(_single(recovered).generation, 'g1');
      }
    }
  });
}
