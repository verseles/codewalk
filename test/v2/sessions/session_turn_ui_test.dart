import 'dart:convert';

import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/app/workspace_chrome_controller.dart';
import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_turn_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final class _FakePort implements SessionTurnActionPort {
  @override
  SessionTurnState state = const SessionTurnState();
  final List<ItemId> staged = [];
  MessageAnchor? nextAnchor;
  // Publishes the live view after a change, as the production turn lane does.
  void Function()? onRedo;

  @override
  SessionTurnUnavailable? unavailable(SessionTurnAction action) => null;

  @override
  Future<SessionTurnResult> stage(
    ItemId boundary, {
    required CommandId id,
  }) async {
    staged.add(boundary);
    state = SessionTurnState(
      phase: SessionTurnPhase.idle,
      revert: RevertState(
        kind: const OpenValue.known(RevertKind.staged),
        boundary: boundary,
        anchor:
            nextAnchor ??
            MessageAnchor(message: MessageRef('msg_2'), orderKey: 'msg_2'),
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
    onRedo?.call();
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
}) => UserInput(
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
}) => AssistantText(
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
  testWidgets(
    'a message bar offers undo on the latest turn and rewind on older ones (#539)',
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
          home: Scaffold(body: SessionLivePage(controller: live)),
        ),
      );
      await tester.pumpAndSettle();

      // The action no longer floats beside the bubble (#492).
      expect(
        find.byKey(ValueKey('user-turn-action-${user1.id.value}')),
        findsNothing,
      );
      final undo = find.byKey(const ValueKey('message-action-undo'));
      final rewind = find.byKey(const ValueKey('message-action-rewind'));
      final more = find.byKey(const ValueKey('message-action-more'));

      // An older confirmed turn offers "Rewind and edit from here" in its
      // bar's menu (#539), on its prompt and on its answer.
      for (final text in ['First user prompt', 'First response']) {
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
        await tester.pump(kDoubleTapTimeout);
        expect(undo, findsNothing);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: rewind,
            matching: find.text('Rewind and edit from here'),
          ),
          findsOneWidget,
        );
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
      }

      // The latest confirmed turn offers "Undo this turn", which stages it.
      await tester.tap(find.text('Second response'));
      await tester.pumpAndSettle();
      expect(undo, findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second user prompt'));
      await tester.pumpAndSettle();
      await tester.pump(kDoubleTapTimeout);
      port.nextAnchor = user2.meta.anchor;
      await tester.tap(undo);
      await tester.pumpAndSettle();

      expect(port.staged, [user2.id]);
      expect(live.draft.text, 'Second user prompt');
    },
  );

  testWidgets(
    'Fork from here cuts before a prompt, after an answer\'s turn (#539)',
    (tester) async {
      final actions = FakeActionSource();
      final rig = CatalogRig(actions: actions);
      await rig.save('a');
      await rig.sessions.initialize();
      final loading = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      final summary = source.row('one');
      source.respond([summary]);
      await loading;
      final directory = LiveDirectory();
      final ref = summary.info.ref;
      final live = SessionLiveController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: summary,
        directory: directory,
      );
      addTearDown(live.dispose);
      final start = live.start();
      final handle = directory.grant(ref, turnActions: _FakePort());
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
        ChangeNotifierProvider<SessionsController?>.value(
          value: rig.sessions,
          child: MaterialApp(
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: Scaffold(body: SessionLivePage(controller: live)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> fork(String text) async {
        await tester.tap(find.text(text));
        await tester.pumpAndSettle();
        await tester.pump(kDoubleTapTimeout);
        await tester.tap(find.byKey(const ValueKey('message-action-more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('message-action-fork')));
        await tester.pumpAndSettle();
        // The list reads again after a fork; it answers before the next one.
        if (!source.tasks.last.completion.isCompleted) {
          source.respond([summary]);
          await tester.pumpAndSettle();
        }
      }

      await fork('First user prompt');
      await fork('First response');
      await fork('Second response');
      expect(actions.calls, [
        'fork:${user1.id.value}',
        'fork:${user2.id.value}',
        'fork',
      ]);
    },
  );

  testWidgets('no Fork from here while an undo is staged (#539)', (
    tester,
  ) async {
    final actions = FakeActionSource();
    final rig = CatalogRig(actions: actions);
    await rig.save('a');
    await rig.sessions.initialize();
    final loading = rig.sessions.selectProfile('profile_a');
    final source = rig.sources.single;
    final summary = source.row('one');
    source.respond([summary]);
    await loading;
    final directory = LiveDirectory();
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
    final user2 = _turn('msg_2', ref: ref, text: 'Second user prompt');
    port.state = SessionTurnState(
      phase: SessionTurnPhase.idle,
      revert: RevertState(
        kind: const OpenValue.known(RevertKind.staged),
        boundary: user2.id,
        anchor: user2.meta.anchor!,
      ),
    );
    handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(
          ref,
          items: [
            user1,
            _answer('ans_1', ref: ref, text: 'First response'),
            user2,
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionsController?>.value(
        value: rig.sessions,
        child: MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: Scaffold(body: SessionLivePage(controller: live)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(rig.sessions.findSession(ref), isNotNull);
    await tester.tap(find.text('First response'));
    await tester.pumpAndSettle();
    await tester.pump(kDoubleTapTimeout);
    final more = find.byKey(const ValueKey('message-action-more'));
    if (more.evaluate().isNotEmpty) {
      await tester.tap(more);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('message-action-fork')), findsNothing);
  });

  testWidgets(
    'a prompt\'s fork opens the new session with the prompt in its box',
    (tester) async {
      final actions = FakeActionSource();
      final rig = CatalogRig(actions: actions);
      await rig.save('a');
      await rig.sessions.initialize();
      final loading = rig.sessions.selectProfile('profile_a');
      final source = rig.sources.single;
      final summary = source.row('one');
      source.respond([summary]);
      await loading;
      final copy = source.row('copy').info.ref;
      actions.forked = copy;
      final metadata = V2MetadataStore(backend: FakeMetadataBackend());
      final drafts = SessionDraftStore(
        payloads: PreferencesPayloadStore(metadata),
        index: metadata,
      );
      final directory = LiveDirectory();
      final ref = summary.info.ref;
      final live = SessionLiveController(
        hosts: rig.hosts,
        profile: profile('a'),
        summary: summary,
        directory: directory,
      );
      addTearDown(live.dispose);
      final start = live.start();
      final handle = directory.grant(ref, turnActions: _FakePort());
      await start;
      final user1 = _turn('msg_1', ref: ref, text: 'First user prompt');
      handle.emit(
        SessionLiveView(
          session: ref,
          phase: SessionLivePhase.live,
          state: liveState(
            ref,
            items: [
              user1,
              _answer('ans_1', ref: ref, text: 'First response'),
            ],
          ),
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: SessionLivePage(controller: live)),
          ),
          GoRoute(
            path: '/s/:host/:id',
            builder: (context, state) =>
                Text('opened ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionsController?>.value(
              value: rig.sessions,
            ),
            Provider<SessionDraftStore?>.value(value: drafts),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('First user prompt'));
      await tester.pumpAndSettle();
      await tester.pump(kDoubleTapTimeout);
      await tester.tap(find.byKey(const ValueKey('message-action-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-fork')));
      await tester.pumpAndSettle();
      expect(actions.calls, ['fork:${user1.id.value}']);
      expect(find.text('opened ses_copy'), findsOneWidget);
      expect(await drafts.read(copy), 'First user prompt');
    },
  );

  testWidgets('undo and redo reflect in the timeline at once', (tester) async {
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
        home: Scaffold(body: SessionLivePage(controller: live)),
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

    // Redo publishes the full view, as the turn lane does; the cut turn is back at once.
    port.onRedo = () => handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        state: liveState(ref, items: [user1, ans1, user2, ans2]),
      ),
    );
    await live.turn.redoAll();
    await tester.pumpAndSettle();
    expect(find.text('Second user prompt'), findsOneWidget);
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets(
      width < 600
          ? 'workspace header overflow shows turn actions when session is active'
          : 'workspace toolbar shows turn actions inline on wide',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
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
                ChangeNotifierProvider<SessionsController?>.value(
                  value: rig.sessions,
                ),
                ChangeNotifierProvider<WorkspaceChromeController?>.value(
                  value: chrome,
                ),
              ],
              child: Scaffold(
                appBar: AppBar(
                  actions: [WorkspaceAppBarActions(compact: width < 600)],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        if (width < 600) {
          expect(find.byKey(const ValueKey('turn-menu-undo')), findsNothing);
          await tester.tap(find.byKey(const ValueKey('workspace-actions')));
          await tester.pumpAndSettle();
        } else {
          expect(
            tester.widget(find.byKey(const ValueKey('turn-menu-undo'))),
            isA<IconButton>(),
          );
        }

        // The same actions are inline on wide and in the overflow on compact.
        expect(find.byKey(const ValueKey('turn-menu-undo')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('turn-menu-redo-next')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('turn-menu-redo-all')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('turn-menu-compact')), findsOneWidget);
      },
    );
  }

  // v1 keeps "Undo last turn" listed and disabled on the home screen.
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      width < 600
          ? 'workspace header overflow keeps undo disabled without a live session'
          : 'workspace toolbar keeps undo disabled without a live session',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final rig = CatalogRig();
        await rig.save('a');
        await rig.sessions.initialize();
        final selecting = rig.sessions.selectProfile('profile_a');
        rig.sources.single.respond([rig.sources.single.row('one')]);
        await selecting;

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

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: V2Localizations.localizationsDelegates,
            supportedLocales: V2Localizations.supportedLocales,
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider<SessionsController?>.value(
                  value: rig.sessions,
                ),
                ChangeNotifierProvider<WorkspaceChromeController?>.value(
                  value: chrome,
                ),
              ],
              child: Scaffold(
                appBar: AppBar(
                  actions: [WorkspaceAppBarActions(compact: width < 600)],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        if (width < 600) {
          await tester.tap(find.byKey(const ValueKey('workspace-actions')));
          await tester.pumpAndSettle();
          final undo = tester.widget<MenuItemButton>(
            find.byKey(const ValueKey('turn-menu-undo')),
          );
          expect(undo.onPressed, isNull);
        } else {
          final undo = tester.widget<IconButton>(
            find.byKey(const ValueKey('turn-menu-undo')),
          );
          expect(undo.onPressed, isNull);
        }

        expect(find.byKey(const ValueKey('turn-menu-redo-next')), findsNothing);
        expect(find.byKey(const ValueKey('turn-menu-redo-all')), findsNothing);
        expect(find.byKey(const ValueKey('turn-menu-compact')), findsNothing);
      },
    );
  }
}
