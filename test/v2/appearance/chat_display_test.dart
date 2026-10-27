import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/features/settings/about_settings_page.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/rendering/canonical_message_body.dart';
import 'package:codewalk/shared/rendering/markdown_content.dart';
import 'package:codewalk/shared/theme/chat_appearance.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:codewalk/shared/widgets/searchable_picker.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

Widget _localized(Widget child) => MaterialApp(
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  home: Scaffold(body: child),
);

Finder _richContaining(String content) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(content),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppPreferencesController controller(FakeMetadataBackend backend) =>
      AppPreferencesController(store: V2MetadataStore(backend: backend));

  group('chat display preferences', () {
    test('round trip persists only non-default values', () async {
      final backend = FakeMetadataBackend();
      final first = controller(backend);
      addTearDown(first.dispose);
      await first.initialize();
      first.setSystemTextScale(1.25);
      first.setConversationTextScale(0.9);
      first.setMathRendering(false);
      await first.flush();
      expect(backend.values['cw2.settings.systemTextScale'], 1.25);
      expect(backend.values['cw2.settings.conversationTextScale'], 0.9);
      expect(backend.values['cw2.settings.mathRendering'], false);

      final second = controller(backend);
      addTearDown(second.dispose);
      await second.initialize();
      expect(second.systemTextScale, 1.25);
      expect(second.conversationTextScale, 0.9);
      expect(second.mathRendering, isFalse);

      second
        ..setSystemTextScale(1)
        ..setConversationTextScale(1)
        ..setMathRendering(true);
      await second.flush();
      expect(backend.values, isNot(contains('cw2.settings.systemTextScale')));
      expect(
        backend.values,
        isNot(contains('cw2.settings.conversationTextScale')),
      );
      expect(backend.values, isNot(contains('cw2.settings.mathRendering')));
    });

    test('stale or illegal stored scales are clamped or ignored', () async {
      final backend = FakeMetadataBackend()
        ..values.addAll({
          'cw2.schema': 1,
          'cw2.settings.systemTextScale': 3,
          'cw2.settings.conversationTextScale': 'large',
          'cw2.settings.mathRendering': 'no',
        });
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      expect(p.systemTextScale, AppPreferencesController.textScaleMax);
      expect(p.conversationTextScale, 1);
      expect(p.mathRendering, isTrue);
      expect(backend.writes, isEmpty);
    });

    test('setters clamp to the supported range and ignore NaN', () {
      final p = AppPreferencesController();
      addTearDown(p.dispose);
      p.setSystemTextScale(0.1);
      expect(p.systemTextScale, AppPreferencesController.textScaleMin);
      p.setConversationTextScale(9);
      expect(p.conversationTextScale, AppPreferencesController.textScaleMax);
      p.setConversationTextScale(double.nan);
      expect(p.conversationTextScale, AppPreferencesController.textScaleMax);
    });
  });

  group('text scaling', () {
    test('multiplied scaler keeps the inherited scaling', () {
      const scaler = MultipliedTextScaler(TextScaler.linear(1.5), 1.2);
      expect(scaler.scale(10), closeTo(18, 1e-9));
      expect(scaler, const MultipliedTextScaler(TextScaler.linear(1.5), 1.2));
    });

    testWidgets('conversation scale affects only its subtree', (tester) async {
      late BuildContext inside;
      late BuildContext outside;
      await tester.pumpWidget(
        ChatAppearance(
          mathRendering: true,
          conversationTextScale: 1.5,
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  outside = context;
                  return const SizedBox();
                },
              ),
              ConversationTextScale(
                child: Builder(
                  builder: (context) {
                    inside = context;
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(MediaQuery.textScalerOf(outside).scale(10), 10);
      expect(MediaQuery.textScalerOf(inside).scale(10), 15);
    });

    testWidgets('the system scale reaches every app surface', (tester) async {
      final graph = createAppDependencies(initialLink: Uri(path: '/settings'));
      addTearDown(graph.dispose);
      graph.preferences.setSystemTextScale(1.4);
      await tester.pumpWidget(
        CodeWalkV2Bootstrap(
          dependencies: graph,
          dynamicColors: (builder) => builder(null, null),
        ),
      );
      await tester.pumpAndSettle();
      final settings = tester.element(
        find.byKey(const ValueKey('settings_navigation_search')),
      );
      expect(MediaQuery.textScalerOf(settings).scale(10), closeTo(14, 1e-9));
    });
  });

  group('review regressions', () {
    testWidgets('only message tiles take the conversation scale', (
      tester,
    ) async {
      final item = AssistantText(
        meta: ItemMeta(
          id: const ItemId('test/a1'),
          generation: 'test',
          status: OpenValue.unknown('test'),
          source: SourceProvenance(
            harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
            version: '2.0.22',
            nativeType: 'assistant',
          ),
        ),
        text: 'Body',
        complete: true,
      );
      late BuildContext header;
      await tester.pumpWidget(
        _localized(
          ChatAppearance(
            mathRendering: true,
            conversationTextScale: 1.5,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    header = context;
                    return const Chip(label: Text('model'));
                  },
                ),
                SessionTimelineTile(item: item),
              ],
            ),
          ),
        ),
      );
      final body = tester.element(find.byType(Card));
      expect(MediaQuery.textScalerOf(body).scale(10), 15);
      expect(MediaQuery.textScalerOf(header).scale(10), 10);
    });

    testWidgets('the picker shrinks above the keyboard', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _localized(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showSearchablePicker(
                context,
                title: 'Option',
                options: {for (var i = 0; i < 40; i++) i: 'Option $i'},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('searchable_picker_search')),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('highlighted code follows the text scaler', (tester) async {
      await tester.pumpWidget(
        _localized(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: MarkdownContent(
                source: '```dart\nfinal answer = 42;\n```',
                enableCodeHighlight: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final code = tester.widget<RichText>(_richContaining('answer = 42'));
      expect(code.textScaler.scale(10), 20);
    });
  });

  group('math rendering', () {
    const source = r'Energy $E = mc^2$ here';

    for (final enabled in [true, false]) {
      testWidgets('math rendering ${enabled ? 'on' : 'off'}', (tester) async {
        await tester.pumpWidget(
          _localized(
            ChatAppearance(
              mathRendering: enabled,
              conversationTextScale: 1,
              child: const CanonicalMessageBody(source: source, complete: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          _richContaining(r'$E = mc^2$'),
          enabled ? findsNothing : findsOneWidget,
        );
      });
    }
  });

  group('settings surfaces', () {
    testWidgets('searchable picker filters, reports no matches and selects', (
      tester,
    ) async {
      AppDensity? picked;
      await tester.pumpWidget(
        _localized(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showSearchablePicker(
                context,
                title: 'Density',
                options: const {
                  AppDensity.dense: 'Dense',
                  AppDensity.normal: 'Normal',
                  AppDensity.spacious: 'Spacious',
                },
                selected: AppDensity.normal,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('searchable_picker_search'));
      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches found'), findsOneWidget);
      await tester.enterText(search, 'SPA');
      await tester.pumpAndSettle();
      expect(find.text('Dense'), findsNothing);
      await tester.tap(find.text('Spacious'));
      await tester.pumpAndSettle();
      expect(picked, AppDensity.spacious);
    });

    testWidgets('appearance exposes text sizes and the math switch', (
      tester,
    ) async {
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
      final p = graph.preferences;
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('settings_conversation_text_scale')),
          )
          .onChanged!(1.3);
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('settings_system_text_scale')),
          )
          .onChanged!(0.9);
      await tester.pump();
      expect(p.conversationTextScale, 1.3);
      expect(p.systemTextScale, 0.9);
      expect(find.textContaining('130%'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings_toggle_math_rendering')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('appearance_settings_list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(
        find.byKey(const ValueKey('settings_toggle_math_rendering')),
      );
      await tester.pumpAndSettle();
      expect(p.mathRendering, isFalse);
    });

    testWidgets('settings search finds About through Telegram', (tester) async {
      final graph = createAppDependencies(initialLink: Uri(path: '/settings'));
      addTearDown(graph.dispose);
      await tester.pumpWidget(
        CodeWalkV2Bootstrap(
          dependencies: graph,
          dynamicColors: (builder) => builder(null, null),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('settings_navigation_search')),
        'telegram',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_destination_about')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_destination_appearance')),
        findsNothing,
      );
    });

    testWidgets('About opens GitHub and Telegram externally', (tester) async {
      final opened = <Uri>[];
      var result = true;
      await tester.pumpWidget(
        _localized(
          AboutSettingsPage(
            open: (uri) async {
              opened.add(uri);
              return result;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('about_telegram')));
      await tester.tap(find.byKey(const ValueKey('about_github')));
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse('https://t.me/codewalkapp'),
        Uri.parse('https://github.com/verseles/codewalk'),
      ]);
      expect(find.text('Unable to open link'), findsNothing);
      result = false;
      await tester.tap(find.byKey(const ValueKey('about_telegram')));
      await tester.pumpAndSettle();
      expect(find.text('Unable to open link'), findsOneWidget);
    });
  });
}
