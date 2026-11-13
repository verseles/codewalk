@TestOn('vm')
library;

import 'package:codewalk/app/app_keyboard_shortcuts.dart';
import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_search_bar.dart';
import 'package:codewalk/features/sessions/session_timeline_projection.dart';
import 'package:codewalk/features/sessions/session_timeline_search.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

/// Search in the open conversation (#462).
void main() {
  final ref = CatalogSource(profile('a')).row('one').info.ref;

  UserInput asked(String id, String text) => UserInput(
    meta: liveMeta(ref, id),
    text: text,
    delivery: const OpenValue.known(DeliveryState.delivered),
    confirmed: true,
  );
  AssistantText answered(String id, String text) =>
      AssistantText(meta: liveMeta(ref, id), text: text, complete: true);

  /// [id]'s metadata inside the harness message [message], so a finished
  /// turn's work collapses behind its answer.
  ItemMeta inMessage(String id, String message) => ItemMeta(
    id: ItemId(id),
    generation: 'live',
    status: const OpenValue.known(ItemStatus.completed),
    source: liveMeta(ref, id).source,
    message: MessageContext(message: MessageRef(message)),
  );

  group('matches', () {
    final items = <TimelineItem>[
      asked('u1', 'Find the Needle'),
      answered('a1', 'no match here'),
      Reasoning(meta: liveMeta(ref, 'r1'), text: 'a needle', complete: true),
      answered('a2', 'needle again'),
      ToolCall(
        meta: liveMeta(ref, 't1'),
        kind: const OpenValue.known(ToolKind.read),
        rawName: 'needle',
      ),
    ];

    test('run from the newest, ignore case and read no tool', () {
      final search = SessionTimelineSearch()..search('NEEDLE', items);
      addTearDown(search.dispose);
      expect(search.matches(items), [
        const ItemId('a2'),
        const ItemId('r1'),
        const ItemId('u1'),
      ]);
      expect(search.current, const ItemId('a2'));
      // Hidden reasoning is not searched.
      expect(search.matches(items, reasoning: false), [
        const ItemId('a2'),
        const ItemId('u1'),
      ]);
    });

    test('step older and newer, wrapping, and keep the match by item', () {
      final search = SessionTimelineSearch()..search('needle', items);
      addTearDown(search.dispose);
      final first = search.reveals;
      search.step(items);
      expect(search.current, const ItemId('r1'));
      search
        ..step(items)
        ..step(items);
      expect(search.current, const ItemId('a2'));
      search.step(items, older: false);
      expect(search.current, const ItemId('u1'));
      expect(search.reveals, first + 4);
      // New content arriving keeps the match where it is.
      final more = [...items, answered('a3', 'a newer needle')];
      expect(search.matches(more).indexOf(search.current!), 3);
      // A blank query finds nothing, and close forgets it.
      search.search('  ', items);
      expect(search.current, isNull);
      search
        ..show()
        ..close();
      expect(search.open, isFalse);
      expect(search.query, isEmpty);
    });
  });

  test('an answer the Block mode still holds is not found yet', () {
    final streaming = ItemMeta(
      id: const ItemId('a1'),
      generation: 'live',
      status: const OpenValue.known(ItemStatus.streaming),
      source: liveMeta(ref, 'a1').source,
    );
    final items = <TimelineItem>[
      answered('a0', 'an earlier needle, shown'),
      asked('u1', 'needle'),
      AssistantText(
        meta: streaming,
        text: 'needle in progress',
        complete: false,
      ),
    ];
    // What the timeline holds, by its own rule: only the turn in flight,
    // only while the session is busy, only in the Block mode.
    final held = SessionTimelinePresentation.heldText(
      items,
      settled: false,
      renderMode: ChatRenderMode.block,
    );
    expect(held, {const ItemId('a1')});
    for (final (settled, mode) in [
      (true, ChatRenderMode.block),
      (false, ChatRenderMode.live),
    ]) {
      expect(
        SessionTimelinePresentation.heldText(
          items,
          settled: settled,
          renderMode: mode,
        ),
        isEmpty,
      );
    }
    // A finished turn shows whole, even if a busy report keeps it in flight.
    expect(
      SessionTimelinePresentation.heldText(
        [
          ...items.take(2),
          AssistantText(
            meta: liveMeta(ref, 'a1'),
            text: 'needle, done',
            complete: true,
          ),
        ],
        settled: false,
        renderMode: ChatRenderMode.block,
      ),
      isEmpty,
    );
    final search = SessionTimelineSearch()..search('needle', items);
    addTearDown(search.dispose);
    expect(search.matches(items), hasLength(3));
    expect(search.matches(items, held: held), [
      const ItemId('u1'),
      const ItemId('a0'),
    ]);
    // The same items and query are not searched again.
    expect(identical(search.matches(items), search.matches(items)), isTrue);
  });

  group('the bar', () {
    late CatalogRig rig;
    late LiveDirectory directory;

    setUp(() async {
      rig = CatalogRig();
      await rig.save('a');
      await rig.sessions.initialize();
      directory = LiveDirectory();
    });
    tearDown(() => rig.dispose());

    /// A conversation long enough that its oldest rows are not built.
    List<TimelineItem> conversation() => [
      asked('u0', 'the first needle is old'),
      for (var i = 1; i <= 40; i++) ...[
        asked('u$i', 'question $i'),
        answered('a$i', 'answer $i ${'with filler text ' * 6}'),
      ],
      answered('a99', 'the newest needle'),
    ];

    Future<SessionLiveController> open(
      WidgetTester tester, {
      List<TimelineItem>? items,
    }) async {
      late SessionLiveController live;
      await tester.runAsync(() async {
        final summary = CatalogSource(profile('a')).row('one');
        live = SessionLiveController(
          hosts: rig.hosts,
          profile: profile('a'),
          summary: summary,
          directory: directory,
        );
        final opening = live.start();
        final handle = directory.grant(summary.info.ref, outbox: FakeOutbox());
        await opening;
        handle.emit(
          SessionLiveView(
            session: summary.info.ref,
            phase: SessionLivePhase.live,
            lastSyncedAt: DateTime.utc(2026, 11, 12),
            state: liveState(
              summary.info.ref,
              items: items ?? conversation(),
              execution: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
            ),
          ),
        );
      });
      addTearDown(live.dispose);
      final settings = AppPreferencesController();
      addTearDown(settings.dispose);
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: V2Localizations.localizationsDelegates,
          supportedLocales: V2Localizations.supportedLocales,
          home: AppKeyboardShortcuts(
            preferences: settings,
            openSettings: () {},
            child: SessionLivePage(controller: live),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return live;
    }

    Future<void> press(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool control = false,
      bool shift = false,
    }) async {
      final held = [
        if (control) LogicalKeyboardKey.controlLeft,
        if (shift) LogicalKeyboardKey.shiftLeft,
      ];
      for (final modifier in held) {
        await tester.sendKeyDownEvent(modifier);
      }
      await tester.sendKeyEvent(key);
      for (final modifier in held.reversed) {
        await tester.sendKeyUpEvent(modifier);
      }
      await tester.pumpAndSettle();
    }

    String count(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('live-search-count')))
        .data!;

    bool outlined(WidgetTester tester, String text) {
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.textContaining(text),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).border != null;
    }

    testWidgets('Ctrl+F finds, Enter and F3 go older, Escape closes', (
      tester,
    ) async {
      final live = await open(tester);
      final l10n = V2Localizations.of(
        tester.element(find.byType(SessionLivePage)),
      );
      await tester.tap(find.byKey(const ValueKey('live-composer-input')));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyF, control: true);
      final field = find.byKey(const ValueKey('live-search-field'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      await tester.enterText(field, 'NEEDLE');
      await tester.pumpAndSettle();
      // The newest match first, outlined and in view.
      expect(count(tester), l10n.liveSearchCount(1, 2));
      expect(outlined(tester, 'the newest needle'), isTrue);
      // Enter goes to the older one, built and scrolled into view.
      await press(tester, LogicalKeyboardKey.enter);
      expect(count(tester), l10n.liveSearchCount(2, 2));
      expect(
        find.textContaining('the first needle is old').hitTestable(),
        findsOneWidget,
      );
      expect(outlined(tester, 'the first needle is old'), isTrue);
      expect(live.scroll.following, isFalse);
      // Shift+Enter comes back; F3 from the composer steps too.
      await press(tester, LogicalKeyboardKey.enter, shift: true);
      expect(count(tester), l10n.liveSearchCount(1, 2));
      await tester.tap(find.byKey(const ValueKey('live-composer-input')));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.f3);
      expect(count(tester), l10n.liveSearchCount(2, 2));
      await press(tester, LogicalKeyboardKey.f3, shift: true);
      expect(count(tester), l10n.liveSearchCount(1, 2));
      // Escape in the field closes the bar and gives the composer the focus.
      await tester.tap(field);
      await tester.pump();
      await press(tester, LogicalKeyboardKey.escape);
      expect(find.byKey(const ValueKey('live-search')), findsNothing);
      expect(live.search.open, isFalse);
      expect(outlined(tester, 'the newest needle'), isFalse);
      // Closed on the newest match at the bottom: the follow resumes.
      expect(live.scroll.following, isTrue);
    });

    testWidgets('no match says so and leaves the arrows off', (tester) async {
      final live = await open(tester);
      expect(
        SessionSearchBar.heightOf(tester.element(find.byType(SessionLivePage))),
        48,
      );
      final l10n = V2Localizations.of(
        tester.element(find.byType(SessionLivePage)),
      );
      live.search.show();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('live-search-field')),
        'nothing like this',
      );
      await tester.pumpAndSettle();
      expect(count(tester), l10n.liveSearchNone);
      for (final key in ['live-search-older', 'live-search-newer']) {
        expect(
          tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed,
          isNull,
        );
      }
      await tester.tap(find.byKey(const ValueKey('live-search-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-search')), findsNothing);
    });

    testWidgets('a match in a collapsed turn opens it; Escape never stops', (
      tester,
    ) async {
      final live = await open(
        tester,
        items: [
          asked('u1', 'first question'),
          Reasoning(
            meta: inMessage('r1', 'm1'),
            text: 'the hidden needle',
            complete: true,
          ),
          ToolCall(
            meta: inMessage('t1', 'm2'),
            kind: const OpenValue.known(ToolKind.read),
            rawName: 'read',
          ),
          AssistantText(
            meta: inMessage('a1', 'm3'),
            text: 'the final answer',
            complete: true,
          ),
          asked('u2', 'second question'),
          // Tall enough that revealing the first turn leaves the bottom,
          // whatever the rows' own padding.
          answered(
            'a2',
            [
              'last answer',
              for (var i = 0; i < 30; i++) 'line $i',
            ].join('\n\n'),
          ),
        ],
      );
      // The finished turn's work is collapsed behind its answer.
      expect(find.textContaining('the hidden needle'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('live-composer-input')));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyF, control: true);
      await tester.enterText(
        find.byKey(const ValueKey('live-search-field')),
        'needle',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('the hidden needle'), findsOneWidget);
      expect(outlined(tester, 'the hidden needle'), isTrue);
      // While the search shows the match, the follow stays off.
      expect(live.scroll.following, isFalse);
      // From the composer, Escape closes the search and stops nothing.
      await tester.tap(find.byKey(const ValueKey('live-composer-input')));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.escape);
      expect(live.search.open, isFalse);
      expect(find.byKey(const ValueKey('live-search')), findsNothing);
      // Closed away from the bottom, the follow stays off until the reader
      // moves.
      expect(live.scroll.following, isFalse);
    });
  });
}
