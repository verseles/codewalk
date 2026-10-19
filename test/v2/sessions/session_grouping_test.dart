import 'package:codewalk/features/sessions/session_grouping.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

SessionSummary _row(
  String id, {
  String? directory,
  String? upstream,
}) => SessionSummary(
  info: SessionInfo(
    ref: SessionRef(
      const HostId('host-a'),
      const HarnessInstanceId('native-a'),
      'ses_$id',
    ),
    title: 'Session $id',
    ownership: const OwnershipInfo.unknown(reason: 'test'),
    project: directory == null
        ? null
        : ProjectRef(
            const HostId('host-a'),
            directory,
            upstreamProjectId: upstream,
          ),
  ),
  updatedAt: DateTime.utc(2026, 10, 19),
);

void main() {
  test('the groups follow the first appearance of their first row', () {
    final groups = groupSessionsByProject([
      _row('a', directory: '/work/one'),
      _row('b', directory: '/work/two'),
      _row('c', directory: '/work/one'),
    ]);
    expect(groups, hasLength(2));
    expect(groups.first.project?.canonicalDirectory, '/work/one');
    expect(groups.last.project?.canonicalDirectory, '/work/two');
  });

  test('the rows inside a group keep the server order', () {
    final groups = groupSessionsByProject([
      _row('a', directory: '/work/one'),
      _row('b', directory: '/work/one'),
    ]);
    expect(groups, hasLength(1));
    expect(
      groups.single.sessions.map((session) => session.info.ref.nativeId),
      ['ses_a', 'ses_b'],
    );
  });

  test('the sessions the server did not attribute share one group', () {
    final groups = groupSessionsByProject([
      _row('a', directory: '/work/one'),
      _row('b'),
      _row('c'),
    ]);
    expect(groups, hasLength(2));
    expect(groups.first.project?.canonicalDirectory, '/work/one');
    expect(groups.last.project, isNull);
    expect(groups.last.sessions, hasLength(2));
  });

  test('the upstream project id never splits a group', () {
    final groups = groupSessionsByProject([
      _row('a', directory: '/work/one', upstream: 'prj_1'),
      _row('b', directory: '/work/one', upstream: 'prj_2'),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.sessions, hasLength(2));
  });

  test('the flat list is a header per group and then its rows', () {
    final items = sessionListItems([
      _row('a', directory: '/work/one'),
      _row('b', directory: '/work/two'),
    ]);
    expect(items, hasLength(4));
    expect(items[0], isA<SessionGroupHeader>());
    expect(items[1], isA<SessionRow>());
    expect(items[2], isA<SessionGroupHeader>());
    expect(items[3], isA<SessionRow>());
  });
}
