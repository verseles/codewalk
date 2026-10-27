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
    await _doubleTap(tester, _send);
    expect(_submits(outbox).single, endsWith(' continue'));
    expect(tester.widget<TextField>(_input).controller!.text, isEmpty);

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
}
