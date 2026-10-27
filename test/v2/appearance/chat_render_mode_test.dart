import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

Future<AppDependencies> _settings(WidgetTester tester) async {
  final graph = createAppDependencies(initialLink: Uri(path: '/settings'));
  addTearDown(graph.dispose);
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CodeWalkV2Bootstrap(
      dependencies: graph,
      dynamicColors: (builder) => builder(null, null),
    ),
  );
  await tester.pumpAndSettle();
  return graph;
}

ChatAppearance _appearance(WidgetTester tester) =>
    tester.widget<ChatAppearance>(find.byType(ChatAppearance).first);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppPreferencesController controller(FakeMetadataBackend backend) =>
      AppPreferencesController(store: V2MetadataStore(backend: backend));

  group('render mode and display preferences', () {
    test('round trip persists only non-default values', () async {
      final backend = FakeMetadataBackend();
      final first = controller(backend);
      addTearDown(first.dispose);
      await first.initialize();
      first
        ..setChatRenderMode(ChatRenderMode.block)
        ..setShowReasoning(false)
        ..setShowToolCalls(false)
        ..setComposerSpellCheck(false);
      await first.flush();
      expect(backend.values['cw2.settings.chatRenderMode'], 'block');
      expect(backend.values['cw2.settings.showReasoning'], false);
      expect(backend.values['cw2.settings.showToolCalls'], false);
      expect(backend.values['cw2.settings.composerSpellCheck'], false);

      final second = controller(backend);
      addTearDown(second.dispose);
      await second.initialize();
      expect(second.chatRenderMode, ChatRenderMode.block);
      expect(second.showReasoning, isFalse);
      expect(second.showToolCalls, isFalse);
      expect(second.composerSpellCheck, isFalse);

      second
        ..setChatRenderMode(ChatRenderMode.live)
        ..setShowReasoning(true)
        ..setShowToolCalls(true)
        ..setComposerSpellCheck(true);
      await second.flush();
      for (final key in [
        'chatRenderMode',
        'showReasoning',
        'showToolCalls',
        'composerSpellCheck',
      ]) {
        expect(backend.values, isNot(contains('cw2.settings.$key')));
      }
    });

    test('unknown or illegal stored values keep the defaults', () async {
      final backend = FakeMetadataBackend()
        ..values.addAll({
          'cw2.schema': 1,
          'cw2.settings.chatRenderMode': 'stream',
          'cw2.settings.showReasoning': 'no',
          'cw2.settings.showToolCalls': 0,
          'cw2.settings.composerSpellCheck': 'off',
        });
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      expect(p.chatRenderMode, ChatRenderMode.live);
      expect(p.showReasoning, isTrue);
      expect(p.showToolCalls, isTrue);
      expect(p.composerSpellCheck, isTrue);
      expect(backend.writes, isEmpty);
    });
  });

  group('settings surfaces', () {
    testWidgets('Behavior switches the render mode for the chat', (
      tester,
    ) async {
      final graph = await _settings(tester);
      final l10n = V2Localizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      await tester.tap(
        find.byKey(const ValueKey('settings_destination_behavior')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.settingsBehaviorChatRenderModeLiveDescription),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.settingsBehaviorChatRenderModeBlock));
      await tester.pumpAndSettle();
      expect(graph.preferences.chatRenderMode, ChatRenderMode.block);
      expect(_appearance(tester).renderMode, ChatRenderMode.block);
      expect(
        find.text(l10n.settingsBehaviorChatRenderModeBlockDescription),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('settings_toggle_composer_spell_check')),
      );
      await tester.pumpAndSettle();
      expect(graph.preferences.composerSpellCheck, isFalse);
      expect(_appearance(tester).composerSpellCheck, isFalse);
    });

    testWidgets('Appearance hides reasoning and tool calls', (tester) async {
      final graph = await _settings(tester);
      await tester.tap(
        find.byKey(const ValueKey('settings_destination_appearance')),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'settings_toggle_thinking_bubbles',
        'settings_toggle_tool_call_bubbles',
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('appearance_settings_list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }
      final p = graph.preferences;
      expect([p.showReasoning, p.showToolCalls], [false, false]);
      final appearance = _appearance(tester);
      expect(
        [appearance.showReasoning, appearance.showToolCalls],
        [false, false],
      );
    });

    testWidgets('settings search finds Behavior by its modes', (tester) async {
      await _settings(tester);
      await tester.enterText(
        find.byKey(const ValueKey('settings_navigation_search')),
        'block',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_destination_behavior')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_destination_about')),
        findsNothing,
      );
    });
  });
}
