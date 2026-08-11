import 'dart:convert';

import 'package:codewalk/core/i18n/app_locales.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/l10n/generated/app_localizations.dart';
import 'package:codewalk/presentation/pages/settings_page.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/session_attention/session_attention_host_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/update_check_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

void main() {
  setUp(_setPackageInfoVersion);

  testWidgets('hides shortcuts on mobile and opens notifications section', (
    WidgetTester tester,
  ) async {
    final local = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
    final dioClient = _buildDioClient(
      _MockDioAdapter()..enqueue(<_MockResponse>[
        _MockResponse(200, <String, dynamic>{}),
        _MockResponse(200, <String, dynamic>{
          'model': 'anthropic/claude-3-5-sonnet',
          'default_agent': 'plan',
          'username': 'helio',
          'snapshot': false,
          'autoupdate': 'notify',
          'share': 'auto',
        }),
        _MockResponse(200, <String, dynamic>{
          'all': <dynamic>[
            <String, dynamic>{
              'id': 'anthropic',
              'name': 'Anthropic',
              'env': <String>['ANTHROPIC_API_KEY'],
              'models': <String, dynamic>{
                'claude-3-5-sonnet': <String, dynamic>{
                  'id': 'claude-3-5-sonnet',
                  'name': 'Claude 3.5 Sonnet',
                  'release_date': '2025-01-01',
                  'capabilities': <String, dynamic>{
                    'attachment': true,
                    'reasoning': true,
                    'temperature': false,
                    'toolcall': true,
                  },
                  'cost': <String, dynamic>{'input': 1, 'output': 2},
                  'limit': <String, dynamic>{'context': 1000, 'output': 100},
                },
              },
            },
          ],
          'default': <String, String>{'anthropic': 'claude-3-5-sonnet'},
          'connected': <String>['anthropic'],
        }),
        _MockResponse(200, <dynamic>[
          <String, dynamic>{
            'name': 'build',
            'mode': 'primary',
            'hidden': false,
            'native': true,
          },
          <String, dynamic>{
            'name': 'plan',
            'mode': 'primary',
            'hidden': false,
            'native': true,
          },
        ]),
      ]),
    );
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      dioClient: dioClient,
      soundService: SoundService(),
      sessionAttentionHostService: _WidgetSessionAttentionHostService(),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: _localizedMaterialApp(home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Setup Wizard'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings_replay_chat_tour_button')),
      findsOneWidget,
    );
    expect(find.text('Replay chat tour'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Speech to text'), findsOneWidget);
    expect(find.text('Sounds'), findsNothing);
    expect(find.text('Shortcuts'), findsNothing);
    expect(find.text('Servers'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Logs'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Logs'), findsOneWidget);

    await tester.tap(find.text('Appearance').first);
    await tester.pumpAndSettle();

    expect(find.text('CodeWalk Classic'), findsOneWidget);
    expect(find.text('OpenCode Presets'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings_visual_style_segmented')),
      findsOneWidget,
    );
    expect(find.text('Visual style'), findsOneWidget);

    await tester.tap(find.text('Refined'));
    await tester.pumpAndSettle();

    expect(settingsProvider.visualStyle, VisualStyle.refined);
    expect(jsonDecode(local.experienceSettingsJson!)['visualStyle'], 'refined');

    await tester.tap(find.text('OpenCode Presets'));
    await tester.pumpAndSettle();

    expect(settingsProvider.themePreset, OpenCodeThemePreset.oc2);
    expect(
      find.byKey(const ValueKey<String>('settings_theme_preset_dropdown')),
      findsOneWidget,
    );
    expect(find.text('OC-2'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings_theme_preset_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'amo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();

    expect(settingsProvider.themePreset, OpenCodeThemePreset.amoled);

    await tester.tap(find.text('CodeWalk Classic'));
    await tester.pumpAndSettle();

    expect(settingsProvider.themePreset, isNull);

    // Density card may be below the fold after Theme/Color/Contrast cards.
    await tester.scrollUntilVisible(
      find.text('Extra Dense'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Extra Dense'), findsOneWidget);
    expect(find.text('Dense'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Spacious'), findsOneWidget);
    expect(find.text('Extra Spacious'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('settings_toggle_composer_tips')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Composer tips'), findsOneWidget);
    expect(find.text('Task list'), findsOneWidget);

    final composerTipsFinder = find.byKey(
      const ValueKey<String>('settings_toggle_composer_tips'),
    );
    expect(tester.widget<SwitchListTile>(composerTipsFinder).value, isTrue);

    await tester.tap(composerTipsFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(composerTipsFinder).value, isFalse);
    expect(settingsProvider.showComposerTips, isFalse);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Behavior').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Permission handling provenance'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('OpenCode-backed defaults', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Permission handling provenance', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('CodeWalk exception'), findsWidgets);
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_default_model'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_default_agent'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_username'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_username_save'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_snapshot'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_small_model'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_autoupdate'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('settings_opencode_share_mode'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final dataSaverLevelFinder = find.byKey(
      const ValueKey<String>('settings_data_saver_level'),
    );
    expect(dataSaverLevelFinder, findsOneWidget);
    expect(settingsProvider.dataSaverLevel, DataSaverLevel.standard);

    await tester.tap(
      find.descendant(of: dataSaverLevelFinder, matching: find.text('Off')),
    );
    await tester.pumpAndSettle();

    expect(settingsProvider.dataSaverLevel, DataSaverLevel.off);
    expect(settingsProvider.dataSaverEnabled, isFalse);

    final sessionAttentionFinder = find.byKey(
      const ValueKey<String>('settings_session_attention_mode'),
    );
    await tester.scrollUntilVisible(
      sessionAttentionFinder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(sessionAttentionFinder, findsOneWidget);
    expect(find.text('Session attention'), findsOneWidget);
    expect(find.text('Bubble'), findsOneWidget);
    expect(find.text('Panel'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: sessionAttentionFinder,
        matching: find.text('Bubble'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      settingsProvider.sessionAttentionPresentation,
      SessionAttentionPresentation.bubble,
    );
    expect(
      jsonDecode(local.experienceSettingsJson!)['sessionAttentionPresentation'],
      'bubble',
    );

    final syncToggleFinder = find.byKey(
      const ValueKey<String>('settings_toggle_experimental_multi_device_sync'),
    );
    await tester.scrollUntilVisible(
      syncToggleFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(syncToggleFinder, findsOneWidget);
    expect(find.text('Enable experimental multi-device sync'), findsOneWidget);
    expect(
      find.text(
        'Can abort ongoing sessions when working in more than one session at the same time.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<SwitchListTile>(syncToggleFinder).value, isFalse);

    await tester.tap(syncToggleFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(syncToggleFinder).value, isTrue);
    expect(settingsProvider.enableExperimentalMultiDeviceSync, isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('About'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('About').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('about_replay_chat_tour_tile')),
      findsOneWidget,
    );
    expect(find.text('Replay chat tour'), findsOneWidget);
    expect(
      find.text('Close settings and show the guided chat walkthrough'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Behavior render mode stays selected across navigation and hydration',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final local = _StaleReadExperienceSettingsDataSource()
        ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
      final firstProvider = SettingsProvider(
        localDataSource: local,
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      await firstProvider.initialize();
      addTearDown(firstProvider.dispose);
      final staleLiveSettingsJson = local.experienceSettingsJson!;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: firstProvider,
          child: _localizedMaterialApp(
            home: const SettingsPage(initialSectionId: 'behavior'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderModeFinder = find.byKey(
        const ValueKey<String>('settings_chat_render_mode'),
      );
      await tester.scrollUntilVisible(
        renderModeFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      Set<ChatRenderMode> selectedMode() => tester
          .widget<SegmentedButton<ChatRenderMode>>(renderModeFinder)
          .selected;

      expect(selectedMode(), <ChatRenderMode>{ChatRenderMode.live});
      expect(
        find.text(
          'Show assistant text, reasoning, and tool activity as OpenCode streams events.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: renderModeFinder, matching: find.text('Block')),
      );
      await tester.pumpAndSettle();

      expect(firstProvider.chatRenderMode, ChatRenderMode.block);
      expect(selectedMode(), <ChatRenderMode>{ChatRenderMode.block});
      expect(
        find.text(
          'Hide live assistant text, reasoning, and tool cards until the current turn can be shown as one block.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Behavior').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        renderModeFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(selectedMode(), <ChatRenderMode>{ChatRenderMode.block});

      await tester.tap(
        find.descendant(of: renderModeFinder, matching: find.text('Live')),
      );
      await tester.pumpAndSettle();
      expect(selectedMode(), <ChatRenderMode>{ChatRenderMode.live});

      await tester.tap(
        find.descendant(of: renderModeFinder, matching: find.text('Block')),
      );
      await tester.pumpAndSettle();
      expect(selectedMode(), <ChatRenderMode>{ChatRenderMode.block});
      expect(
        jsonDecode(local.experienceSettingsJson!)['chatRenderMode'],
        'block',
      );

      local.readOverride = staleLiveSettingsJson;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(firstProvider.chatRenderMode, ChatRenderMode.block);
      expect(selectedMode(), <ChatRenderMode>{ChatRenderMode.block});
      local.readOverride = null;

      final secondProvider = SettingsProvider(
        localDataSource: local,
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      await secondProvider.initialize();
      addTearDown(secondProvider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: secondProvider,
          child: _localizedMaterialApp(
            home: const SettingsPage(initialSectionId: 'behavior'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        renderModeFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(secondProvider.chatRenderMode, ChatRenderMode.block);
      expect(selectedMode(), <ChatRenderMode>{ChatRenderMode.block});
    },
  );

  testWidgets('settings landing shows update banner above normal actions', (
    WidgetTester tester,
  ) async {
    _setPackageInfoVersion(version: '1.2.3', buildNumber: '45');
    final local = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
      updateCheckService: _FakeUpdateCheckService(
        const UpdateCheckResult(
          latestVersion: '1.3.0',
          releaseUrl:
              'https://github.com/verseles/codewalk/releases/tag/v1.3.0',
          apkUrl:
              'https://github.com/verseles/codewalk/releases/download/v1.3.0/codewalk.apk',
          isNewer: true,
        ),
      ),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);
    await settingsProvider.checkForUpdate();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: _localizedMaterialApp(home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    final bannerFinder = find.byKey(
      const ValueKey<String>('settings_update_available_banner'),
    );
    expect(bannerFinder, findsOneWidget);
    expect(find.text('Update available: v1.3.0'), findsOneWidget);
    expect(
      find.text('Current: 1.2.3 (build 45); available: v1.3.0'),
      findsOneWidget,
    );
    expect(find.text('Install update'), findsOneWidget);
    expect(
      tester.getTopLeft(bannerFinder).dy,
      lessThan(tester.getTopLeft(find.text('Setup Wizard')).dy),
    );
  });

  testWidgets('Behavior settings toggles composer spell check preference', (
    WidgetTester tester,
  ) async {
    final local = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: _localizedMaterialApp(home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Behavior').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey<String>('settings_toggle_composer_spell_check'),
      ),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final toggleFinder = find.byKey(
      const ValueKey<String>('settings_toggle_composer_spell_check'),
    );
    expect(find.text('Composer spell check'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);
    expect(settingsProvider.composerSpellCheckEnabled, isFalse);
    final persisted = jsonDecode(local.experienceSettingsJson!) as Map;
    expect(persisted['composerSpellCheckEnabled'], isFalse);
  });

  testWidgets('unsupported update platform opens release page fallback', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      _setPackageInfoVersion(version: '1.2.3', buildNumber: '45');
      final local = InMemoryAppLocalDataSource()
        ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
      final settingsProvider = SettingsProvider(
        localDataSource: local,
        dioClient: DioClient(),
        soundService: SoundService(),
        updateCheckService: _FakeUpdateCheckService(
          const UpdateCheckResult(
            latestVersion: '1.3.0',
            releaseUrl:
                'https://github.com/verseles/codewalk/releases/tag/v1.3.0',
            isNewer: true,
          ),
        ),
      );
      await settingsProvider.initialize();
      addTearDown(settingsProvider.dispose);
      await settingsProvider.checkForUpdate();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: _localizedMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('settings_update_available_banner')),
        findsOneWidget,
      );
      expect(find.text('Install update'), findsNothing);
      expect(find.text('GitHub'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('settings landing hides update banner when current is latest', (
    WidgetTester tester,
  ) async {
    final local = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
      updateCheckService: _FakeUpdateCheckService(
        const UpdateCheckResult(latestVersion: '1.138.1', isNewer: false),
      ),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);
    await settingsProvider.checkForUpdate();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: _localizedMaterialApp(home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('settings_update_available_banner')),
      findsNothing,
    );
    expect(find.text('Setup Wizard'), findsOneWidget);
  });

  testWidgets('mobile back follows detail then list then app flow', (
    WidgetTester tester,
  ) async {
    final local = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: _localizedMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey<String>('open_settings_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    child: const Text('Open settings'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('open_settings_button')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(find.text('Appearance').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('settings_toggle_composer_tips')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Composer tips'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('settings replay chat tour button arms flag and closes page', (
    WidgetTester tester,
  ) async {
    final local = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = jsonEncode(<String, dynamic>{
        'checkUpdatesOnOpen': false,
        'pendingPostOnboardingChatTour': false,
      });
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: _localizedMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey<String>('open_settings_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    child: const Text('Open settings'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('open_settings_button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('settings_replay_chat_tour_button')),
    );
    await tester.pumpAndSettle();

    expect(settingsProvider.pendingPostOnboardingChatTour, isTrue);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('about replay chat tour arms flag and closes settings', (
    WidgetTester tester,
  ) async {
    final local = InMemoryAppLocalDataSource()
      ..experienceSettingsJson = jsonEncode(<String, dynamic>{
        'checkUpdatesOnOpen': false,
        'pendingPostOnboardingChatTour': false,
      });
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await settingsProvider.initialize();
    addTearDown(settingsProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: _localizedMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey<String>('open_settings_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                    child: const Text('Open settings'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('open_settings_button')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('About'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('About').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('about_replay_chat_tour_tile')),
    );
    await tester.pumpAndSettle();

    expect(settingsProvider.pendingPostOnboardingChatTour, isTrue);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('desktop shortcuts section shows local provenance', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final local = InMemoryAppLocalDataSource()
        ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
      final settingsProvider = SettingsProvider(
        localDataSource: local,
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      await settingsProvider.initialize();
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: _localizedMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Shortcuts'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Shortcuts'), findsOneWidget);

      await tester.tap(find.text('Shortcuts').first);
      await tester.pumpAndSettle();

      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('CodeWalk-local'), findsOneWidget);
      expect(
        find.text(
          'These bindings are stored in CodeWalk for the current app runtime and do not edit OpenCode `tui.json` keybinds.',
        ),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows Android background alert controls in notifications', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final local = InMemoryAppLocalDataSource()
        ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}';
      final settingsProvider = SettingsProvider(
        localDataSource: local,
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      await settingsProvider.initialize();
      addTearDown(settingsProvider.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settingsProvider,
          child: _localizedMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notifications').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Android background alerts'), findsOneWidget);
      expect(find.text('Background alerts on Android'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('settings_toggle_android_background_alerts'),
        ),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void _setPackageInfoVersion({
  String version = '1.138.1',
  String buildNumber = '1782268765',
}) {
  PackageInfo.setMockInitialValues(
    appName: 'CodeWalk',
    packageName: 'com.verseles.codewalk',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
}

class _MockResponse {
  _MockResponse(this.statusCode, this.data);

  final int statusCode;
  final dynamic data;
}

class _StaleReadExperienceSettingsDataSource
    extends InMemoryAppLocalDataSource {
  String? readOverride;

  @override
  Future<String?> getExperienceSettingsJson() async {
    return readOverride ?? super.getExperienceSettingsJson();
  }
}

class _WidgetSessionAttentionHostService
    implements SessionAttentionHostService {
  var _running = false;

  @override
  Future<SessionAttentionHostActivationResult> activate(
    SessionAttentionPresentation presentation,
  ) async {
    _running = presentation != SessionAttentionPresentation.off;
    return SessionAttentionHostActivationResult.success(await capability());
  }

  @override
  Future<SessionAttentionHostCapability> capability() async {
    return SessionAttentionHostCapability(
      kind: SessionAttentionHostKind.desktopWindow,
      supported: true,
      permissionGranted: true,
      running: _running,
      topmostSupported: true,
    );
  }

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> stop() async {
    _running = false;
  }
}

class _MockDioAdapter implements HttpClientAdapter {
  final List<_MockResponse> _responses = <_MockResponse>[];
  int callCount = 0;

  void enqueue(List<_MockResponse> items) {
    _responses.addAll(items);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (callCount >= _responses.length) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'No more mock responses (call #$callCount)',
      );
    }

    final mock = _responses[callCount];
    callCount += 1;

    if (mock.statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: mock.statusCode,
          data: mock.data,
        ),
      );
    }

    return ResponseBody.fromString(
      _encode(mock.data),
      mock.statusCode,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  String _encode(dynamic data) {
    if (data == null) {
      return '';
    }
    if (data is String) {
      return data;
    }
    return jsonEncode(data);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeUpdateCheckService extends UpdateCheckService {
  _FakeUpdateCheckService(this.result);

  final UpdateCheckResult? result;

  @override
  Future<UpdateCheckResult?> check(String currentVersion) async => result;

  @override
  void clearCache() {}
}

DioClient _buildDioClient(_MockDioAdapter adapter) {
  final dioClient = DioClient();
  dioClient.dio.httpClientAdapter = adapter;
  return dioClient;
}

MaterialApp _localizedMaterialApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('en'),
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocales.supported,
    home: home,
  );
}
