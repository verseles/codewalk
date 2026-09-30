import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/widgets/project_session_picker.dart';
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
  EdgeInsets padding = EdgeInsets.zero,
  bool open = true,
  FocusNode? openerFocus,
  ValueChanged<SessionMenuAction?>? onSelected,
  ValueNotifier<int>? dismissSignal,
  List<SessionMenuSession> recentSessions = const [],
  ValueChanged<SessionTabMenuSelection?>? onResult,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    localizedMaterialApp(
      theme: ThemeData(platform: TargetPlatform.windows),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale), padding: padding),
        child: Directionality(
          textDirection: direction,
          child: dismissSignal == null
              ? child!
              : Column(
                  children: [
                    TextButton(
                      key: const ValueKey<String>('external_tab'),
                      onPressed: () => dismissSignal.value++,
                      child: const Text('Another window tab'),
                    ),
                    Expanded(child: child!),
                  ],
                ),
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            Future<void> show() async {
              final result = await showMenu<SessionTabMenuSelection>(
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
                  dismissSignal: dismissSignal,
                  recentSessions: recentSessions,
                ),
              );
              onResult?.call(result);
              onSelected?.call(
                result is SessionTabMenuActionSelection ? result.action : null,
              );
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
  SessionMenuSession choice(
    String id, {
    SessionAttentionState attention = const SessionAttentionState(),
    bool selected = false,
  }) => SessionMenuSession(
    identity: SessionTabIdentity(
      serverId: 'server',
      directory: '/project',
      sessionId: id,
    ),
    title: 'Conversation $id with a long title',
    attention: attention,
    isSelected: selected,
  );

  testWidgets('picker dismissal removes only its owned route', (tester) async {
    final signal = ValueNotifier<int>(0);
    final updates = ValueNotifier<int>(0);
    addTearDown(signal.dispose);
    addTearDown(updates.dispose);
    late BuildContext homeContext;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Builder(
          builder: (context) {
            homeContext = context;
            return TextButton(
              onPressed: () => showDialog<SessionTabIdentity>(
                context: context,
                builder: (_) => ProjectSessionPicker(
                  projectLabel: 'Project',
                  updates: updates,
                  dismissSignal: signal,
                  sessions: () => [choice('first')],
                  isValid: () => true,
                ),
              ),
              child: const Text('Open picker'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    final top = showDialog<void>(
      context: homeContext,
      builder: (_) => const AlertDialog(content: Text('Unrelated route')),
    );
    await tester.pumpAndSettle();
    signal.value++;
    await tester.pumpAndSettle();
    expect(find.text('Unrelated route'), findsOneWidget);
    Navigator.of(homeContext).pop();
    await top;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('project_session_picker')),
      findsNothing,
    );
    expect(find.text('Open picker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'project selector updates cached rows and dismisses on server invalidation',
    (tester) async {
      final updates = ValueNotifier<int>(0);
      addTearDown(updates.dispose);
      var valid = true;
      var sessions = [choice('first'), choice('second')];
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<SessionTabIdentity>(
                context: context,
                builder: (_) => ProjectSessionPicker(
                  projectLabel: 'Project',
                  updates: updates,
                  sessions: () => sessions,
                  isValid: () => valid,
                ),
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('project_session_picker_first')),
        findsOneWidget,
      );
      sessions = [choice('second')];
      updates.value++;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('project_session_picker_first')),
        findsNothing,
      );
      valid = false;
      updates.value++;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('project_session_picker')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recent session rows return scoped identity and show more',
    (tester) async {
      final session = choice('other', selected: true);
      SessionTabMenuSelection? result;
      await _pumpMenu(
        tester,
        recentSessions: [session],
        onResult: (value) => result = value,
      );
      final row = find.byKey(
        const ValueKey<String>('session_tab_recent_other'),
      );
      expect(
        tester.getSemantics(row).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        (result as SessionTabMenuSessionSelection).identity,
        session.identity,
      );
      expect(_action(SessionMenuAction.pin), findsNothing);
      await _pumpMenu(
        tester,
        recentSessions: [session],
        onResult: (value) => result = value,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('session_tab_menu_show_more')),
      );
      await tester.pumpAndSettle();
      expect(result, isA<SessionTabMenuMoreSelection>());
    },
    semanticsEnabled: true,
  );

  testWidgets(
    'keyboard reaches recent rows and show more within the menu loop',
    (tester) async {
      SessionTabMenuSelection? result;
      await _pumpMenu(
        tester,
        recentSessions: [choice('other')],
        onResult: (value) => result = value,
      );
      tester
          .widget<IconButton>(_action(SessionMenuAction.closeProject))
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(
          tester.element(find.text('Conversation other with a long title')),
        ).hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, isA<SessionTabMenuMoreSelection>());
      await _pumpMenu(
        tester,
        recentSessions: [choice('other')],
        onResult: (value) => result = value,
      );
      tester
          .widget<IconButton>(_action(SessionMenuAction.closeProject))
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.byKey(const ValueKey<String>('session_tab_recent_header')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'recent statuses remain accessible in scaled narrow RTL menus',
    (tester) async {
      tester.view.physicalSize = const Size(200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final choices = [
        choice(
          'error',
          attention: const SessionAttentionState(
            hasError: true,
            isActive: true,
          ),
          selected: true,
        ),
        choice(
          'pending',
          attention: const SessionAttentionState(hasPendingInteraction: true),
        ),
        choice(
          'unread',
          attention: const SessionAttentionState(hasUnreadCompletion: true),
        ),
        choice('busy', attention: const SessionAttentionState(isActive: true)),
      ];
      await _pumpMenu(
        tester,
        textScale: 2,
        direction: TextDirection.rtl,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        recentSessions: choices,
      );
      expect(tester.takeException(), isNull);
      for (final session in choices) {
        final row = find.byKey(
          ValueKey<String>('session_tab_recent_${session.identity.sessionId}'),
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final data = tester.getSemantics(row).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.label, contains(session.title));
        expect(data.label.length, greaterThan(session.title.length));
        final rect = tester.getRect(row);
        expect(rect.left, greaterThanOrEqualTo(32));
        expect(rect.right, lessThanOrEqualTo(168));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    },
    semanticsEnabled: true,
  );

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
      [SessionMenuAction.copyLink],
      [
        SessionMenuAction.delete,
        SessionMenuAction.share,
        SessionMenuAction.closeProject,
      ],
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
    expect(delete.style!.side?.resolve({}), isNull);
    final close = tester.widget<IconButton>(
      _action(SessionMenuAction.closeProject),
    );
    expect(close.style!.side?.resolve({}), isNull);
    final deleteX = tester.getCenter(_action(SessionMenuAction.delete)).dx;
    final shareX = tester.getCenter(_action(SessionMenuAction.share)).dx;
    final closeX = tester.getCenter(_action(SessionMenuAction.closeProject)).dx;
    expect(deleteX, tester.getCenter(_action(SessionMenuAction.pin)).dx);
    expect(closeX, tester.getCenter(_action(SessionMenuAction.archive)).dx);
    expect(shareX, (deleteX + closeX) / 2);
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
    'an external window tab dismisses the exact popup and completes its future',
    (tester) async {
      final signal = ValueNotifier<int>(0);
      addTearDown(signal.dispose);
      var completed = false;
      SessionMenuAction? result;
      await _pumpMenu(
        tester,
        dismissSignal: signal,
        onSelected: (value) {
          completed = true;
          result = value;
        },
      );
      await tester.tap(find.byKey(const ValueKey<String>('external_tab')));
      await tester.pumpAndSettle();
      expect(_action(SessionMenuAction.pin), findsNothing);
      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byKey(const ValueKey<String>('open_menu')), findsOneWidget);
    },
  );

  testWidgets('external dismissal never pops a dialog above the menu', (
    tester,
  ) async {
    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);
    await _pumpMenu(tester, dismissSignal: signal);
    final context = tester.element(
      find.byKey(const ValueKey<String>('open_menu')),
    );
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Keep this dialog')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('external_tab')));
    await tester.pumpAndSettle();
    expect(_action(SessionMenuAction.pin), findsNothing);
    expect(find.text('Keep this dialog'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('external_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Keep this dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow safe-area popup keeps every action inside its usable width',
    (tester) async {
      tester.view.physicalSize = const Size(200, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpMenu(
        tester,
        padding: const EdgeInsets.symmetric(horizontal: 24),
      );
      expect(tester.takeException(), isNull);
      for (final action in SessionMenuAction.values) {
        final rect = tester.getRect(_action(action));
        expect(rect.width, 48);
        expect(rect.height, 48);
        expect(rect.left, greaterThanOrEqualTo(32));
        expect(rect.right, lessThanOrEqualTo(168));
      }
      expect(
        tester.getCenter(_action(SessionMenuAction.changeIcon)).dy,
        greaterThan(tester.getCenter(_action(SessionMenuAction.pin)).dy),
      );
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
        final archiveY = tester
            .getCenter(_action(SessionMenuAction.archive))
            .dy;
        final pinY = tester.getCenter(_action(SessionMenuAction.pin)).dy;
        if (width >= 240) {
          expect(archiveY, pinY, reason: 'Four targets fit on mobile');
          expect(
            tester.getCenter(_action(SessionMenuAction.share)).dy,
            tester.getCenter(_action(SessionMenuAction.delete)).dy,
          );
          expect(
            tester.getCenter(_action(SessionMenuAction.closeProject)).dy,
            tester.getCenter(_action(SessionMenuAction.delete)).dy,
          );
        } else {
          expect(archiveY, greaterThan(pinY));
        }
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
