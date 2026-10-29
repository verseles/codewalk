import 'dart:convert';

import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/app/workspace_chrome_controller.dart';
import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_turn_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final class _FakePort implements SessionTurnActionPort {
  @override
  SessionTurnState state = const SessionTurnState();
  final List<ItemId> staged = [];
  MessageAnchor? nextAnchor;

  @override
  SessionTurnUnavailable? unavailable(SessionTurnAction action) => null;

  @override
  Future<SessionTurnResult> stage(ItemId boundary, {required CommandId id}) async {
    staged.add(boundary);
    state = SessionTurnState(
      phase: SessionTurnPhase.idle,
      revert: RevertState(
        kind: const OpenValue.known(RevertKind.staged),
        boundary: boundary,
        anchor: nextAnchor ??
            MessageAnchor(
              message: MessageRef('msg_2'),
              orderKey: 'msg_2',
            ),
      ),
    );
    return const SessionTurnResult(applied: true);
  }

  @override
  Future<SessionTurnResult> redoNext({required CommandId id}) async {
    state = const SessionTurnState();
    return const SessionTurnResult(applied: true, cleared: true);
  }

  @override
  Future<SessionTurnResult> redoAll({required CommandId id}) async {
    state = const SessionTurnState();
    return const SessionTurnResult(applied: true, cleared: true);
  }

  @override
  Future<SessionTurnResult> compact({required CommandId id}) async {
    return const SessionTurnResult(applied: true);
  }

  @override
  Future<void> refresh() async {}
}

UserInput _turn(
  String message, {
  required SessionRef ref,
  String? text,
  bool confirmed = true,
}) =>
    UserInput(
      meta: ItemMeta(
        id: ItemId(jsonEncode([ref.storageKey, message, 'user', 0])),
        generation: 'history',
        status: const OpenValue.known(ItemStatus.completed),
        source: SourceProvenance(
          harness: ref.harnessRef,
          version: '2.0.22',
          nativeType: 'user',
        ),
        anchor: MessageAnchor(message: MessageRef(message), orderKey: message),
      ),
      text: text ?? 'text of $message',
      delivery: const OpenValue.known(DeliveryState.delivered),
      confirmed: confirmed,
    );

AssistantText _answer(
  String message, {
  required SessionRef ref,
  required String text,
}) =>
    AssistantText(
      meta: ItemMeta(
        id: ItemId(jsonEncode([ref.storageKey, message, 'assistant', 0])),
        generation: 'history',
        status: const OpenValue.known(ItemStatus.completed),
        source: SourceProvenance(
          harness: ref.harnessRef,
          version: '2.0.22',
          nativeType: 'assistant',
        ),
        anchor: MessageAnchor(message: MessageRef(message), orderKey: message),
      ),
      text: text,
      complete: true,
    );

void main() {
  testWidgets('timeline shows inline undo on latest user and rewind on older user',
      (tester) async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    final handle = directory.grant(ref, turnActions: port);
    await start;

    final user1 = _turn('msg_1', ref: ref, text: 'First user prompt');
    final ans1 = _answer('ans_1', ref: ref, text: 'First response');
    final user2 = _turn('msg_2', ref: ref, text: 'Second user prompt');
    final ans2 = _answer('ans_2', ref: ref, text: 'Second response');

    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(ref, items: [user1, ans1, user2, ans2]),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: SessionLivePage(controller: live),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check user 1 inline action: older confirmed user has "Rewind and edit from here"
    final olderBtn = find.byKey(ValueKey('user-turn-action-${user1.id.value}'));
    expect(olderBtn, findsOneWidget);
    final olderWidget = tester.widget<IconButton>(olderBtn);
    expect(olderWidget.tooltip, 'Rewind and edit from here');

    // Check user 2 inline action: latest confirmed user has "Undo this turn"
    final latestBtn = find.byKey(ValueKey('user-turn-action-${user2.id.value}'));
    expect(latestBtn, findsOneWidget);
    final latestWidget = tester.widget<IconButton>(latestBtn);
    expect(latestWidget.tooltip, 'Undo this turn');

    // Tap latest undo action
    port.nextAnchor = user2.meta.anchor;
    await tester.tap(latestBtn);
    await tester.pumpAndSettle();

    expect(port.staged, [user2.id]);
    expect(live.draft.text, 'Second user prompt');
  });

  testWidgets('timeline immediately filters staged cut items', (tester) async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final directory = LiveDirectory();
    final summary = CatalogSource(profile('a')).row('one');
    final ref = summary.info.ref;
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
    );
    addTearDown(live.dispose);

    final port = _FakePort();
    final start = live.start();
    final handle = directory.grant(ref, turnActions: port);
    await start;

    final user1 = _turn('msg_1', ref: ref, text: 'First user prompt');
    final ans1 = _answer('ans_1', ref: ref, text: 'First response');
    final user2 = _turn('msg_2', ref: ref, text: 'Second user prompt');
    final ans2 = _answer('ans_2', ref: ref, text: 'Second response');

    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(ref, items: [user1, ans1, user2, ans2]),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: SessionLivePage(controller: live),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First user prompt'), findsOneWidget);
    expect(find.text('Second user prompt'), findsOneWidget);

    // Stage undo on user2
    port.nextAnchor = user2.meta.anchor;
    await live.turn.stageUndo(target: user2);
    await tester.pumpAndSettle();

    // msg_2 and later items are now filtered from the timeline
    expect(find.text('First user prompt'), findsOneWidget);
    expect(find.text('Second user prompt'), findsNothing);
  });

  testWidgets('workspace header overflow shows turn actions when session is active',
      (tester) async {
    final rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    final selecting = rig.sessions.selectProfile('profile_a');
    final source = rig.sources.single;
    final row = source.row('one');
    source.respond([row]);
    await selecting;

    final directory = LiveDirectory();
    final ref = row.info.ref;
    final port = _FakePort();
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: row,
      directory: directory,
    );
    addTearDown(live.dispose);
    final start = live.start();
    directory.grant(ref, turnActions: port);
    await start;

    final tabs = SessionTabsController(
      catalog: rig.sessions,
      store: SessionTabsStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      ),
    );
    addTearDown(tabs.dispose);
    await tabs.initialize();

    final health = EndpointHealthController(
      hosts: rig.hosts,
      now: () => tester.binding.clock.now().toUtc(),
    );
    addTearDown(health.dispose);

    final chrome = WorkspaceChromeController(
      health: health,
      catalog: rig.sessions,
      tabs: tabs,
    );
    addTearDown(chrome.dispose);

    tabs.live(ref, () => live);
    chrome.locationChanged('/s/${ref.host.value}/${ref.nativeId}');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionsController?>.value(value: rig.sessions),
            ChangeNotifierProvider<WorkspaceChromeController?>.value(value: chrome),
          ],
          child: Scaffold(
            appBar: AppBar(
              actions: const [WorkspaceAppBarActions()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap more actions button
    await tester.tap(find.byKey(const ValueKey('workspace-actions')));
    await tester.pumpAndSettle();

    // Verify turn action items exist in the popup menu
    expect(find.byKey(const ValueKey('turn-menu-undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('turn-menu-redo-next')), findsOneWidget);
    expect(find.byKey(const ValueKey('turn-menu-redo-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('turn-menu-compact')), findsOneWidget);
  });
}
