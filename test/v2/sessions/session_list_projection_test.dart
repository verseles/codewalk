import 'package:codewalk/features/sessions/session_list_projection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _host = HostId('profile_a');
const _harness = HarnessInstanceId('profile_a');
SessionRef _ref(String id) => SessionRef(_host, _harness, 'ses_$id');

SessionSummary _row(
  String id, {
  String? title,
  String? parent,
  String? directory,
  int? updated,
  int? created,
  SessionViewMarker? view,
  SessionOutcome? outcome,
}) => SessionSummary(
  info: SessionInfo(
    ref: _ref(id),
    title: title ?? id,
    ownership: const OwnershipInfo.unknown(reason: 'test'),
    project: directory == null ? null : ProjectRef(_host, directory),
    lineage: SessionLineage(parent: parent == null ? null : _ref(parent)),
  ),
  updatedAt: updated == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true),
  createdAt: created == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
  view: view,
  outcome: outcome,
);

List<String> _ids(Iterable<SessionSummary> rows) => [
  for (final row in rows) row.info.ref.nativeId.substring(4),
];

void main() {
  test('search keeps title matches and pins lead; children never appear', () {
    final rows = [
      _row('a', title: 'Fix login', updated: 3),
      _row('b', title: 'Write docs', updated: 5),
      _row('c', title: 'fix tests', parent: 'b', updated: 4),
      _row('d', title: 'FIX build', updated: 1),
    ];
    final pinned = {_ref('d')};
    final searched = projectSessionList(
      rows,
      query: '  fix ',
      pinned: (row) => pinned.contains(row.info.ref),
    );
    expect(_ids(searched.map((e) => e.session)), ['d', 'a']);
    final all = projectSessionList(
      rows,
      query: '',
      pinned: (row) => pinned.contains(row.info.ref),
    );
    expect(_ids(all.map((e) => e.session)), ['d', 'b', 'a']);
    expect(all.any((row) => row.session.info.lineage.parent != null), isFalse);
  });

  test('sorts by most recent update; missing times keep order', () {
    final rows = [
      _row('x', title: 'beta', updated: 2, created: 20),
      _row('y', title: 'Alpha', updated: null, created: 10),
      _row('z', title: 'gamma', updated: 9, created: null),
      _row('w', title: 'alpha', updated: null, created: 30),
    ];
    expect(_ids(sortSessionsByRecent(rows)), ['z', 'x', 'y', 'w']);
  });

  test('recent caps at two roots per project without a global limit of five', () {
    final rows = [
      // Project /a has 4 roots (plus a duplicate of a3, a child, and a timeless row).
      _row('a0', directory: '/a', updated: 10),
      _row('a1', directory: '/a', updated: 20),
      _row('a2', directory: '/a', updated: 30),
      _row('a3', directory: '/a', updated: 40),
      _row('a3', directory: '/a', updated: 35),
      _row('a-child', directory: '/a', parent: 'a3', updated: 99),
      _row('a-timeless', directory: '/a'),
      // Project /b has 3 roots.
      _row('b0', directory: '/b', updated: 15),
      _row('b1', directory: '/b', updated: 25),
      _row('b2', directory: '/b', updated: 35),
      // Project /c has 3 roots.
      _row('c0', directory: '/c', updated: 12),
      _row('c1', directory: '/c', updated: 22),
      _row('c2', directory: '/c', updated: 32),
      // Project /d has 1 root.
      _row('d0', directory: '/d', updated: 5),
    ];
    final recent = recentSessions(rows);
    expect(_ids(recent), ['a3', 'b2', 'c2', 'a2', 'b1', 'c1', 'd0']);
    expect(recentSessions(rows, perProjectLimit: 0), isEmpty);
  });

  test(
    'roots that need attention lead Recent, honoring the per-project cap',
    () {
      final rows = [
        _row(
          'p-older-waiting',
          directory: '/p',
          updated: DateTime.utc(2026, 10, 26, 8).millisecondsSinceEpoch,
        ),
        _row(
          'p-newest',
          directory: '/p',
          updated: DateTime.utc(2026, 10, 26, 12).millisecondsSinceEpoch,
        ),
        _row(
          'p-second',
          directory: '/p',
          updated: DateTime.utc(2026, 10, 26, 11).millisecondsSinceEpoch,
        ),
        _row(
          'q-recent-waiting',
          directory: '/q',
          updated: DateTime.utc(2026, 10, 26, 10).millisecondsSinceEpoch,
        ),
        _row(
          'q-middle',
          directory: '/q',
          updated: DateTime.utc(2026, 10, 26, 9).millisecondsSinceEpoch,
        ),
        _row(
          'q-oldest',
          directory: '/q',
          updated: DateTime.utc(2026, 10, 26, 7).millisecondsSinceEpoch,
        ),
      ];
      final recent = recentSessions(
        rows,
        needsAttention: (row) => row.info.ref.nativeId.endsWith('waiting'),
      );
      // Both projects keep at most 2 rows: their waiting root plus their
      // newest remaining root, ordered attention-first then by update time.
      expect(_ids(recent), [
        'q-recent-waiting',
        'p-older-waiting',
        'p-newest',
        'q-middle',
      ]);
    },
  );

  test('a completed unread root is emphasized for one hour after idle', () {
    final idle = DateTime.utc(2026, 10, 26, 12);
    final unread = SessionViewMarker(idleAt: idle);
    final done = _row('done', view: unread, outcome: SessionOutcome.succeeded);
    expect(
      unreadEmphasized(done, now: idle.add(const Duration(minutes: 59))),
      isTrue,
    );
    expect(
      unreadEmphasized(done, now: idle.add(const Duration(hours: 1))),
      isFalse,
    );
    expect(unreadEmphasized(done, now: idle, current: _ref('done')), isFalse);
    for (final row in [
      _row('failed', view: unread, outcome: SessionOutcome.failed),
      _row(
        'child',
        parent: 'done',
        view: unread,
        outcome: SessionOutcome.succeeded,
      ),
      _row(
        'seen',
        view: SessionViewMarker(idleAt: idle, viewedAt: idle),
        outcome: SessionOutcome.succeeded,
      ),
      _row('unknown', view: unread),
    ]) {
      expect(
        unreadEmphasized(row, now: idle),
        isFalse,
        reason: row.info.ref.nativeId,
      );
    }
    expect(
      nextEmphasisEnd([done], now: idle.add(const Duration(minutes: 20))),
      const Duration(minutes: 40),
    );
    expect(
      nextEmphasisEnd([done], now: idle.add(const Duration(hours: 2))),
      isNull,
    );
  });
}
