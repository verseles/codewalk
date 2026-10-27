import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

ItemMeta _meta(
  String id, {
  String? message,
  ItemStatus status = ItemStatus.completed,
  String generation = 'g1',
}) => ItemMeta(
  id: ItemId(id),
  generation: generation,
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'test',
  ),
  message: message == null
      ? null
      : MessageContext(message: MessageRef(message)),
);

UserInput _user(String id) => UserInput(
  meta: _meta(id),
  text: 'prompt',
  delivery: const OpenValue.known(DeliveryState.delivered),
);

Reasoning _think(String id, String message) => Reasoning(
  meta: _meta(id, message: message),
  text: 'hmm',
  complete: true,
);

ToolCall _tool(
  String id,
  String message, {
  ItemStatus status = ItemStatus.completed,
  ToolKind kind = ToolKind.read,
  String generation = 'g1',
}) => ToolCall(
  meta: _meta(id, message: message, status: status, generation: generation),
  kind: OpenValue.known(kind),
  rawName: kind.name,
);

AssistantText _text(
  String id,
  String message, {
  bool complete = true,
  String generation = 'g1',
}) => AssistantText(
  meta: _meta(
    id,
    message: message,
    status: complete ? ItemStatus.completed : ItemStatus.streaming,
    generation: generation,
  ),
  text: 'answer',
  complete: complete,
);

/// A short description of each row, to compare whole projections.
List<String> _shape(List<SessionTimelineRow> rows) => [
  for (final row in rows)
    switch (row) {
      SessionItemRow(:final item) => item.id.value,
      SessionToolRunRow(:final tools) =>
        'run(${tools.map((t) => t.id.value).join(',')})',
      SessionWorkGroupRow(:final work, :final messageCount, :final expanded) =>
        'work(${work.length}/$messageCount${expanded ? ',open' : ''})',
    },
];

/// A turn of two work messages and a final answer.
List<TimelineItem> _turn({bool complete = true, String generation = 'g1'}) => [
  _user('u1'),
  _think('r1', 'm1'),
  _tool('t1', 'm1', generation: generation),
  _tool('t2', 'm1', generation: generation),
  _tool('t3', 'm2', generation: generation),
  _text('a1', 'm3', complete: complete, generation: generation),
];

