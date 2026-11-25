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
  int? updated,
  int? created,
  SessionViewMarker? view,
  SessionOutcome? outcome,
}) => SessionSummary(
  info: SessionInfo(
    ref: _ref(id),
    title: title ?? id,
    ownership: const OwnershipInfo.unknown(reason: 'test'),
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

  test('recent lists at most five visible roots by update', () {
    final rows = [
      for (var i = 0; i < 7; i++) _row('r$i', updated: i),
      _row('child', parent: 'r6', updated: 99),
      _row('timeless'),
    ];
    final recent = recentSessions(rows);
    expect(_ids(recent), ['r6', 'r5', 'r4', 'r3', 'r2']);
  });

  test('roots that need attention lead Recent, each band by update', () {
    final rows = [
      _row(
        'older-waiting',
        updated: DateTime.utc(2026, 10, 26, 8).millisecondsSinceEpoch,
      ),
      _row(
        'newest',
        updated: DateTime.utc(2026, 10, 26, 12).millisecondsSinceEpoch,
      ),
      _row(
        'middle',
        updated: DateTime.utc(2026, 10, 26, 9).millisecondsSinceEpoch,
      ),
      _row(
        'recent-waiting',
        updated: DateTime.utc(2026, 10, 26, 10).millisecondsSinceEpoch,
      ),
    ];
    final recent = recentSessions(
      rows,
      needsAttention: (row) => row.info.ref.nativeId.endsWith('waiting'),
    );
    expect(_ids(recent), [
      'recent-waiting',
      'older-waiting',
      'newest',
      'middle',
    ]);
  });

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
