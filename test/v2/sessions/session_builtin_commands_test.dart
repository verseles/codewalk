import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_builtin_commands.dart';
import 'package:codewalk/features/sessions/sessions_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations_en.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'composer_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

final _l10n = V2LocalizationsEn();
final _input = find.byKey(const ValueKey('live-composer-input'));
final _send = find.byKey(const ValueKey('live-composer-send'));
final _picker = find.byKey(const ValueKey('live-command-picker'));

Finder _command(String name) => find.byKey(ValueKey('live-command-$name'));

/// A live session with a model and two agents to pick, open on its
/// composer in a window of [size], with [outbox] behind it.
Future<AppDependencies> _open(
  WidgetTester tester,
  FakeOutbox outbox, {
  Size size = const Size(1280, 800),
  Locale locale = const Locale('en'),
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
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
  graph.preferences.setLocale(locale);
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
  final handle = directory.grant(ref, outbox: outbox)
    ..selectionAvailable = true
    ..selectionState = SessionSelectionState(
      selection: const Selection(
        modelId: 'alpha',
        modelProviderId: 'prov',
        agentId: 'build',
      ),
      models: [ModelEntry(id: 'alpha', providerId: 'prov', label: 'Alpha')],
      agents: [
        CatalogEntry(
          id: 'build',
          kind: const OpenValue.known(CatalogKind.agent),
          label: 'Build',
        ),
        CatalogEntry(
          id: 'plan',
          kind: const OpenValue.known(CatalogKind.agent),
          label: 'Plan',
        ),
      ],
    );
  await tester.pump();
  handle.emit(
    SessionLiveView(
      session: ref,
      phase: SessionLivePhase.live,
      lastSyncedAt: DateTime.utc(2026, 10, 15, 12),
      state: liveState(
        ref,
        execution: const ExecutionState(
          kind: OpenValue.known(ExecutionKind.idle),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (keyboard > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();
  }
  return graph;
}

Iterable<String> _submits(FakeOutbox outbox) =>
    outbox.calls.where((c) => c.startsWith('submit'));

String _text(WidgetTester tester) =>
    tester.widget<TextField>(_input).controller!.text;

/// Types [text] and taps Send, as on a phone.
Future<void> _sendTyped(WidgetTester tester, String text) async {
  await tester.enterText(_input, text);
  await tester.pump();
  await tester.tap(_send);
  await tester.pumpAndSettle();
}

/// Dismisses the shown message so the next one is the one on screen.
Future<void> _dismissMessage(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-snack-bar-dismiss')));
  await tester.pumpAndSettle();
}

void main() {
  group('parsing and matching', () {
    test('a sent builtin is a leading / and its name, any case', () {
      expect(parseSessionBuiltinCommand('/new'), SessionBuiltinCommand.newChat);
      expect(
        parseSessionBuiltinCommand('  /MODELS later '),
        SessionBuiltinCommand.model,
      );
      expect(parseSessionBuiltinCommand('/model'), SessionBuiltinCommand.model);
      expect(parseSessionBuiltinCommand('/'), isNull);
      expect(parseSessionBuiltinCommand('/open'), isNull);
      expect(parseSessionBuiltinCommand('/review'), isNull);
      expect(parseSessionBuiltinCommand('please /new'), isNull);
    });

    test('the picker opens on a lone / and a word, not while composing', () {
      expect(sessionCommandQuery(const TextEditingValue(text: '/')), '');
      expect(sessionCommandQuery(const TextEditingValue(text: ' /mo')), 'mo');
      expect(sessionCommandQuery(const TextEditingValue(text: '/mo x')), null);
      expect(sessionCommandQuery(const TextEditingValue(text: 'x/')), null);
      expect(
        sessionCommandQuery(
          const TextEditingValue(
            text: '/mo',
            composing: TextRange(start: 1, end: 3),
          ),
        ),
        null,
      );
    });

    test('matches go by name, other name or description, in order', () {
      expect(
        sessionCommandSuggestions('', _l10n),
        SessionBuiltinCommand.values,
      );
      expect(sessionCommandSuggestions('MODELS', _l10n), [
        SessionBuiltinCommand.model,
      ]);
      expect(sessionCommandSuggestions('session', _l10n), [
        SessionBuiltinCommand.newChat,
        SessionBuiltinCommand.sessions,
        SessionBuiltinCommand.compact,
      ]);
      expect(sessionCommandSuggestions('zzz', _l10n), isEmpty);
    });

    test('turn actions stay unavailable until #455 binds them', () {
      for (final action in SessionTurnAction.values) {
        expect(
          unboundSessionTurnActions.unavailable(action),
          SessionTurnActionUnavailable.notYetAvailable,
        );
      }
    });
  });

  testWidgets(
    'typing / opens the picker; keys move, run and close it (#137)',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      final outbox = FakeOutbox();
      final graph = await _open(tester, outbox);
      await tester.tap(_input);
      await tester.enterText(_input, '/');
      await tester.pump();
      expect(_picker, findsOneWidget);
      expect(_command('new'), findsOneWidget);
      expect(_command('model'), findsOneWidget);

      // Down moves the highlight; Escape closes the picker and keeps the text.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester
            .widget<ListTile>(
              find.descendant(
                of: _command('model'),
                matching: find.byType(ListTile),
              ),
            )
            .selected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_picker, findsNothing);
      expect(_text(tester), '/');

      // A new word opens it again; Enter runs the only match.
      await tester.enterText(_input, '/thi');
      await tester.pump();
      expect(_command('thinking'), findsOneWidget);
      expect(_command('new'), findsNothing);
      expect(graph.preferences.showReasoning, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(graph.preferences.showReasoning, isFalse);
      expect(find.text(_l10n.commandThinkingHidden), findsOneWidget);
      expect(_text(tester), isEmpty);
      expect(_picker, findsNothing);

      // Tab runs the highlight too; the help lists every command and Enter
      // closes it.
      await tester.enterText(_input, '/he');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-command-help')), findsOneWidget);
      expect(find.text(_l10n.chatSlashCommandUndo), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-command-help')), findsNothing);
      expect(_submits(outbox), isEmpty);
    },
  );

  testWidgets('a tapped match runs it; a typed builtin is never sent', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final graph = await _open(tester, outbox);
    await tester.enterText(_input, '/thinking');
    await tester.pump();
    await tester.tap(_command('thinking'));
    await tester.pumpAndSettle();
    expect(graph.preferences.showReasoning, isFalse);
    await _dismissMessage(tester);

    // Undo, redo and compact say they are unavailable for this conversation when unbound.
    for (final name in ['undo', 'redo', 'compact']) {
      await _sendTyped(tester, '/$name');
      expect(
        find.text(_l10n.commandUnavailableHere),
        findsOneWidget,
        reason: name,
      );
      expect(_text(tester), isEmpty, reason: name);
      await _dismissMessage(tester);
    }

    // The /models alias opens the model picker; words after it are dropped.
    await _sendTyped(tester, '/MODELS please');
    expect(find.byKey(const ValueKey('live-selection-search')), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await _sendTyped(tester, '/agent');
    expect(find.byKey(const ValueKey('live-agent-menu')), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    // A server command stays a prompt (#292).
    await _sendTyped(tester, '/review');
    expect(_submits(outbox), hasLength(1));
    expect(outbox.calls.where((c) => c.contains('/review')), isNotEmpty);

    // /new opens the New Chat draft.
    await _sendTyped(tester, '/new');
    expect(find.byKey(const ValueKey('workspace-draft')), findsOneWidget);
    expect(_submits(outbox), hasLength(1));
  });

  testWidgets('/sessions opens the hidden pane of a wide window', (
    tester,
  ) async {
    final outbox = FakeOutbox();
    final graph = await _open(tester, outbox);
    graph.preferences.setSessionPaneHidden(true);
    await tester.pumpAndSettle();
    expect(find.byType(SessionsPage), findsNothing);
    await _sendTyped(tester, '/sessions');
    expect(graph.preferences.sessionPaneHidden, isFalse);
    expect(find.byType(SessionsPage), findsOneWidget);
  });

  testWidgets('/sessions opens the list drawer of a phone', (tester) async {
    final outbox = FakeOutbox();
    await _open(tester, outbox, size: const Size(390, 844));
    expect(sessionListDrawerOpen(tester), isFalse);
    await _sendTyped(tester, '/sessions');
    expect(sessionListDrawerOpen(tester), isTrue);
  });

  testWidgets(
    'with no room for a row the picker stays shut and takes no keys',
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
    (tester) async {
      final outbox = FakeOutbox();
      await _open(tester, outbox, size: const Size(360, 640), keyboard: 540);
      await tester.tap(_input);
      await tester.enterText(_input, '/');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_picker, findsNothing);
      // Enter is the field's again: no unseen command runs.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-draft')), findsNothing);
      expect(_submits(outbox).single, endsWith(' /'));
    },
  );

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the picker keeps the field above a phone keyboard (#278, '
        '${locale.languageCode})', (tester) async {
      const size = Size(360, 640);
      const keyboard = 300.0;
      final outbox = FakeOutbox();
      await _open(
        tester,
        outbox,
        size: size,
        locale: locale,
        keyboard: keyboard,
      );
      await tester.enterText(_input, '/');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_picker).height, lessThanOrEqualTo(240));
      // Hit tests honour the composer's clip, unlike screen rectangles: the
      // field, Send and the highlighted command are really shown.
      void shown() {
        for (final finder in [_input, _send]) {
          expect(finder.hitTestable(), findsOneWidget, reason: '$finder');
        }
        final active = find.byWidgetPredicate(
          (widget) => widget is ListTile && widget.selected,
        );
        expect(active.hitTestable(), findsOneWidget);
      }

      shown();
      expect(_command('new').hitTestable(), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        shown();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      shown();

      // The command help fits the phone above the keyboard and closes.
      await _sendTyped(tester, '/help');
      expect(tester.takeException(), isNull);
      final close = find.descendant(
        of: find.byKey(const ValueKey('live-command-help')),
        matching: find.byType(TextButton),
      );
      expect(close.hitTestable(), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-command-help')), findsNothing);
    });
  }
}
