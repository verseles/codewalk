import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

ItemMeta _meta(
  String id, {
  String? message,
  ItemStatus status = ItemStatus.completed,
  String generation = 'g1',
  bool ended = false,
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
      : MessageContext(
          message: MessageRef(message),
          completed: ended ? DateTime.utc(2026, 10, 27) : null,
        ),
);

UserInput _user(String id) => UserInput(
  meta: _meta(id),
  text: 'prompt',
  delivery: const OpenValue.known(DeliveryState.delivered),
);

Reasoning _think(
  String id,
  String message, {
  bool complete = true,
  bool ended = false,
}) => Reasoning(
  meta: _meta(
    id,
    message: message,
    status: complete ? ItemStatus.completed : ItemStatus.streaming,
    ended: ended,
  ),
  text: 'hmm',
  complete: complete,
);

ToolCall _tool(
  String id,
  String message, {
  ItemStatus status = ItemStatus.completed,
  ToolKind kind = ToolKind.read,
  String generation = 'g1',
  bool ended = false,
  ToolRunFacts? runFacts,
}) => ToolCall(
  meta: _meta(
    id,
    message: message,
    status: status,
    generation: generation,
    ended: ended,
  ),
  kind: OpenValue.known(kind),
  rawName: kind.name,
  runFacts: runFacts,
);

AssistantText _text(
  String id,
  String message, {
  bool complete = true,
  String generation = 'g1',
  bool ended = false,
}) => AssistantText(
  meta: _meta(
    id,
    message: message,
    status: complete ? ItemStatus.completed : ItemStatus.streaming,
    generation: generation,
    ended: ended,
  ),
  text: 'answer',
  complete: complete,
);

/// A short description of each row, to compare whole projections.
List<String> _shape(List<SessionTimelineRow> rows) => [
  for (final row in rows)
    switch (row) {
      SessionItemRow(:final item) => item.id.value,
      SessionActivityStretchRow(
        :final work,
        :final expanded,
        :final runningCount,
        :final failedCount,
      ) =>
        'stretch(${work.map((w) => w.id.value).join(',')}'
            '${runningCount > 0 ? ',run=$runningCount' : ''}'
            '${failedCount > 0 ? ',fail=$failedCount' : ''}'
            '${expanded ? ',open' : ''})',
      SessionSubagentCallsRow(:final calls) =>
        'agents(${calls.map((call) => call.item.id.value).join(',')})',
      SessionReportRow(:final reports) => 'reports(${reports.length})',
      SessionPendingRow(:final anchor) => 'pending(${anchor.value})',
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
  test(
    'replies group only across consecutive original items even with folded work',
    () {
      Notice reply(String id) => Notice(
        meta: _meta(id),
        kind: const OpenValue.known(NoticeKind.continuation),
        text: 'body',
        report: const SubagentReport(),
      );
      final rows = SessionTimelinePresentation().project([
        reply('1'),
        reply('2'),
        _tool('call', 'm1'),
        reply('3'),
        _text('summary', 'm2'),
      ], settled: true);
      expect(_shape(rows), [
        'reports(2)',
        'stretch(call)',
        'reports(1)',
        'summary',
      ]);
    },
  );

  test('stretch collapses immediately as soon as following answer streams', () {
    final rows = SessionTimelinePresentation().project(
      _turn(complete: false),
      settled: false,
    );
    expect(_shape(rows), ['u1', 'stretch(r1,t1,t2,t3)', 'a1']);
  });

  test('without expanded tools a live tail is its summary at once (#537)', () {
    final presentation = SessionTimelinePresentation();
    final items = [
      _user('u1'),
      _think('r1', 'm1', complete: false),
      _tool('t1', 'm1'),
      _tool('t2', 'm1', status: ItemStatus.streaming),
    ];
    final rows = presentation.project(
      items,
      settled: false,
      expandTools: false,
    );
    expect(_shape(rows), ['u1', 'stretch(r1,t1,t2,run=2)']);
    // A tap still opens it, step by step.
    presentation.toggle('work-r1');
    expect(
      _shape(presentation.project(items, settled: false, expandTools: false)),
      ['u1', 'stretch(r1,t1,t2,run=2,open)', 'r1', 't1', 't2'],
    );
  });

  test('live tail with no following text stays individual compact rows', () {
    final rows = SessionTimelinePresentation().project([
      _user('u1'),
      _think('r1', 'm1', complete: false),
      _tool('t1', 'm1'),
      _tool('t2', 'm1', status: ItemStatus.streaming),
    ], settled: false);
    expect(_shape(rows), ['u1', 'r1', 't1', 't2']);
  });

  test(
    'intermediate AssistantText stays visible forever while only tool stretches compact',
    () {
      final presentation = SessionTimelinePresentation();
      // Phase 1: work -> intermediate text -> more live work (no final text yet).
      final midTurn = [
        _user('u1'),
        _tool('t1', 'm1', kind: ToolKind.read),
        _tool('t2', 'm1', kind: ToolKind.shell),
        _text('a1', 'm2'),
        _tool('t3', 'm3', kind: ToolKind.search),
        _tool('t4', 'm3', kind: ToolKind.edit, status: ItemStatus.streaming),
      ];
      expect(_shape(presentation.project(midTurn, settled: false)), [
        'u1',
        'stretch(t1,t2)',
        'a1',
        't3',
        't4',
      ]);
      // Phase 2: final answer begins arriving -> second stretch collapses too,
      // and BOTH intermediate a1 and final a2 stay visible forever.
      final withFinal = [
        ...midTurn.take(5),
        _tool('t4', 'm3', kind: ToolKind.edit),
        _text('a2', 'm4', complete: false),
      ];
      expect(_shape(presentation.project(withFinal, settled: false)), [
        'u1',
        'stretch(t1,t2)',
        'a1',
        'stretch(t3,t4)',
        'a2',
      ]);
      expect(_shape(presentation.project(withFinal, settled: true)), [
        'u1',
        'stretch(t1,t2)',
        'a1',
        'stretch(t3,t4)',
        'a2',
      ]);
    },
  );

  test('a reminder stays outside stretches in chronological order (#491)', () {
    Notice reminder(String id, ItemStatus status) => Notice(
      meta: _meta(id, status: status),
      kind: const OpenValue.known(NoticeKind.continuation),
      text: 'You are in Plan mode.',
    );
    for (final status in [ItemStatus.pending, ItemStatus.interrupted]) {
      final rows = SessionTimelinePresentation().project([
        ..._turn(),
        reminder('n1', status),
      ], settled: true);
      expect(_shape(rows), [
        'u1',
        'stretch(r1,t1,t2,t3)',
        'a1',
        'n1',
      ], reason: '$status');
    }
    final turn = _turn();
    final rows = SessionTimelinePresentation().project([
      ...turn.take(3),
      reminder('n2', ItemStatus.completed),
      ...turn.skip(3),
    ], settled: true);
    expect(_shape(rows), [
      'u1',
      'stretch(r1,t1)',
      'n2',
      'stretch(t2,t3)',
      'a1',
    ]);
  });

  test(
    'expanding a collapsed stretch reveals individual rows and survives rebuilds',
    () {
      final presentation = SessionTimelinePresentation();
      var rows = presentation.project(_turn(), settled: true);
      expect(_shape(rows), ['u1', 'stretch(r1,t1,t2,t3)', 'a1']);
      final stretch = rows[1] as SessionActivityStretchRow;
      expect(stretch.openingMessage?.message, MessageRef('m1'));
      expect(stretch.messageHeaders, [true, false, false, true]);

      presentation.toggle(stretch.id);
      rows = presentation.project(_turn(), settled: true);
      expect(_shape(rows), [
        'u1',
        'stretch(r1,t1,t2,t3,open)',
        'r1',
        't1',
        't2',
        't3',
        'a1',
      ]);
      // Expanded rows preserve per-item message headers.
      expect((rows[2] as SessionItemRow).messageHeader, isTrue);
      expect((rows[3] as SessionItemRow).messageHeader, isFalse);
      expect((rows[5] as SessionItemRow).messageHeader, isTrue);

      // Reader choice survives passive refresh under new generation.
      rows = presentation.project(_turn(generation: 'g2'), settled: true);
      expect((rows[1] as SessionActivityStretchRow).expanded, isTrue);

      // A fresh presentation starts collapsed.
      rows = SessionTimelinePresentation().project(_turn(), settled: true);
      expect(_shape(rows), ['u1', 'stretch(r1,t1,t2,t3)', 'a1']);
    },
  );

  test(
    'failed and background-running items surface on the stretch summary',
    () {
      final bgFacts = ToolRunFacts(
        shellId: 'sh_bg',
        background: true,
        shellStatus: const OpenValue.known(ShellStatus.running),
      );
      final failFacts = ToolRunFacts(
        exitCode: 1,
        shellStatus: const OpenValue.known(ShellStatus.exited),
      );
      final rows = SessionTimelinePresentation().project([
        _user('u1'),
        _tool('s1', 'm1', kind: ToolKind.shell, runFacts: bgFacts),
        _tool('s2', 'm1', kind: ToolKind.shell, runFacts: failFacts),
        _text('a1', 'm2', complete: false),
      ], settled: false);
      expect(_shape(rows), ['u1', 'stretch(s1,s2,run=1,fail=1)', 'a1']);
    },
  );

  test('failed TurnOutcome and Notices stay outside stretches', () {
    final rows = SessionTimelinePresentation().project([
      ..._turn(),
      TurnOutcome(
        meta: _meta('o1'),
        kind: const OpenValue.known(OutcomeKind.failed),
      ),
      Notice(
        meta: _meta('c1', status: ItemStatus.failed),
        kind: const OpenValue.known(NoticeKind.compaction),
        text: 'compaction failed',
      ),
    ], settled: true);
    expect(_shape(rows), ['u1', 'stretch(r1,t1,t2,t3)', 'a1', 'o1', 'c1']);
  });

  test('settled trailing stretch collapses and resists brief busy jitter', () {
    final items = [_user('u1'), _tool('t1', 'm1'), _tool('t2', 'm1')];
    final presentation = SessionTimelinePresentation();
    expect(_shape(presentation.project(items, settled: false)), [
      'u1',
      't1',
      't2',
    ]);
    final settledRows = presentation.project(items, settled: true);
    expect(_shape(settledRows), ['u1', 'stretch(t1,t2)']);
    // Brief busy pulse keeps settled trailing stretch closed.
    expect(_shape(presentation.project(items, settled: false)), [
      'u1',
      'stretch(t1,t2)',
    ]);
    // A new streaming item reopens the live tail.
    expect(
      _shape(
        presentation.project([
          ...items,
          _tool('t3', 'm2', status: ItemStatus.streaming),
        ], settled: false),
      ),
      ['u1', 't1', 't2', 't3'],
    );
  });

  test('subagent calls stay outside stretches and keep original adjacency', () {
    final items = [
      _user('u1'),
      _tool('t1', 'm1'),
      _tool('s1', 'm1', kind: ToolKind.subagent),
      _tool('s2', 'm1', kind: ToolKind.subagent),
      _think('r1', 'm1'),
      _tool('s3', 'm1', kind: ToolKind.subagent),
      _text('a1', 'm2'),
    ];
    final rows = SessionTimelinePresentation().project(
      items,
      settled: true,
      showReasoning: false,
    );
    expect(_shape(rows), [
      'u1',
      'stretch(t1)',
      'agents(s1,s2)',
      'agents(s3)',
      'a1',
    ]);
  });

  test(
    'hidden reasoning and calls leave no row and no empty stretch (#108)',
    () {
      final presentation = SessionTimelinePresentation();
      List<String> shape({bool reasoning = true, bool tools = true}) => _shape(
        presentation.project(
          _turn(),
          settled: true,
          showReasoning: reasoning,
          showToolCalls: tools,
        ),
      );
      expect(shape(tools: false), ['u1', 'stretch(r1)', 'a1']);
      expect(shape(reasoning: false), ['u1', 'stretch(t1,t2,t3)', 'a1']);
      expect(shape(reasoning: false, tools: false), ['u1', 'a1']);
      final rows = presentation.project(
        _turn(),
        settled: true,
        showReasoning: false,
      );
      expect((rows[1] as SessionActivityStretchRow).messageHeaders, [
        true,
        false,
        true,
      ]);
    },
  );

  test(
    'Block render mode holds unfinished answers and does not collapse before heldText (#284)',
    () {
      final presentation = SessionTimelinePresentation();
      List<String> block(List<TimelineItem> items, {bool settled = false}) =>
          _shape(
            presentation.project(
              items,
              settled: settled,
              renderMode: ChatRenderMode.block,
            ),
          );
      final inFlight = [
        _user('u1'),
        _think('r1', 'm1', ended: true),
        _tool('t1', 'm1', ended: true),
        _tool('t2', 'm1', ended: true),
        _text('x1', 'm2', complete: false),
        _tool('t3', 'm2'),
        _tool('t4', 'm2', status: ItemStatus.streaming),
      ];
      // x1 is held (not visible yet), so r1/t1/t2 do NOT collapse in Block mode!
      expect(block(inFlight), ['u1', 'r1', 't1', 't2', 't3', 'pending(u1)']);
      // Without expanded tools, the published work and a call that ended
      // early are summaries too (#537).
      expect(
        _shape(
          SessionTimelinePresentation().project(
            inFlight,
            settled: false,
            renderMode: ChatRenderMode.block,
            expandTools: false,
          ),
        ),
        ['u1', 'stretch(r1,t1,t2)', 'stretch(t3)', 'pending(u1)'],
      );
      expect(
        SessionTimelinePresentation.heldText(
          inFlight,
          settled: false,
          renderMode: ChatRenderMode.block,
        ),
        {const ItemId('x1')},
      );
      // In Live mode x1 IS visible, so r1/t1/t2 DO collapse before x1.
      expect(_shape(presentation.project(inFlight, settled: false)), [
        'u1',
        'stretch(r1,t1,t2)',
        'x1',
        't3',
        't4',
      ]);
      // A published intermediate ended answer DOES collapse the stretch before it in Block mode.
      final withPublishedIntermediate = [
        _user('u1'),
        _tool('t1', 'm1', ended: true),
        _text('a1', 'm2', ended: true),
        _tool('t2', 'm3', ended: true),
        _text('x2', 'm4', complete: false),
      ];
      expect(block(withPublishedIntermediate), [
        'u1',
        'stretch(t1)',
        'a1',
        't2',
        'pending(u1)',
      ]);
      // Prompt waiting for its first answer keeps pending row.
      expect(block([_user('u1')]), ['u1', 'pending(u1)']);
      // Settled Block mode collapses identically to Live.
      expect(block(_turn(), settled: true), [
        'u1',
        'stretch(r1,t1,t2,t3)',
        'a1',
      ]);
    },
  );

  test(
    'unknown-status ShellRun is excluded from compaction so history minimizes it',
    () {
      final unknownShell = ShellRun(
        meta: _meta('sh_u', message: 'm1'),
        command: 'echo hi',
        shellStatus: OpenValue.unknown('custom_state'),
      );
      final rows = SessionTimelinePresentation().project([
        _user('u1'),
        _tool('t1', 'm1'),
        unknownShell,
        _tool('t2', 'm1'),
        _text('a1', 'm2'),
      ], settled: true);
      expect(_shape(rows), ['u1', 'stretch(t1)', 'sh_u', 'stretch(t2)', 'a1']);
    },
  );

  test(
    'empty or whitespace AssistantText does not prematurely collapse a stretch',
    () {
      final emptyAnswer = AssistantText(
        meta: _meta('a0', message: 'm2', status: ItemStatus.streaming),
        text: '   \n\t  ',
        complete: false,
      );
      final rows = SessionTimelinePresentation().project([
        _user('u1'),
        _tool('t1', 'm1'),
        emptyAnswer,
      ], settled: false);
      expect(_shape(rows), ['u1', 't1', 'a0']);
    },
  );

  test(
    'failed/interrupted ToolCall with running runFacts is never active and Block mode keeps running shell calls live',
    () {
      final runningFacts = ToolRunFacts(
        shellId: 'sh_live',
        background: true,
        shellStatus: const OpenValue.known(ShellStatus.running),
      );
      final failedStale = _tool(
        'tf',
        'm1',
        status: ItemStatus.failed,
        kind: ToolKind.shell,
        runFacts: runningFacts,
      );
      final liveBg = _tool(
        'tb',
        'm1',
        status: ItemStatus.completed,
        kind: ToolKind.shell,
        runFacts: runningFacts,
      );
      final doneTool = _tool('td', 'm1');
      final liveRows = SessionTimelinePresentation().project([
        _user('u1'),
        failedStale,
        _text('a1', 'm2', complete: false),
      ], settled: false);
      expect(_shape(liveRows), ['u1', 'stretch(tf,fail=1)', 'a1']);

      // In Block mode, a completed ToolCall whose background shell is still
      // running is not treated as an ended call, unlike a finished call.
      final blockRows = SessionTimelinePresentation().project(
        [_user('u1'), doneTool, liveBg],
        settled: false,
        renderMode: ChatRenderMode.block,
      );
      expect(_shape(blockRows), ['u1', 'td', 'pending(u1)']);

      // Without message context, _ended also consults _running for ToolCall.
      final liveBgNoMsg = ToolCall(
        meta: _meta('tb2', status: ItemStatus.completed),
        kind: const OpenValue.known(ToolKind.shell),
        rawName: 'shell',
        runFacts: runningFacts,
      );
      final blockNoMsg = SessionTimelinePresentation().project(
        [_user('u1'), liveBgNoMsg],
        settled: false,
        renderMode: ChatRenderMode.block,
      );
      expect(_shape(blockNoMsg), ['u1', 'pending(u1)']);
    },
  );
}
