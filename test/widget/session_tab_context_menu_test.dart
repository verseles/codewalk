import 'dart:ui' show Tristate;

import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/widgets/session_context_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

final _identity = SessionTabIdentity(
  serverId: 'server',
  directory: '/project',
  sessionId: 'session',
);

ChatSession _session({bool toggled = false, bool link = true}) => ChatSession(
  id: 'session',
  workspaceId: 'project',
  time: DateTime.fromMillisecondsSinceEpoch(1000),
  shared: toggled,
  shareUrl: link ? 'https://example.com/session' : null,
  archivedAt: toggled ? DateTime.fromMillisecondsSinceEpoch(2000) : null,
);

Finder _action(SessionMenuAction action) =>
    find.byKey(ValueKey<String>('session_tab_menu_${action.name}'));

Future<void> _pumpMenu(
  WidgetTester tester, {
  ChatSession? session,
  bool snapshot = true,
  bool active = true,
  bool disabled = false,
  bool toggled = false,
  String? closeLabel = 'Close project',
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  bool open = true,
  FocusNode? openerFocus,
  ValueChanged<SessionMenuAction?>? onSelected,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    localizedMaterialApp(
      theme: ThemeData(platform: TargetPlatform.windows),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            Future<void> show() async {
              final result = await showMenu<SessionMenuAction>(
                context: context,
                requestFocus: true,
                position: const RelativeRect.fromLTRB(16, 64, 16, 16),
                items: buildUnifiedSessionMenuEntries(
                  context,
                  session: snapshot
                      ? (session ?? _session(toggled: toggled))
                      : null,
                  isPinned: toggled,
                  tabIdentity: _identity,
                  includeTabLocal: true,
                  includeActiveOnly: true,
                  isActive: active,
                  canUndo: !disabled,
                  canRedo: !disabled,
                  canCompact: !disabled,
                  canCloseProject: !disabled,
                  closeProjectLabel: closeLabel,
                ),
              );
              onSelected?.call(result);
            }

            return GestureDetector(
              onLongPressStart: (_) => show(),
              child: TextButton(
                key: const ValueKey<String>('open_menu'),
                focusNode: openerFocus,
                onPressed: show,
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    ),
  );
  if (open) {
    await tester.tap(find.byKey(const ValueKey<String>('open_menu')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('desktop groups all actions into four-column rows', (
    tester,
  ) async {
    await _pumpMenu(tester);
    for (final action in SessionMenuAction.values) {
      expect(_action(action), findsOneWidget);
      expect(tester.getSize(_action(action)), const Size(48, 48));
    }
    final groups = [
      [
        SessionMenuAction.pin,
        SessionMenuAction.rename,
        SessionMenuAction.changeIcon,
        SessionMenuAction.archive,
      ],
      [
        SessionMenuAction.undo,
        SessionMenuAction.redo,
        SessionMenuAction.fork,
        SessionMenuAction.compact,
      ],
      [
        SessionMenuAction.viewTasks,
        SessionMenuAction.reviewChanges,
        SessionMenuAction.exportMarkdown,
        SessionMenuAction.exportJson,
      ],
      [SessionMenuAction.share, SessionMenuAction.copyLink],
      [SessionMenuAction.delete, SessionMenuAction.closeProject],
    ];
    double previousY = 0;
    for (final group in groups) {
      final y = tester.getCenter(_action(group.first)).dy;
      expect(y, greaterThan(previousY));
      for (final action in group) {
        expect(tester.getCenter(_action(action)).dy, y);
      }
      previousY = y;
    }
    expect(find.byType(Divider), findsNWidgets(4));
    final delete = tester.widget<IconButton>(_action(SessionMenuAction.delete));
    expect(delete.style!.side!.resolve({}), isNotNull);
  });

  testWidgets(
    'missing snapshot omits unavailable actions without empty groups',
    (tester) async {
      await _pumpMenu(tester, snapshot: false, closeLabel: null);
      for (final action in [
        SessionMenuAction.share,
        SessionMenuAction.copyLink,
        SessionMenuAction.archive,
        SessionMenuAction.closeProject,
      ]) {
        expect(_action(action), findsNothing);
      }
      expect(_action(SessionMenuAction.changeIcon), findsOneWidget);
      expect(_action(SessionMenuAction.delete), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await _pumpMenu(tester, session: _session(link: false));
      expect(_action(SessionMenuAction.copyLink), findsNothing);
    },
  );

  testWidgets(
    'disabled and toggled actions expose one semantic button each',
    (tester) async {
      await _pumpMenu(tester, disabled: true, toggled: true);
      for (final action in [
        SessionMenuAction.pin,
        SessionMenuAction.share,
        SessionMenuAction.archive,
      ]) {
        final data = tester.getSemantics(_action(action)).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isToggled, Tristate.isTrue);
        expect(data.label, isNotEmpty);
      }
      for (final action in [
        SessionMenuAction.undo,
        SessionMenuAction.redo,
        SessionMenuAction.compact,
        SessionMenuAction.closeProject,
      ]) {
        final button = tester.widget<IconButton>(_action(action));
        expect(button.onPressed, isNull);
        final data = tester.getSemantics(_action(action)).getSemanticsData();
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
      }
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Unpin' &&
              widget.properties.button == true,
        ),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await _pumpMenu(tester, disabled: true, active: false);
      for (final action in [
        SessionMenuAction.undo,
        SessionMenuAction.redo,
        SessionMenuAction.compact,
      ]) {
        expect(tester.widget<IconButton>(_action(action)).onPressed, isNotNull);
      }
    },
    semanticsEnabled: true,
  );

  testWidgets('each icon returns its own action through the popup route', (
    tester,
  ) async {
    for (final action in SessionMenuAction.values) {
      SessionMenuAction? result;
      await _pumpMenu(tester, onSelected: (value) => result = value);
      await tester.tap(_action(action));
      await tester.pumpAndSettle();
      expect(result, action);
      expect(_action(action), findsNothing);
    }
  });

  testWidgets('hover and touch hold reveal names without selecting actions', (
    tester,
  ) async {
    var selected = false;
    await _pumpMenu(tester, onSelected: (_) => selected = true);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_action(SessionMenuAction.rename)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Rename session'), findsOneWidget);
    expect(selected, isFalse);
    await mouse.removePointer();
    await tester.longPress(_action(SessionMenuAction.delete));
    await tester.pump();
    expect(find.text('Delete'), findsOneWidget);
    expect(selected, isFalse);
    expect(_action(SessionMenuAction.delete), findsOneWidget);
    await tester.tap(_action(SessionMenuAction.delete));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
  });

  testWidgets('releasing the touch hold that opens the menu selects nothing', (
    tester,
  ) async {
    var selected = false;
    await _pumpMenu(tester, open: false, onSelected: (_) => selected = true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('open_menu'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_action(SessionMenuAction.pin), findsOneWidget);
    expect(selected, isFalse);
  });

  testWidgets(
    'keyboard traverses rows, skips disabled actions and restores focus',
    (tester) async {
      SessionMenuAction? result;
      await _pumpMenu(
        tester,
        disabled: true,
        onSelected: (value) => result = value,
      );
      bool focused(SessionMenuAction action) =>
          tester.widget<IconButton>(_action(action)).focusNode!.hasFocus;
      expect(focused(SessionMenuAction.pin), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focused(SessionMenuAction.rename), isTrue);
      expect(find.text('Rename session'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focused(SessionMenuAction.changeIcon), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(focused(SessionMenuAction.rename), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focused(SessionMenuAction.reviewChanges), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focused(SessionMenuAction.rename), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, SessionMenuAction.rename);
      final opener = FocusNode();
      addTearDown(opener.dispose);
      await _pumpMenu(
        tester,
        open: false,
        openerFocus: opener,
        onSelected: (value) => result = value,
      );
      opener.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(focused(SessionMenuAction.pin), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_action(SessionMenuAction.pin), findsNothing);
      expect(result, isNull);
      expect(opener.hasFocus, isTrue);
    },
  );

  testWidgets(
    'compact and tiny layouts wrap while large labels and RTL remain usable',
    (tester) async {
      for (final width in [360.0, 200.0, 140.0]) {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpMenu(
          tester,
          textScale: 2,
          closeLabel: 'Close a project with a very long localized name',
        );
        expect(tester.takeException(), isNull);
        for (final action in SessionMenuAction.values) {
          expect(
            _action(action),
            findsOneWidget,
            reason: 'width=$width, action=$action',
          );
          expect(tester.getSize(_action(action)), const Size(48, 48));
        }
        final pin = tester.getRect(_action(SessionMenuAction.pin));
        expect(pin.left, greaterThanOrEqualTo(0));
        expect(pin.right, lessThanOrEqualTo(width));
        expect(
          tester.getCenter(_action(SessionMenuAction.archive)).dy,
          greaterThan(tester.getCenter(_action(SessionMenuAction.pin)).dy),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      tester.view.physicalSize = const Size(800, 600);
      await _pumpMenu(tester, direction: TextDirection.rtl);
      expect(
        tester.getCenter(_action(SessionMenuAction.pin)).dx,
        greaterThan(tester.getCenter(_action(SessionMenuAction.rename)).dx),
      );
    },
  );
}
