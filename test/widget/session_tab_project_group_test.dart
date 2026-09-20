import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/widgets/session_tab_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

SessionTabRecord tab(
  String sessionId,
  String directory, {
  bool isSelected = false,
}) {
  return SessionTabRecord(
    identity: SessionTabIdentity(
      serverId: 'srv_test',
      directory: directory,
      sessionId: sessionId,
    ),
    title: 'Session $sessionId',
    lastOpenedAtMs: 0,
    serverUpdatedAtMs: 0,
    status: SessionStatusType.idle,
    isSelected: isSelected,
  );
}

Widget app({
  required List<SessionTabRecord> tabs,
  void Function(SessionTabRecord)? onNewChat,
}) {
  return localizedMaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 800,
          child: SessionTabStrip(
            tabs: tabs,
            projects: const [],
            openProjectIds: const {},
            isCompact: false,
            onActivate: (_) {},
            onClose: (_) {},
            onContextMenu: (tab, position, {required haptic}) async {},
            trailingBuilder: (context, tab) => null,
            onNewChatForProject: onNewChat == null
                ? null
                : (anchor) => onNewChat(anchor),
          ),
        ),
      ),
    ),
  );
}

String addKey(SessionTabRecord t) =>
    'session_tab_new_${sessionTabIdentityKey(t.identity)}';

void main() {
  testWidgets('groups same-project tabs and renders one + per group', (
    tester,
  ) async {
    final a1 = tab('a1', '/a');
    final b1 = tab('b1', '/b');
    final a2 = tab('a2', '/a');
    await tester.pumpWidget(app(tabs: [a1, b1, a2], onNewChat: (_) {}));
    await tester.pump();

    // Visual order: a1, a2, +a, b1, +b.
    final dx = <String, double>{
      for (final t in [a1, a2, b1])
        t.identity.sessionId: tester
            .getCenter(
              find.byKey(
                ValueKey('session_tab_${sessionTabIdentityKey(t.identity)}'),
              ),
            )
            .dx,
    };
    expect(dx['a1'], lessThan(dx['a2']!));
    expect(dx['a2'], lessThan(dx['b1']!));
    expect(find.byKey(ValueKey(addKey(a2))), findsOneWidget);
    expect(find.byKey(ValueKey(addKey(b1))), findsOneWidget);
    expect(find.byKey(ValueKey(addKey(a1))), findsNothing);
  });

  testWidgets('tapping + reports the group anchor', (tester) async {
    final a1 = tab('a1', '/a');
    final b1 = tab('b1', '/b');
    SessionTabRecord? tapped;
    await tester.pumpWidget(
      app(tabs: [a1, b1], onNewChat: (anchor) => tapped = anchor),
    );
    await tester.pump();

    await tester.tap(find.byKey(ValueKey(addKey(b1))));
    expect(tapped?.identity.sessionId, 'b1');
  });

  testWidgets('draft group renders no +', (tester) async {
    final draft = tab('', '/a', isSelected: true);
    final b1 = tab('b1', '/b');
    await tester.pumpWidget(app(tabs: [draft, b1], onNewChat: (_) {}));
    await tester.pump();

    expect(find.byKey(ValueKey(addKey(b1))), findsOneWidget);
    // No + keyed on the draft anchor.
    expect(find.byKey(ValueKey(addKey(draft))), findsNothing);
  });

  testWidgets('no + when callback is null', (tester) async {
    final a1 = tab('a1', '/a');
    final b1 = tab('b1', '/b');
    await tester.pumpWidget(app(tabs: [a1, b1]));
    await tester.pump();

    expect(find.byKey(ValueKey(addKey(a1))), findsNothing);
    expect(find.byKey(ValueKey(addKey(b1))), findsNothing);
  });
}