void main() {
  test('a streaming turn shows its calls in a run and nothing collapses', () {
    final rows = SessionTimelinePresentation().project(
      _turn(complete: false),
      settled: false,
    );
    expect(_shape(rows), ['u1', 'r1', 'run(t1,t2,t3)', 'a1']);
  });

  test('a finished turn collapses its work behind the answer', () {
    final presentation = SessionTimelinePresentation();
    var rows = presentation.project(_turn(), settled: true);
    expect(_shape(rows), ['u1', 'work(4/2)', 'a1']);
    final group = rows[1] as SessionWorkGroupRow;
    presentation.toggle(group.id);
    rows = presentation.project(_turn(), settled: true);
    expect(_shape(rows), ['u1', 'work(4/2,open)', 'r1', 'run(t1,t2,t3)', 'a1']);
    // The reader's choice survives the rebuilds of the same timeline...
    rows = presentation.project(_turn(generation: 'g2'), settled: true);
    expect((rows[1] as SessionWorkGroupRow).expanded, isTrue);
    // ...and a timeline shown again starts collapsed.
    rows = SessionTimelinePresentation().project(_turn(), settled: true);
    expect(_shape(rows), ['u1', 'work(4/2)', 'a1']);
  });

  test('the final answer keeps its whole message', () {
    final items = [
      _user('u1'),
      _tool('t1', 'm1'),
      _think('r2', 'm2'),
      _tool('t2', 'm2'),
      _text('a2', 'm2'),
    ];
    final rows = SessionTimelinePresentation().project(items, settled: true);
    expect(_shape(rows), ['u1', 'work(1/1)', 'r2', 't2', 'a2']);
  });

  group('the work never collapses before the turn finished (#273)', () {
    for (final (name, items, settled) in [
      ('while the session runs', _turn(), false),
      ('while the answer streams', _turn(complete: false), true),
      (
        'while a call still runs',
        [..._turn(), _tool('t4', 'm4', status: ItemStatus.streaming)],
        true,
      ),
      (
        'over a failed turn',
        [
          ..._turn(),
          TurnOutcome(
            meta: _meta('o1'),
            kind: const OpenValue.known(OutcomeKind.failed),
          ),
        ],
        true,
      ),
      (
        'without the harness message of the answer',
        [
          _user('u1'),
          _tool('t1', 'm1'),
          AssistantText(meta: _meta('a1'), text: 'answer', complete: true),
        ],
        true,
      ),
      (
        'without an answer',
        [_user('u1'), _tool('t1', 'm1'), _tool('t2', 'm1')],
        true,
      ),
    ]) {
      test(name, () {
        final rows = SessionTimelinePresentation().project(
          items,
          settled: settled,
        );
        expect(rows.whereType<SessionWorkGroupRow>(), isEmpty);
      });
    }
  });

  test('an earlier turn collapses while a newer one runs', () {
    final items = [
      ..._turn(),
      _user('u2'),
      _tool('t9', 'm9', status: ItemStatus.streaming),
    ];
    final rows = SessionTimelinePresentation().project(items, settled: false);
    expect(_shape(rows), ['u1', 'work(4/2)', 'a1', 'u2', 't9']);
  });

  test('a settled turn stays collapsed through status jitter (#274)', () {
    final presentation = SessionTimelinePresentation();
    final settledRows = presentation.project(_turn(), settled: true);
    final id = (settledRows[1] as SessionWorkGroupRow).id;
    // A pulse that briefly reports the session busy, and a rehydration that
    // brings the same items back under a new generation.
    for (final items in [_turn(), _turn(generation: 'g2')]) {
      final rows = presentation.project(items, settled: false);
      expect(_shape(rows), ['u1', 'work(4/2)', 'a1']);
      expect((rows[1] as SessionWorkGroupRow).id, id);
    }
    // An item of the turn that streams again reopens it, latch or not
    // (#273).
    final resumed = [
      for (final item in _turn())
        item.id.value == 't3'
            ? _tool('t3', 'm2', status: ItemStatus.streaming, generation: 'g3')
            : item,
    ];
    for (final settled in [false, true]) {
      expect(
        presentation
            .project(resumed, settled: settled)
            .whereType<SessionWorkGroupRow>(),
        isEmpty,
      );
    }
    // New content in the same turn reopens it while it runs.
    final rows = presentation.project([
      ..._turn(),
      _tool('t4', 'm4', status: ItemStatus.streaming),
    ], settled: false);
    expect(rows.whereType<SessionWorkGroupRow>(), isEmpty);
  });

  test('a run is two or more calls; a sub-agent keeps its own row', () {
    final items = [
      _user('u1'),
      _tool('t1', 'm1'),
      _think('r1', 'm1'),
      _tool('t2', 'm1'),
      _tool('s1', 'm1', kind: ToolKind.subagent),
      _tool('t3', 'm1'),
      _tool('t4', 'm1'),
      _text('a1', 'm1', complete: false),
    ];
    final presentation = SessionTimelinePresentation();
    final rows = presentation.project(items, settled: false);
    expect(_shape(rows), ['u1', 't1', 'r1', 't2', 's1', 'run(t3,t4)', 'a1']);
    final run = rows[5] as SessionToolRunRow;
    expect(run.expanded, isFalse);
    // The run's calls belong to a message opened above it.
    expect(run.messageHeaders, [false, false]);
    presentation.toggle(run.id);
    // A call appended to the run keeps its identity and its open state.
    final grown = presentation.project([
      ...items.take(7),
      _tool('t5', 'm1', status: ItemStatus.pending),
      ...items.skip(7),
    ], settled: false);
    final again = grown[5] as SessionToolRunRow;
    expect([again.id, again.expanded, again.tools.length], [run.id, true, 3]);
  });

  test('only the first item of a message opens it', () {
    final rows = SessionTimelinePresentation().project(
      _turn(complete: false),
      settled: false,
    );
    expect(
      [
        for (final row in rows)
          if (row is SessionItemRow) row.messageHeader,
      ],
      [false, true, true],
    );
  });
}
