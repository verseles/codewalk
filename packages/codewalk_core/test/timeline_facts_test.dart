import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

const _host = HostId('h');
const _harnessId = HarnessInstanceId('i');
const _harness = HarnessRef(_host, _harnessId);
const _ref = SessionRef(_host, _harnessId, 's1');

SourceProvenance _source({Durability durability = Durability.durable}) =>
    SourceProvenance(
      harness: _harness,
      version: '2.0.22',
      nativeType: 'test',
      durability: OpenValue.known(durability),
    );

ItemMeta _meta(String id, {ItemStatus status = ItemStatus.streaming}) =>
    ItemMeta(
      id: ItemId(id),
      generation: 'g1',
      status: OpenValue.known(status),
      source: _source(),
    );

void main() {
  test('ToolRunFacts validates shellId and survives withMeta and delta', () {
    expect(() => ToolRunFacts(shellId: ''), throwsArgumentError);
    expect(ToolRunFacts().isEmpty, isTrue);

    final facts = ToolRunFacts(
      exitCode: 0,
      shellStatus: const OpenValue.known(ShellStatus.exited),
      shellId: 'sh_1',
    );
    expect(facts.isEmpty, isFalse);
    expect(
      facts,
      ToolRunFacts(
        exitCode: 0,
        shellStatus: const OpenValue.known(ShellStatus.exited),
        shellId: 'sh_1',
      ),
    );

    final call = ToolCall(
      meta: _meta('t1'),
      kind: const OpenValue.known(ToolKind.shell),
      rawName: 'shell',
      input: CanonicalValue('echo'),
      runFacts: facts,
    );
    final updated =
        call.withMeta(_meta('t1', status: ItemStatus.completed)) as ToolCall;
    expect(updated.runFacts, facts);

    final pos1 = StreamPosition(id: 's', epoch: 'e', seq: BigInt.one);
    final pos2 = StreamPosition(id: 's', epoch: 'e', seq: BigInt.two);
    var state = reduce(
      SessionState(_ref),
      ItemUpserted(
        meta: EventMeta(
          owner: const SessionOwner(_ref),
          position: pos1,
          receivedAt: DateTime.utc(2026),
          source: _source(),
        ),
        item: call,
      ),
    ).state;
    state = reduce(
      state,
      ItemDelta(
        meta: EventMeta(
          owner: const SessionOwner(_ref),
          position: pos2,
          receivedAt: DateTime.utc(2026),
          source: _source(),
        ),
        itemId: const ItemId('t1'),
        field: const OpenValue.known(DeltaField.toolInput),
        text: ' hi',
        generation: 'g1',
      ),
    ).state;
    expect((state.timeline.single as ToolCall).runFacts, facts);
  });

  test(
    'Reasoning duration handles absent, valid, and inverted times and survives delta/gap',
    () {
      final start = DateTime.utc(2026, 1, 1, 0, 0, 1);
      final end = DateTime.utc(2026, 1, 1, 0, 0, 4);
      final rValid = Reasoning(
        meta: _meta('r1'),
        text: 'a',
        complete: false,
        started: start,
        completed: end,
      );
      expect(rValid.duration, const Duration(seconds: 3));

      final rInverted = Reasoning(
        meta: _meta('r2'),
        text: 'a',
        complete: true,
        started: end,
        completed: start,
      );
      expect(rInverted.duration, isNull);

      final rMissing = Reasoning(
        meta: _meta('r3'),
        text: 'a',
        complete: true,
        started: start,
      );
      expect(rMissing.duration, isNull);

      final copied =
          rValid.withMeta(_meta('r1', status: ItemStatus.completed))
              as Reasoning;
      expect(copied.started, start);
      expect(copied.completed, end);

      final pos1 = StreamPosition(id: 's', epoch: 'e', seq: BigInt.one);
      final pos2 = StreamPosition(id: 's', epoch: 'e', seq: BigInt.two);
      var state = reduce(
        SessionState(_ref),
        ItemUpserted(
          meta: EventMeta(
            owner: const SessionOwner(_ref),
            position: pos1,
            receivedAt: DateTime.utc(2026),
            source: _source(),
          ),
          item: rValid,
        ),
      ).state;
      state = reduce(
        state,
        ItemDelta(
          meta: EventMeta(
            owner: const SessionOwner(_ref),
            position: pos2,
            receivedAt: DateTime.utc(2026),
            source: _source(),
          ),
          itemId: const ItemId('r1'),
          field: const OpenValue.known(DeltaField.reasoning),
          text: 'b',
          generation: 'g1',
        ),
      ).state;
      final afterDelta = state.timeline.single as Reasoning;
      expect(afterDelta.started, start);
      expect(afterDelta.completed, end);

      final disconnected = disconnect(state);
      final afterGap = disconnected.timeline.single as Reasoning;
      expect(afterGap.prefixMissing, isTrue);
      expect(afterGap.started, start);
      expect(afterGap.completed, end);
    },
  );

  test('ShellReport validates shellId, compares by value, and survives withMeta', () {
    expect(() => ShellReport(shellId: ''), throwsArgumentError);
    final report = ShellReport(
      command: 'echo hi',
      outcome: OutcomeKind.succeeded,
      exitCode: 0,
      truncated: true,
      shellId: 'sh_1',
    );
    final equal = ShellReport(
      command: 'echo hi',
      outcome: OutcomeKind.succeeded,
      exitCode: 0,
      truncated: true,
      shellId: 'sh_1',
    );
    expect(report, equal);
    expect(report.hashCode, equal.hashCode);
    expect(
      report,
      isNot(ShellReport(command: 'echo hi', outcome: OutcomeKind.failed)),
    );

    final notice = Notice(
      meta: _meta('n1', status: ItemStatus.completed),
      kind: const OpenValue.known(NoticeKind.continuation),
      text: 'hi',
      shellReport: report,
    );
    final updated =
        notice.withMeta(_meta('n1', status: ItemStatus.completed)) as Notice;
    expect(updated.shellReport, report);

    final skill = Notice(
      meta: _meta('sk1', status: ItemStatus.completed),
      kind: const OpenValue.known(NoticeKind.skillActivated),
      text: 'review',
    );
    expect(skill.kind.known, NoticeKind.skillActivated);
  });
}
