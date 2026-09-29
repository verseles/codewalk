import 'dart:convert';

import 'package:codewalk/core/i18n/l10n_bridge.dart';
import 'package:codewalk/l10n/generated/app_localizations_en.dart';
import 'package:codewalk/presentation/pages/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../support/chat_page_test_harness.dart';
import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('composer receiving tips cover actionable agent prompt practices', () {
    final l10n = AppLocalizationsEn();
    final tips = buildComposerReceivingTips(l10n);
    int? randomUpperBound;
    final pickedIndex = pickComposerReceivingTipIndex(l10n, (max) {
      randomUpperBound = max;
      return 0;
    });
    expect(tips, hasLength(greaterThanOrEqualTo(20)));
    expect(tips.toSet(), hasLength(tips.length));
    expect(tips.every((tip) => tip.startsWith('Tip: ')), isTrue);
    expect(tips.every((tip) => tip.length <= 80), isTrue);
    expect(tips, contains('Tip: Start with the end goal'));
    expect(tips, contains('Tip: Name relevant files, screens, or commands'));
    expect(tips, contains('Tip: State constraints the agent must preserve'));
    expect(tips, contains('Tip: Say which tests or checks should pass'));
    expect(tips, contains('Tip: Add acceptance criteria for larger changes'));
    expect(pickedIndex, 0);
    expect(randomUpperBound, tips.length);
  });

  group('ChatPage responsive shell', () {
    testWidgets('shows drawer on mobile width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
      final provider = buildChatPageProvider(localDataSource: source);
      final appProvider = buildChatPageAppProvider(localDataSource: source);
      addTearDown(() {
        provider.dispose();
        provider.projectProvider.dispose();
        appProvider.dispose();
      });
      await tester.pumpWidget(buildChatPageTestApp(provider, appProvider));
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.menu), findsOneWidget);
      expect(find.text('Desktop Shortcuts'), findsNothing);
    });

    testWidgets('mobile new chat from drawer closes the drawer', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
      final provider = buildChatPageProvider(localDataSource: source);
      final appProvider = buildChatPageAppProvider(localDataSource: source);
      addTearDown(() {
        provider.dispose();
        provider.projectProvider.dispose();
        appProvider.dispose();
      });
      await tester.pumpWidget(buildChatPageTestApp(provider, appProvider));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('appbar_drawer_button')),
      );
      await tester.pumpAndSettle();
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      expect(scaffold.isDrawerOpen, isTrue);
      await tester.tap(
        find.byKey(const ValueKey<String>('sidebar_new_chat_button')),
      );
      await tester.pumpAndSettle();
      expect(scaffold.isDrawerOpen, isFalse);
      expect(find.text('How can I help you today?'), findsOneWidget);
    });

    testWidgets('mobile new chat shortcut closes an open drawer', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
      final provider = buildChatPageProvider(localDataSource: source);
      final appProvider = buildChatPageAppProvider(localDataSource: source);
      addTearDown(() {
        provider.dispose();
        provider.projectProvider.dispose();
        appProvider.dispose();
      });
      await tester.pumpWidget(buildChatPageTestApp(provider, appProvider));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('appbar_drawer_button')),
      );
      await tester.pumpAndSettle();
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      expect(scaffold.isDrawerOpen, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(scaffold.isDrawerOpen, isFalse);
      expect(find.text('How can I help you today?'), findsOneWidget);
    });

    testWidgets('shows utility pane on large desktop width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test'
        ..experienceSettingsJson = jsonEncode(<String, dynamic>{
          'checkUpdatesOnOpen': false,
          'composerAutoApprovePermissions': false,
        });
      final provider = buildChatPageProvider(localDataSource: source);
      final appProvider = buildChatPageAppProvider(localDataSource: source);
      addTearDown(() {
        provider.dispose();
        provider.projectProvider.dispose();
        appProvider.dispose();
      });
      await tester.pumpWidget(buildChatPageTestApp(provider, appProvider));
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.menu), findsNothing);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.textContaining('Ctrl/Cmd'), findsNothing);
      expect(find.text('Ctrl+N'), findsOneWidget);
      expect(find.text('Alt+Shift+S'), findsOneWidget);
      expect(find.text('Ctrl+P'), findsOneWidget);
      expect(find.text('Ctrl+,'), findsOneWidget);
      expect(find.text('Ctrl+M'), findsOneWidget);
      expect(find.text('Ctrl+T'), findsOneWidget);
      expect(find.text('Esc, Esc'), findsOneWidget);
      expect(find.text(L10nBridge.current!.chatConversations), findsOneWidget);
    });
  });
}
