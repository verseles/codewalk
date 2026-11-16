import 'dart:math';

import 'package:codewalk/features/sessions/session_grouping.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRef _ref(String id) => SessionRef(
  const HostId('host-a'),
  const HarnessInstanceId('native-a'),
  'ses_$id',
);

SessionSummary _row(
  String id, {
  String? directory,
  String? upstream,
  String? parent,
  String? fork,
}) => SessionSummary(
  info: SessionInfo(
    ref: _ref(id),
    lineage: SessionLineage(
      parent: parent == null ? null : _ref(parent),
      fork: fork == null ? null : ForkLineage(_ref(fork)),
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

/// The grouped list as text: `header:<dir>`, then `<id>` for each row.
List<String> _shape(List<SessionListItem> items) => [
  for (final item in items)
    switch (item) {
      SessionGroupHeader(:final group) =>
        'header:${group.project?.canonicalDirectory}',
      SessionRow(:final session) => session.info.ref.nativeId.substring(4),
    },
];

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
    expect(groups.single.sessions.map((session) => session.info.ref.nativeId), [
      'ses_a',
      'ses_b',
    ]);
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

  test('the flat list keeps the exact header and row sequence', () {
    final items = sessionListItems([
      _row('a', directory: '/work/one'),
      _row('b', directory: '/work/two'),
      _row('c', directory: '/work/one'),
    ]);
    expect(
      items.map(
        (item) => switch (item) {
          SessionGroupHeader(:final group) =>
            'header:${group.project?.canonicalDirectory}',
          SessionRow(:final session) => 'row:${session.info.ref.nativeId}',
        },
      ),
      [
        'header:/work/one',
        'row:ses_a',
        'row:ses_c',
        'header:/work/two',
        'row:ses_b',
      ],
    );
  });

  group('primary rows', () {
    test('rows without a lineage keep the grouped sequence', () {
      expect(
        _shape(
          sessionListItems([
            _row('a', directory: '/w'),
            _row('b', directory: '/w'),
          ]),
        ),
        ['header:/w', 'a', 'b'],
      );
    });

    test('a child is never drawn, even under its loaded parent', () {
      // The ids and the directory of the 2.0.22 capture
      // d/foreground-nested.json; the endpoint's newest-first order lists
      // the grandchild first.
      const dir = '/workspace/.cloud-runtime/opencode-v2/capture-d';
      const root = 'efa9a9492ffedN3lszVGGAkUUw';
      const child = 'efa9a8862ffeuHE62WQvAHpGJ6';
      const grandchild = 'efa9a7d56ffe4yJlWC4DcnBJII';
      expect(
        _shape(
          sessionListItems([
            _row(grandchild, directory: dir, parent: child),
            _row(child, directory: dir, parent: root),
            _row(root, directory: dir),
          ]),
        ),
        ['header:$dir', root],
      );
    });

    test('the roots keep the order and the position the server gave them', () {
      expect(
        _shape(
          sessionListItems([
            _row('x', directory: '/w'),
            _row('c', directory: '/w', parent: 'p'),
            _row('y', directory: '/w'),
            _row('p', directory: '/w'),
            _row('z', directory: '/w'),
          ]),
        ),
        ['header:/w', 'x', 'y', 'p', 'z'],
      );
    });

    test('the roots of one parent keep the server order among themselves', () {
      expect(
        _shape(
          sessionListItems([
            _row('c2', directory: '/w', parent: 'p'),
            _row('g', directory: '/w', parent: 'c1'),
            _row('p', directory: '/w'),
            _row('c1', directory: '/w', parent: 'p'),
          ]),
        ),
        ['header:/w', 'p'],
      );
    });

    test('a child whose parent is not loaded is not drawn either', () {
      expect(
        _shape(
          sessionListItems([
            _row('a', directory: '/w'),
            _row('c', directory: '/w', parent: 'gone'),
            _row('b', directory: '/w'),
          ]),
        ),
        ['header:/w', 'a', 'b'],
      );
    });

    test('a child never keeps its group when its parent sits in another', () {
      expect(
        _shape(
          sessionListItems([
            _row('c', directory: '/two', parent: 'p'),
            _row('p', directory: '/one'),
            _row('u', parent: 'p'),
          ]),
        ),
        ['header:/one', 'p'],
      );
    });

    test('a group whose sessions are all children is not shown', () {
      expect(
        _shape(
          sessionListItems([
            _row('c', directory: '/two', parent: 'p'),
            _row('p', directory: '/one'),
          ]),
        ),
        ['header:/one', 'p'],
      );
    });

    test('the sessions without a project are only their roots', () {
      expect(_shape(sessionListItems([_row('c', parent: 'p'), _row('p')])), [
        'header:null',
        'p',
      ]);
    });

    test('a fork is a new root, not a child', () {
      expect(
        _shape(
          sessionListItems([
            _row('f', directory: '/w', fork: 'a'),
            _row('a', directory: '/w'),
          ]),
        ),
        ['header:/w', 'f', 'a'],
      );
    });

    test('a row whose lineage names a parent is a child, even in a loop', () {
      // A lineage that loops still names a parent, so it is a child: the
      // rule never invents a root, and the group holds no primary row.
      expect(
        _shape(sessionListItems([_row('s', directory: '/w', parent: 's')])),
        isEmpty,
      );
      expect(
        _shape(
          sessionListItems([
            _row('a', directory: '/w', parent: 'b'),
            _row('x', directory: '/w'),
            _row('b', directory: '/w', parent: 'a'),
          ]),
        ),
        ['header:/w', 'x'],
      );
    });

    test('with one group open, the others show their header alone', () {
      expect(
        _shape(
          sessionListItems(
            [
              _row('a', directory: '/one'),
              _row('c', directory: '/one', parent: 'a'),
              _row('b', directory: '/two'),
            ],
            open: (project: const ProjectRef(HostId('host-a'), '/one')),
          ),
        ),
        ['header:/one', 'a', 'header:/two'],
      );
    });

    test('every primary row is drawn exactly once, in the server order', () {
      final random = Random(397);
      const directories = ['/one', '/two', null];
      for (var run = 0; run < 300; run++) {
        final count = 1 + random.nextInt(40);
        final rows = [
          for (var i = 0; i < count; i++)
            _row(
              'r$i',
              directory: directories[random.nextInt(3)],
              parent: switch (random.nextInt(4)) {
                0 => null,
                1 => 'r${random.nextInt(count)}',
                2 => 'gone$i',
                _ => 'r$i',
              },
            ),
        ];
        final items = sessionListItems(rows);
        final drawn = items.whereType<SessionRow>().toList();
        expect(
          drawn.map((row) => row.session.info.ref).toList()..sort(_byId),
          [
            for (final row in rows)
              if (row.info.lineage.parent == null) row.info.ref,
          ]..sort(_byId),
        );
        // Each group that holds a primary row is shown, once, and its rows
        // keep the order the server gave them.
        var expectedGroup = -1;
        final groups = groupSessionsByProject(rows);
        final shown = items.whereType<SessionGroupHeader>().toList();
        expect(shown, hasLength(groups.where(_holdsPrimary).length));
        for (final item in items) {
          if (item is SessionGroupHeader) {
            expectedGroup++;
            while (!_holdsPrimary(groups[expectedGroup])) {
              expectedGroup++;
            }
            expect(item.group.project, groups[expectedGroup].project);
            continue;
          }
          final row = item as SessionRow;
          final info = row.session.info;
          expect(info.project, groups[expectedGroup].project);
          expect(info.lineage.parent, isNull);
        }
      }
    });
  });
}

bool _holdsPrimary(SessionGroup group) =>
    group.sessions.any((session) => session.info.lineage.parent == null);

int _byId(SessionRef a, SessionRef b) => a.nativeId.compareTo(b.nativeId);
