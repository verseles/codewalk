import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/widgets/session_tab_strip.dart';
import 'package:codewalk/presentation/widgets/session_tab_switcher_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

SessionTabRecord tab(String id, {bool isSelected = false}) {
  return SessionTabRecord(
    identity: SessionTabIdentity(
      serverId: 'srv',
      directory: '/repo',
      sessionId: 'ses_$id',
    ),
    title: 'Session $id',
    lastOpenedAtMs: 0,
    serverUpdatedAtMs: 0,
    status: SessionStatusType.idle,
    isSelected: isSelected,
  );
}

void main() {
  testWidgets('renders MRU titles with preview highlight and semantics',
      (tester) async {
    final tabs = <SessionTabRecord>[
      tab('a', isSelected: true),
      tab('b'),
      tab('c'),
    ];
    var selected = -1;
    await pumpLocalizedApp(
      tester,
      child: SessionTabSwitcherOverlay(
        tabs: tabs,
        previewIndex: 1,
        projects: const [],
        onSelect: (index) => selected = index,
        onDismiss: () {},
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('session_tab_switcher_overlay')),
      findsOneWidget,
    );
    expect(find.text('Session a'), findsOneWidget);
    expect(find.text('Session b'), findsOneWidget);
    expect(find.text('Session c'), findsOneWidget);
    final bKey = sessionTabIdentityKey(tabs[1].identity);
    expect(
      find.byKey(ValueKey<String>('session_tab_switcher_highlight_$bKey')),
      findsOneWidget,
    );

    await tester.tap(find.text('Session c'));
    await tester.pump();
    expect(selected, 2);
  });

  testWidgets('barrier tap dismisses without selecting', (tester) async {
    var dismissed = false;
    await pumpLocalizedApp(
      tester,
      child: SessionTabSwitcherOverlay(
        tabs: <SessionTabRecord>[tab('a', isSelected: true), tab('b')],
        previewIndex: 1,
        projects: const [],
        onSelect: (_) {},
        onDismiss: () => dismissed = true,
      ),
    );
    await tester.pump();

    // Tap a corner outside the centered card so the barrier (not a list
    // row) receives the pointer.
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(dismissed, isTrue);
  });
}
