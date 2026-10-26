import 'package:codewalk/features/sessions/session_tab_reconciler.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _host = HostId('a');
const _hour = 3600 * 1000;
const _now = 100 * _hour;

SessionRef _ref(String id, {String host = 'a'}) =>
    SessionRef(HostId(host), HarnessInstanceId(host), id);

SessionSummary _row(
  String id, {
  int? updated,
  String directory = '/work',
  String? parent,
  String host = 'a',
}) => SessionSummary(
  info: SessionInfo(
    ref: _ref(id, host: host),
    title: id,
    ownership: const OwnershipInfo.unknown(reason: 'not observed'),
    project: ProjectRef(HostId(host), directory),
    lineage: SessionLineage(parent: parent == null ? null : _ref(parent)),
  ),
  updatedAt: updated == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(updated),
);

SessionTabCandidate _candidate(
  SessionSummary row, {
  bool hidden = false,
  bool pinned = false,
  bool? busy = false,
}) => SessionTabCandidate(row: row, hidden: hidden, pinned: pinned, busy: busy);

Map<SessionRef, SessionTabCandidate> _known(
  Iterable<SessionTabCandidate> candidates,
) => {for (final c in candidates) c.row.info.ref: c};

SessionTab _tab(String id, {int opened = 0, int? updated, String? host}) =>
    SessionTab(
      ref: _ref(id, host: host ?? 'a'),
      project: ProjectRef(HostId(host ?? 'a'), '/work'),
      title: id,
      lastOpenedAtMs: opened,
      updatedAtMs: updated,
    );

SessionTabReconciliation _run(
  SessionTabsState state,
  Iterable<SessionTabCandidate> candidates, {
  Set<String> fallbacks = const {},
  Set<String> known = const {'/work'},
  Set<SessionRef> frozen = const {},
}) => reconcileSessionTabs(
  state: state,
  host: _host,
  nowMs: _now,
  candidates: _known(candidates),
  fallbacks: fallbacks,
  knownDirectories: known,
  frozen: frozen,
);

List<String> _ids(SessionTabsState? state) => [
  for (final tab in state!.tabs) tab.ref.nativeId,
];

