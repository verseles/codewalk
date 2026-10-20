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

/// The nested list as text: `header:<dir>`, then `<id>@<depth>`, with `!`
/// when the row's parent is not drawn above it.
List<String> _shape(List<SessionListItem> items) => [
  for (final item in items)
    switch (item) {
      SessionGroupHeader(:final group) =>
        'header:${group.project?.canonicalDirectory}',
      SessionRow(:final session, :final depth, :final parentElsewhere) =>
        '${session.info.ref.nativeId.substring(4)}@$depth'
            '${parentElsewhere ? '!' : ''}',
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

  group('nesting', () {
    test('rows without a lineage keep the grouped sequence', () {
      expect(
        _shape(
          sessionListItems([
            _row('a', directory: '/w'),
            _row('b', directory: '/w'),
          ]),
        ),
        ['header:/w', 'a@0', 'b@0'],
      );
    });

    test('the recorded three-level lineage nests recursively', () {
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
        ['header:$dir', '$root@0', '$child@1', '$grandchild@2'],
      );
    });

    test('the parent stays where the server put it', () {
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
        ['header:/w', 'x@0', 'y@0', 'p@0', 'c@1', 'z@0'],
      );
    });

    test('the siblings keep the server order under their parent', () {
      expect(
        _shape(
          sessionListItems([
            _row('c2', directory: '/w', parent: 'p'),
            _row('g', directory: '/w', parent: 'c1'),
            _row('p', directory: '/w'),
            _row('c1', directory: '/w', parent: 'p'),
          ]),
        ),
        ['header:/w', 'p@0', 'c2@1', 'c1@1', 'g@2'],
      );
    });

    test(
      'a child whose parent is not loaded stays where the server put it',
      () {
        expect(
          _shape(
            sessionListItems([
              _row('a', directory: '/w'),
              _row('c', directory: '/w', parent: 'gone'),
              _row('b', directory: '/w'),
            ]),
          ),
          ['header:/w', 'a@0', 'c@0!', 'b@0'],
        );
      },
    );

    test('a child never leaves the group the server attributed it to', () {
      expect(
        _shape(
          sessionListItems([
            _row('c', directory: '/two', parent: 'p'),
            _row('p', directory: '/one'),
            _row('u', parent: 'p'),
          ]),
        ),
        ['header:/two', 'c@0!', 'header:/one', 'p@0', 'header:null', 'u@0!'],
      );
    });

    test('the sessions without a project nest among themselves', () {
      expect(_shape(sessionListItems([_row('c', parent: 'p'), _row('p')])), [
        'header:null',
        'p@0',
        'c@1',
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
        ['header:/w', 'f@0', 'a@0'],
      );
    });

    test('every row of a lineage that loops stays where the server put it', () {
      expect(
        _shape(sessionListItems([_row('s', directory: '/w', parent: 's')])),
        ['header:/w', 's@0!'],
      );
      expect(
        _shape(
          sessionListItems([
            _row('a', directory: '/w', parent: 'b'),
            _row('x', directory: '/w'),
            _row('b', directory: '/w', parent: 'a'),
          ]),
        ),
        ['header:/w', 'a@0!', 'x@0', 'b@0!'],
      );
      // A row that hangs off the loop still nests under its own parent.
      expect(
        _shape(
          sessionListItems([
            _row('t', directory: '/w', parent: 'b'),
            _row('a', directory: '/w', parent: 'c'),
            _row('b', directory: '/w', parent: 'a'),
            _row('c', directory: '/w', parent: 'b'),
          ]),
        ),
        ['header:/w', 'a@0!', 'b@0!', 't@1', 'c@0!'],
      );
    });

    test('the depth has no cap in the model', () {
      final rows = [
        for (var i = 5; i >= 0; i--)
          _row('n$i', directory: '/w', parent: i == 0 ? null : 'n${i - 1}'),
      ];
      expect(_shape(sessionListItems(rows)), [
        'header:/w',
        for (var i = 0; i <= 5; i++) 'n$i@$i',
      ]);
    });

    test('every loaded row is drawn exactly once under its own parent', () {
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
          rows.map((row) => row.info.ref).toList()..sort(_byId),
        );
        final groups = groupSessionsByProject(rows);
        expect(items.whereType<SessionGroupHeader>(), hasLength(groups.length));
        var header = -1;
        final stack = <SessionRef>[];
        for (final item in items) {
          if (item is SessionGroupHeader) {
            header++;
            stack.clear();
            continue;
          }
          final row = item as SessionRow;
          final info = row.session.info;
          expect(info.project, groups[header].project);
          expect(
            row.parentElsewhere,
            row.depth == 0 && info.lineage.parent != null,
          );
          stack.length = row.depth;
          if (row.depth > 0) expect(stack.last, info.lineage.parent);
          stack.add(info.ref);
        }
      }
    });
  });
}

int _byId(SessionRef a, SessionRef b) => a.nativeId.compareTo(b.nativeId);
