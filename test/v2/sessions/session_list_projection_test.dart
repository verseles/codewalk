import 'package:codewalk/features/sessions/session_grouping.dart';
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

  test('the latest update counts children too (#534)', () {
    expect(latestSessionUpdate(const []), isNull);
    expect(latestSessionUpdate([_row('a')]), isNull);
    final latest = latestSessionUpdate([
      _row('a', updated: 10),
      _row('b', updated: 30),
      _row('child', parent: 'a', updated: 99),
      _row('c'),
    ]);
    // A child at work is activity in its project.
    expect(latest, DateTime.fromMillisecondsSinceEpoch(99, isUtc: true));
  });

  test('the drawer lists the active project first, then by activity', () {
    DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final activity = <String, DateTime?>{
      '/a': at(10),
      '/b': at(30),
      '/c': null,
      '/d': at(30),
      '/e': at(20),
      '/f': null,
    };
    final order = projectDrawerOrder(
      ['/a', '/b', '/c', '/d', '/e', '/f'],
      active: '/e',
      activity: (directory) => activity[directory],
    );
    // The active one leads whatever its activity; a tie keeps the opening
    // order, and the projects without activity close the list in it too.
    expect(order, ['/e', '/b', '/d', '/a', '/c', '/f']);
    expect(
      projectDrawerOrder(['/a', '/b'], active: null, activity: (_) => null),
      ['/a', '/b'],
    );
    expect(projectDrawerOrder(['/a'], active: '/gone', activity: (_) => null), [
      '/a',
    ]);
  });

  test('the active project shows five rows and the current one', () {
    List<SessionRow> rows(int count) => [
      for (var i = 0; i < count; i++) SessionRow(_row('r$i', updated: 100 - i)),
    ];
    List<String> ids(List<SessionRow> rows) => _ids(rows.map((r) => r.session));

    final eight = activeProjectWindow(rows(8));
    expect(ids(eight.shown), ['r0', 'r1', 'r2', 'r3', 'r4']);
    expect(eight.hidden, 3);

    final five = activeProjectWindow(rows(5));
    expect(five.shown, hasLength(5));
    expect(five.hidden, 0);

    // The conversation on screen takes the last place, never a sixth.
    final current = activeProjectWindow(rows(8), current: _ref('r6'));
    expect(ids(current.shown), ['r0', 'r1', 'r2', 'r3', 'r6']);
    expect(current.hidden, 3);
    final within = activeProjectWindow(rows(8), current: _ref('r2'));
    expect(ids(within.shown), ['r0', 'r1', 'r2', 'r3', 'r4']);
    final absent = activeProjectWindow(rows(8), current: _ref('gone'));
    expect(absent.shown, hasLength(5));
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
