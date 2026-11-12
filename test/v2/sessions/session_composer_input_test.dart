import 'dart:async';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../hosts/fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// A live session open on its composer, with [outbox] behind it.
Future<({LiveHandle handle, SessionRef ref, AppDependencies graph})> _open(
  WidgetTester tester,
  FakeOutbox outbox, {
  void Function(AppDependencies graph)? setUp,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rig = CatalogRig();
  await rig.save('a');
  final directory = LiveDirectory();
  final graph = createAppDependencies(
    initialLink: Uri(path: '/sessions'),
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
  );
  addTearDown(graph.dispose);
  setUp?.call(graph);
  await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: graph));
  await showSessionList(tester);
  final read = graph.sessions!.selectProfile('profile_a');
  final catalog = rig.sources.single;
  final row = catalog.row('one');
  catalog.respond([row]);
  await read;
  await tester.pumpAndSettle();
  final button = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump();
  final ref = row.info.ref;
  final handle = directory.grant(ref, outbox: outbox);
  await tester.pump();
  handle.emit(
    SessionLiveView(
      session: ref,
      phase: SessionLivePhase.live,
      lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
      state: liveState(ref, execution: _execution(ExecutionKind.idle)),
    ),
  );
  await tester.pumpAndSettle();
  return (handle: handle, ref: ref, graph: graph);
}

ExecutionState _execution(ExecutionKind kind) =>
    ExecutionState(kind: OpenValue.known(kind));

