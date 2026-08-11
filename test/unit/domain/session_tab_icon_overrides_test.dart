import 'dart:convert';

import 'package:codewalk/domain/entities/session_tab_icon_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips normalized full identities and unknown preset ids', () {
    final state = SessionTabIconOverridesState(
      entries: <SessionTabIconOverride>[
        SessionTabIconOverride(
          serverId: ' server-a ',
          directory: r'\work\project\',
          sessionId: ' session-a ',
          presetId: 'future-preset',
          updatedAtMs: 10,
        ),
      ],
    );

    final decoded = SessionTabIconOverridesState.decode(state.encode());

    expect(decoded.entries, hasLength(1));
    expect(decoded.entries.single.serverId, 'server-a');
    expect(decoded.entries.single.directory, '/work/project');
    expect(decoded.entries.single.sessionId, 'session-a');
    expect(decoded.entries.single.presetId, 'future-preset');
  });

  test('isolates same session id by server and directory', () {
    final entries = <SessionTabIconOverride>[
      SessionTabIconOverride(
        serverId: 'server-a',
        directory: '/work/a',
        sessionId: 'same',
        presetId: 'code',
        updatedAtMs: 1,
      ),
      SessionTabIconOverride(
        serverId: 'server-a',
        directory: '/work/b',
        sessionId: 'same',
        presetId: 'bug',
        updatedAtMs: 2,
      ),
      SessionTabIconOverride(
        serverId: 'server-b',
        directory: '/work/a',
        sessionId: 'same',
        presetId: 'cloud',
        updatedAtMs: 3,
      ),
    ];

    expect(
      SessionTabIconOverridesState(entries: entries).compacted().entries,
      hasLength(3),
    );
  });

  test('deduplicates newest and compacts deterministically', () {
    final entries = <SessionTabIconOverride>[
      for (var index = 0; index < 260; index++)
        SessionTabIconOverride(
          serverId: 'server-a',
          directory: '/work/$index',
          sessionId: 'session-$index',
          presetId: 'code',
          updatedAtMs: index,
        ),
      SessionTabIconOverride(
        serverId: 'server-a',
        directory: '/work/259',
        sessionId: 'session-259',
        presetId: 'bug',
        updatedAtMs: 999,
      ),
    ];

    final compacted = SessionTabIconOverridesState(
      entries: entries,
    ).compacted();

    expect(compacted.entries, hasLength(256));
    expect(compacted.entries.first.presetId, 'bug');
    expect(
      compacted.entries.map((entry) => entry.sessionId),
      isNot(contains('session-0')),
    );
  });

  test('drops malformed entries and corrupted payloads safely', () {
    final malformed = jsonEncode(<String, Object>{
      'version': 1,
      'entries': <Object>[
        <String, Object>{'serverId': 'server-a'},
        'invalid',
      ],
    });

    expect(SessionTabIconOverridesState.decode(malformed).entries, isEmpty);
    expect(SessionTabIconOverridesState.decode('{bad').entries, isEmpty);
    expect(
      SessionTabIconOverridesState.decode('{"version":2,"entries":[]}').entries,
      isEmpty,
    );
  });
}
