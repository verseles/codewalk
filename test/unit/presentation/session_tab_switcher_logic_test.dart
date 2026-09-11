import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/utils/session_tab_switcher_logic.dart';
import 'package:flutter_test/flutter_test.dart';

SessionTabRecord tab(
  String id, {
  int lastOpenedAtMs = 0,
  bool isSelected = false,
  bool invalid = false,
}) {
  return SessionTabRecord(
    identity: SessionTabIdentity(
      serverId: 'srv',
      directory: '/repo',
      sessionId: invalid ? '' : 'ses_$id',
    ),
    title: 'Session $id',
    lastOpenedAtMs: lastOpenedAtMs,
    serverUpdatedAtMs: 0,
    status: SessionStatusType.idle,
    isSelected: isSelected,
  );
}

void main() {
  group('orderTabsForSwitcher (MRU)', () {
    test('current tab anchors first, rest by recency desc', () {
      final tabs = <SessionTabRecord>[
        tab('a', lastOpenedAtMs: 10, isSelected: true),
        tab('b', lastOpenedAtMs: 30),
        tab('c', lastOpenedAtMs: 20),
      ];
      final ordered = orderTabsForSwitcher(tabs);
      expect(
        ordered.map((t) => t.identity.sessionId).toList(),
        <String>['ses_a', 'ses_b', 'ses_c'],
      );
    });

    test('ties preserve visual order', () {
      final tabs = <SessionTabRecord>[
        tab('a', isSelected: true),
        tab('b'),
        tab('c'),
      ];
      final ordered = orderTabsForSwitcher(tabs);
      expect(
        ordered.map((t) => t.identity.sessionId).toList(),
        <String>['ses_a', 'ses_b', 'ses_c'],
      );
    });

    test('invalid identities are excluded', () {
      final tabs = <SessionTabRecord>[
        tab('a', isSelected: true),
        tab('draft', invalid: true),
        tab('b', lastOpenedAtMs: 5),
      ];
      final ordered = orderTabsForSwitcher(tabs);
      expect(
        ordered.map((t) => t.identity.sessionId).toList(),
        <String>['ses_a', 'ses_b'],
      );
    });

    test('fewer than 2 valid tabs returns as-is', () {
      final ordered = orderTabsForSwitcher(<SessionTabRecord>[
        tab('a', isSelected: true),
      ]);
      expect(ordered.length, 1);
    });
  });

  group('switcher index math', () {
    test('forward starts at 1, reverse starts at last', () {
      expect(switcherInitialIndex(3, reverse: false), 1);
      expect(switcherInitialIndex(3, reverse: true), 2);
      expect(switcherInitialIndex(1, reverse: false), 0);
    });

    test('step wraps around both directions', () {
      expect(switcherStepIndex(2, 3, reverse: false), 0);
      expect(switcherStepIndex(0, 3, reverse: true), 2);
      expect(switcherStepIndex(1, 3, reverse: false), 2);
      expect(switcherStepIndex(1, 3, reverse: true), 0);
    });
  });
}