void main() {
  const window = 3 * _hour;

  test('a session updated within three hours gets a tab, an older one not', () {
    final result = _run(SessionTabsState(), [
      _candidate(_row('edge', updated: _now - window)),
      _candidate(_row('inside', updated: _now - window + 1)),
      _candidate(_row('unknown')),
    ]);
    expect(_ids(result.state), ['inside']);
    expect(result.state!.tabs.single.lastOpenedAtMs, 0);
    expect(result.nextExpiryMs, _now + 1);
  });

  test('an idle tab leaves exactly when its window ends', () {
    final tab = _tab('s', opened: _now - window + 5, updated: 1);
    final state = SessionTabsState(tabs: [tab]);
    final row = _row('s', updated: 1);
    final kept = _run(state, [_candidate(row)]);
    expect(kept.state, isNull);
    expect(kept.nextExpiryMs, _now + 5);
    final later = reconcileSessionTabs(
      state: state,
      host: _host,
      nowMs: _now + 5,
      candidates: _known([_candidate(row)]),
    );
    expect(_ids(later.state), isEmpty);
  });

  test('a selected, busy, pinned or unknown-activity tab stays', () {
    final old = [
      for (final id in ['sel', 'busy', 'pin', 'unknown']) _tab(id),
    ];
    final state = SessionTabsState(tabs: old, selected: {_host: _ref('sel')});
    final result = _run(state, [
      _candidate(_row('sel', updated: 1)),
      _candidate(_row('busy', updated: 1), busy: true),
      _candidate(_row('pin', updated: 1), pinned: true),
      _candidate(_row('unknown', updated: 1), busy: null),
    ]);
    // Only the update is recorded; nothing leaves and nothing expires.
    expect(_ids(result.state), ['sel', 'busy', 'pin', 'unknown']);
    expect(result.nextExpiryMs, isNull);
  });

  test('a tab whose session is not loaded proves nothing and stays', () {
    final state = SessionTabsState(tabs: [_tab('s')]);
    final result = _run(state, const []);
    expect(result.state, isNull);
  });

  test('a recent update of a tab is recorded without reordering', () {
    final state = SessionTabsState(
      tabs: [
        _tab('b', opened: _now - 10),
        _tab('a', opened: _now - 20),
      ],
    );
    final result = _run(state, [
      _candidate(_row('a', updated: _now - 1)),
      _candidate(_row('b', updated: _now - 2)),
    ]);
    expect(_ids(result.state), ['b', 'a']);
    expect(result.state!.tabs.last.updatedAtMs, _now - 1);
  });

  test('hidden and child sessions are not added; a hidden tab leaves unless '
      'selected', () {
    final state = SessionTabsState(
      tabs: [
        _tab('hidden', opened: _now - 1),
        _tab('shown', opened: _now - 1),
      ],
      selected: {_host: _ref('shown')},
    );
    final result = _run(state, [
      _candidate(_row('hidden', updated: _now), hidden: true),
      _candidate(_row('shown', updated: _now), hidden: true),
      _candidate(_row('child', updated: _now, parent: 'shown')),
      _candidate(_row('other', updated: _now), hidden: true, pinned: true),
    ]);
    expect(_ids(result.state), ['shown']);
  });

  test('new tabs follow the kept ones, the most recent first', () {
    final state = SessionTabsState(tabs: [_tab('kept', opened: _now)]);
    final result = _run(state, [
      _candidate(_row('old', updated: _now - 30)),
      _candidate(_row('z', updated: _now - 10)),
      _candidate(_row('y', updated: _now - 10)),
      _candidate(_row('new', updated: _now - 1)),
    ]);
    expect(_ids(result.state), ['kept', 'new', 'y', 'z', 'old']);
  });

  test('a busy or pinned session gets a tab whatever its age', () {
    final result = _run(SessionTabsState(), [
      _candidate(_row('busy', updated: 1), busy: true),
      _candidate(_row('pin', updated: 1), pinned: true),
      _candidate(_row('idle', updated: 1)),
    ]);
    expect(_ids(result.state), unorderedEquals(['busy', 'pin']));
    expect(result.nextExpiryMs, isNull);
  });

  test('a full strip adds nothing and drops nothing', () {
    final full = [
      for (var i = 0; i < SessionTabsStore.maxTabs; i++)
        _tab('t$i', opened: _now),
    ];
    final result = _run(SessionTabsState(tabs: full), [
      _candidate(_row('new', updated: _now), pinned: true),
    ]);
    expect(result.state, isNull);
  });

  group('a closed session', () {
    SessionTabsState closed(String id, {int? updated}) => SessionTabsState(
      suppressed: [
        SessionTabSuppression(
          ref: _ref(id),
          project: const ProjectRef(_host, '/work'),
          closedAtMs: _now - 1,
          updatedAtMs: updated,
        ),
      ],
    );

    test('stays closed through a replay of the same update, even busy', () {
      final result = _run(closed('s', updated: _now - 5), [
        _candidate(_row('s', updated: _now - 5), busy: true),
      ]);
      expect(result.state, isNull);
    });

    test('comes back on a strictly newer update', () {
      final result = _run(closed('s', updated: _now - 5), [
        _candidate(_row('s', updated: _now - 4)),
      ]);
      expect(_ids(result.state), ['s']);
      expect(result.state!.suppressed, isEmpty);
    });

    test('without a known update takes the first one seen as its own', () {
      final first = _run(closed('s'), [
        _candidate(_row('s', updated: _now - 5)),
      ]);
      expect(_ids(first.state), isEmpty);
      expect(first.state!.suppressed.single.updatedAtMs, _now - 5);
      final again = _run(first.state!, [
        _candidate(_row('s', updated: _now - 5)),
      ]);
      expect(again.state, isNull);
      final newer = _run(first.state!, [
        _candidate(_row('s', updated: _now - 2)),
      ]);
      expect(_ids(newer.state), ['s']);
    });

    test('comes back when pinned, its close forgotten', () {
      final result = _run(closed('s', updated: _now - 5), [
        _candidate(_row('s', updated: 1), pinned: true),
      ]);
      expect(_ids(result.state), ['s']);
      expect(result.state!.suppressed, isEmpty);
    });
  });

  group('a project just opened', () {
    test('gets its most recent visible session once its rows are known', () {
      final rows = [
        _candidate(_row('older', updated: 10, directory: '/p')),
        _candidate(_row('hidden', updated: 30, directory: '/p'), hidden: true),
        _candidate(_row('child', updated: 40, directory: '/p', parent: 'x')),
        _candidate(_row('newest', updated: 20, directory: '/p')),
      ];
      final unknown = _run(
        SessionTabsState(),
        rows,
        fallbacks: {'/p'},
        known: const {},
      );
      expect(unknown.state, isNull);
      expect(unknown.consumed, isEmpty);
      final result = _run(
        SessionTabsState(),
        rows,
        fallbacks: {'/p'},
        known: {'/p'},
      );
      expect(_ids(result.state), ['newest']);
      expect(result.state!.tabs.single.lastOpenedAtMs, _now);
      expect(result.nextExpiryMs, _now + 3 * _hour);
      expect(result.consumed, {'/p'});
    });

    test('keeps the tabs it has and skips a closed session', () {
      final state = SessionTabsState(
        suppressed: [
          SessionTabSuppression(
            ref: _ref('closed'),
            project: const ProjectRef(_host, '/p'),
            closedAtMs: 1,
            updatedAtMs: 50,
          ),
        ],
      );
      final result = _run(
        state,
        [
          _candidate(_row('closed', updated: 50, directory: '/p')),
          _candidate(_row('next', updated: 20, directory: '/p')),
        ],
        fallbacks: {'/p'},
        known: {'/p'},
      );
      expect(_ids(result.state), ['next']);
      final recent = _run(
        SessionTabsState(),
        [
          _candidate(_row('recent', updated: _now, directory: '/p')),
          _candidate(_row('older', updated: 20, directory: '/p')),
        ],
        fallbacks: {'/p'},
        known: {'/p'},
      );
      expect(_ids(recent.state), ['recent']);
    });
  });

  test('tabs of another server and tabs being changed are left alone', () {
    final state = SessionTabsState(
      tabs: [
        _tab('frozen'),
        _tab('s', host: 'b'),
      ],
    );
    final result = _run(
      state,
      [
        _candidate(_row('frozen', updated: 1)),
        _candidate(_row('s', updated: 1, host: 'b')),
        _candidate(_row('closing', updated: _now)),
      ],
      frozen: {_ref('frozen'), _ref('closing')},
    );
    expect(result.state, isNull);
  });
}