/// Shows [opened] with [execution] reported, or none.
Future<void> _report(
  WidgetTester tester,
  ({LiveHandle handle, SessionRef ref, AppDependencies graph}) opened,
  ExecutionKind? execution,
) async {
  opened.handle.emit(
    SessionLiveView(
      session: opened.ref,
      phase: SessionLivePhase.live,
      lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
      state: liveState(
        opened.ref,
        execution: execution == null ? null : _execution(execution),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Iterable<String> _submits(FakeOutbox outbox) =>
    outbox.calls.where((c) => c.startsWith('submit'));

final _input = find.byKey(const ValueKey('live-composer-input'));
final _send = find.byKey(const ValueKey('live-composer-send'));

/// The double tap that continues, when the composer offers it.
final _continues = find.descendant(
  of: find.byKey(const ValueKey('live-composer')),
  matching: find.byWidgetPredicate(
    (widget) => widget is GestureDetector && widget.onDoubleTap != null,
  ),
);

void main() {
  testWidgets(
    'a physical Enter sends and keeps the field focused (#174)',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      final outbox = FakeOutbox();
      await _open(tester, outbox);
      await tester.tap(_input);
      await tester.enterText(_input, 'Hello');
      await tester.pump();
      // Shift+Enter breaks the line instead.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_submits(outbox), isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_submits(outbox).single, endsWith(' Hello'));
      expect(tester.widget<TextField>(_input).controller!.text, isEmpty);
      expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
      // An empty Enter sends nothing and adds no line.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_submits(outbox), hasLength(1));
      expect(tester.widget<TextField>(_input).controller!.text, isEmpty);
      // A click on Send keeps the field focused too.
      await tester.enterText(_input, 'Again');
      await tester.pump();
      await tester.tap(_send, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_submits(outbox), hasLength(2));
      expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
    },
  );

  testWidgets(
    'on a phone a sent message lets the keyboard go (beta.21)',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      final outbox = FakeOutbox();
      await _open(tester, outbox);
      await tester.tap(_input);
      await tester.enterText(_input, 'Hello');
      await tester.pump();
      expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
      await tester.tap(_send);
      await tester.pumpAndSettle();
      expect(_submits(outbox).single, endsWith(' Hello'));
      // The field lets go, so the keyboard closes and the composer folds.
      expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isFalse);
    },
  );

  testWidgets('an idle session shows a check on the empty Send (beta.21)', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final opened = await _open(tester, outbox);
    final l10n = opened.graph.localizations.current;
    IconData? glyph() => tester
        .widget<Icon>(find.descendant(of: _send, matching: find.byType(Icon)))
        .icon;
    // Idle and empty: a check, still disabled, and the bar does not say Idle.
    expect(glyph(), Symbols.check);
    expect(tester.widget<IconButton>(_send).tooltip, l10n.liveIdle);
    expect(tester.widget<IconButton>(_send).onPressed, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('composer-status')),
        matching: find.text(l10n.liveIdle),
      ),
      findsNothing,
    );
    // Typing brings the arrow back; clearing the field shows the check again.
    await tester.enterText(_input, 'Hi');
    await tester.pump();
    expect(glyph(), Symbols.arrow_upward);
    expect(tester.widget<IconButton>(_send).tooltip, l10n.composerSend);
    await tester.enterText(_input, '');
    await tester.pump();
    expect(glyph(), Symbols.check);
  });

  testWidgets('a double tap on the empty Send continues once (#82)', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final opened = await _open(tester, outbox);
    expect(tester.widget<IconButton>(_send).onPressed, isNull);
    // A single tap on the empty Send does nothing.
    await tester.tap(_send);
    await tester.pumpAndSettle();
    expect(_submits(outbox), isEmpty);
    await tester.tap(_input);
    await tester.pump();
    await _doubleTap(tester, _send);
    expect(_submits(outbox).single, endsWith(' continue'));
    expect(tester.widget<TextField>(_input).controller!.text, isEmpty);
    // On a phone the accepted Continue lets the keyboard go (beta.21).
    expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isFalse);

    // Only a session the server reports idle continues: not one whose
    // execution is unknown, nor a running one whose Stop is unavailable.
    for (final execution in [null, ExecutionKind.running]) {
      await _report(tester, opened, execution);
      expect(tester.widget<IconButton>(_send).onPressed, isNull);
      expect(_continues, findsNothing, reason: '$execution');
    }
    await _report(tester, opened, ExecutionKind.idle);
    expect(_continues, findsOneWidget);

    // While the session responds the slot is Stop, which never continues.
    opened.handle.stopAvailable = true;
    await _report(tester, opened, ExecutionKind.running);
    expect(_send, findsNothing);
    expect(find.byKey(const ValueKey('live-stop')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('live-stop')),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
  });

  testWidgets('text typed while a continue is sent stays (#82)', (
    tester,
  ) async {
    final outbox = FakeOutbox()..holdSubmit = Completer<void>();
    await _open(tester, outbox);
    // The send's indicator never settles while the send is held.
    await tester.tap(_send);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_send);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_submits(outbox).single, endsWith(' continue'));
    expect(tester.widget<TextField>(_input).readOnly, isFalse);
    await tester.enterText(_input, 'next');
    await tester.pump();
    outbox.holdSubmit!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_input).controller!.text, 'next');
    expect(_submits(outbox), hasLength(1));
    // The next message keeps the keyboard (beta.21).
    expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
  });

  testWidgets('the status slot reports the call in flight (#133)', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final opened = await _open(tester, outbox);
    final ref = opened.ref;
    opened.handle.emit(
      SessionLiveView(
        session: ref,
        phase: SessionLivePhase.live,
        lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
        state: liveState(
          ref,
          execution: _execution(ExecutionKind.running),
          items: [
            UserInput(
              meta: liveMeta(ref, 'u1'),
              text: 'go',
              delivery: const OpenValue.known(DeliveryState.delivered),
            ),
            ToolCall(
              meta: ItemMeta(
                id: const ItemId('t1'),
                generation: 'live',
                status: const OpenValue.known(ItemStatus.streaming),
                source: liveMeta(ref, 't1').source,
              ),
              kind: const OpenValue.known(ToolKind.search),
              rawName: 'grep',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final slot = find.byKey(const ValueKey('composer-status'));
    expect(find.descendant(of: slot, matching: find.text('grep')), findsOne);
    await _report(tester, opened, ExecutionKind.idle);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: slot, matching: find.text('grep')),
      findsNothing,
    );
  });

  testWidgets('the composer spell checks unless turned off (#88)', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final opened = await _open(tester, outbox);
    var field = tester.widget<TextField>(_input);
    expect([field.autocorrect, field.enableSuggestions], [true, true]);
    opened.graph.preferences.setComposerSpellCheck(false);
    await tester.pumpAndSettle();
    field = tester.widget<TextField>(_input);
    expect([field.autocorrect, field.enableSuggestions], [false, false]);
    expect(
      field.spellCheckConfiguration,
      const SpellCheckConfiguration.disabled(),
    );
  });

  testWidgets('holding Send chooses the default delivery (#470)', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final opened = await _open(tester, outbox);
    final preferences = opened.graph.preferences;
    expect(preferences.composerQueue, isFalse);
    Future<void> send(String text) async {
      await tester.enterText(_input, text);
      await tester.pump();
      await tester.tap(_send);
      await tester.pumpAndSettle();
    }

    Future<void> choose(String key) async {
      await tester.longPress(_send);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    // Steer is the default, and no chips offer the choice.
    expect(find.byKey(const ValueKey('live-delivery-queue')), findsNothing);
    await send('one');
    expect(_submits(outbox).last, endsWith(' steer one'));

    // Held while empty, Send still opens the choice; each says what it does,
    // the current one checked.
    expect(tester.widget<IconButton>(_send).onPressed, isNull);
    await tester.longPress(_send);
    await tester.pumpAndSettle();
    final l10n = opened.graph.localizations.current;
    expect(find.text(l10n.composerSteerHint), findsOneWidget);
    expect(find.text(l10n.composerQueueHint), findsOneWidget);
    Icon? mark(String key) {
      final tile = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(ListTile),
      );
      return tester.widget<ListTile>(tile).leading as Icon?;
    }

    expect(mark('live-delivery-steer')?.icon, isNotNull);
    expect(mark('live-delivery-queue')?.icon, isNull);
    // Dismissing it keeps the default.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(l10n.composerQueueHint), findsNothing);
    expect(preferences.composerQueue, isFalse);

    // Queue becomes the default for every later send, and Send says so.
    await choose('live-delivery-queue');
    expect(preferences.composerQueue, isTrue);
    // An idle session's empty Send shows the check (beta.21); typed text
    // shows the delivery.
    expect(tester.widget<IconButton>(_send).tooltip, l10n.liveIdle);
    await tester.enterText(_input, 'two');
    await tester.pump();
    expect(tester.widget<IconButton>(_send).tooltip, l10n.composerQueue);
    await send('two');
    await send('three');
    expect(_submits(outbox).skip(1), [
      endsWith(' queue two'),
      endsWith(' queue three'),
    ]);

    await choose('live-delivery-steer');
    expect(preferences.composerQueue, isFalse);
    await tester.enterText(_input, 'four');
    await tester.pump();
    expect(tester.widget<IconButton>(_send).tooltip, l10n.composerSend);
    await send('four');
    expect(_submits(outbox).last, endsWith(' steer four'));
  });

  testWidgets('the keys and a right click open the delivery choice (#470)', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final opened = await _open(tester, outbox);
    final l10n = opened.graph.localizations.current;
    final preferences = opened.graph.preferences;
    // Shift+F10 from the empty field, which a keyboard user is typing in.
    await tester.tap(_input);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text(l10n.composerQueueHint), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-delivery-queue')));
    await tester.pumpAndSettle();
    expect(preferences.composerQueue, isTrue);

    // The Menu key opens it too, and so does a right click on Send.
    await tester.tap(_input);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text(l10n.composerSteerHint), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-delivery-steer')));
    await tester.pumpAndSettle();
    expect(preferences.composerQueue, isFalse);

    await tester.tap(_send, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text(l10n.composerQueueHint), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
}
