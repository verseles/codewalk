import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/pages/settings/sections/appearance_settings_section.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_icon_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/project_icon_models.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/theme/opencode_theme_presets.dart';
import 'package:codewalk/presentation/widgets/app_tab_strip.dart';
import 'package:codewalk/presentation/widgets/session_tab_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/project_icon_fakes.dart';
import '../support/pump_localized_app.dart';

SettingsProvider _settings() => SettingsProvider(
  localDataSource: InMemoryAppLocalDataSource(),
  dioClient: DioClient(),
  soundService: SoundService(),
);

SessionTabRecord _tab(
  String id, {
  bool selected = false,
  bool pinned = false,
}) => SessionTabRecord(
  identity: SessionTabIdentity(
    serverId: 'server',
    directory: '/repo/palette',
    sessionId: id,
  ),
  projectId: 'palette',
  title: id,
  lastOpenedAtMs: 0,
  serverUpdatedAtMs: 0,
  status: SessionStatusType.idle,
  isSelected: selected,
  isPinned: pinned,
  errorToken: 'attention',
);

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  test('light presets keep project palette visible', () {
    for (final preset in openCodeThemePresetOptions()) {
      final scheme = openCodeLightSchemeFor(preset)!;
      for (final selected in [true, false]) {
        final base = selected ? scheme.surface : scheme.surfaceContainerHigh;
        for (final seed in [Colors.red, Colors.blue, Colors.green]) {
          final foreground = projectTabPaletteForeground(
            scheme,
            seed,
            selected: selected,
          );
          final overlays = [
            Colors.transparent,
            scheme.primary.withValues(alpha: .09),
            scheme.primary.withValues(alpha: .14),
          ];
          final fill = projectTabSurface(
            seed,
            base,
            [foreground],
            selected: selected,
            overlays: overlays,
          );
          for (final overlay in overlays) {
            expect(
              _contrast(foreground, Color.alphaBlend(overlay, fill)),
              greaterThanOrEqualTo(4.5),
              reason: '$preset, $seed, selected=$selected, overlay=$overlay',
            );
          }
          expect(
            fill,
            isNot(base),
            reason: '$preset, $seed, selected=$selected',
          );
          final channelDelta = math.max(
            (fill.r - base.r).abs(),
            math.max((fill.g - base.g).abs(), (fill.b - base.b).abs()),
          );
          expect(
            channelDelta,
            greaterThanOrEqualTo(selected ? .02 : .01),
            reason: '$preset, $seed, selected=$selected',
          );
        }
      }
    }
  });

  for (final mode in ['light', 'dark', 'amoled']) {
    for (final integrated in [false, true]) {
      testWidgets(
        '$mode palettes update in ${integrated ? 'integrated' : 'compact'} chrome with attention icons',
        (tester) async {
          final settings = _settings();
          final icon = paletteIcon(
            utf8.encode(
              '<svg viewBox="0 0 10 10"><rect width="10" height="10" fill="red"/></svg>',
            ),
            format: ProjectIconFormat.svg,
          );
          final discovery = PaletteDiscovery();
          final icons = ProjectIconProvider(
            store: PaletteStore(icon),
            discoveryService: discovery,
            extractColor: (_) async => Colors.red,
          );
          addTearDown(settings.dispose);
          addTearDown(icons.dispose);
          var scheme = mode == 'light'
              ? openCodeLightSchemeFor(OpenCodeThemePreset.oc2)!
              : ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.dark,
                );
          if (mode == 'amoled') {
            scheme = scheme.copyWith(
              surface: Colors.black,
              surfaceContainerHigh: Colors.black,
            );
          }
          final selected = _tab('active', selected: true);
          final inactive = _tab(
            'inactive',
            pinned: true,
          ).copyWith(iconPresetId: 'design', errorToken: null);
          Color fill(SessionTabRecord tab) => tester
              .widget<Material>(
                find.byKey(
                  ValueKey(
                    'session_tab_${sessionTabIdentityKey(tab.identity)}',
                  ),
                ),
              )
              .color!;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider<ProjectIconProvider>.value(value: icons),
              ],
              child: localizedMaterialApp(
                theme: ThemeData(colorScheme: scheme),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: integrated ? 800 : 360,
                      child: SessionTabStrip(
                        tabs: [selected, inactive],
                        projects: [paletteProject()],
                        openProjectIds: const {},
                        isCompact: !integrated,
                        fillWidth: !integrated,
                        transparentBackground: integrated,
                        onActivate: (_) {},
                        onClose: (_) {},
                        onContextMenu: (_, _, {required haptic}) async {},
                        trailingBuilder: (_, _) => null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(fill(selected), isNot(scheme.surface));
          expect(fill(inactive), isNot(Colors.transparent));
          expect(fill(selected), isNot(fill(inactive)));
          expect(
            tester
                .widget<Icon>(
                  find.byKey(
                    ValueKey(
                      'session_tab_custom_icon_${sessionTabIdentityKey(inactive.identity)}',
                    ),
                  ),
                )
                .color,
            mode == 'light' ? Colors.black : scheme.onSurfaceVariant,
          );
          expect(
            discovery.calls,
            0,
            reason: 'closed projects only load stored icons',
          );
          expect(
            find.byKey(
              ValueKey(
                'session_tab_leading_error_${sessionTabIdentityKey(selected.identity)}',
              ),
            ),
            findsOneWidget,
          );
          if (mode == 'amoled') {
            expect(
              find.byKey(
                ValueKey(
                  'session_tab_selection_indicator_${sessionTabIdentityKey(selected.identity)}',
                ),
              ),
              findsOneWidget,
            );
          }
          await settings.setUseProjectIconTabColors(false);
          await tester.pumpAndSettle();
          expect(fill(selected), scheme.surface);
          expect(fill(inactive), Colors.transparent);
          expect(
            tester
                .widget<Icon>(
                  find.byKey(
                    ValueKey(
                      'session_tab_custom_icon_${sessionTabIdentityKey(inactive.identity)}',
                    ),
                  ),
                )
                .color,
            scheme.onSurfaceVariant,
          );
          await settings.setUseProjectIconTabColors(true);
          await tester.pumpAndSettle();
          expect(fill(selected), isNot(scheme.surface));
          await icons.discoverIcon(paletteProject());
          await tester.pumpAndSettle();
          expect(fill(selected), scheme.surface);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('palette uses expected selected custom glyph color by theme', (
    tester,
  ) async {
    final settings = _settings();
    final icons = ProjectIconProvider(
      store: PaletteStore(paletteIcon([1])),
      discoveryService: PaletteDiscovery(),
      extractColor: (_) async => Colors.red,
    );
    addTearDown(settings.dispose);
    addTearDown(icons.dispose);
    final scheme = openCodeLightSchemeFor(OpenCodeThemePreset.oc2)!;
    final selected = _tab(
      'custom',
      selected: true,
    ).copyWith(iconPresetId: 'design', errorToken: null);
    final iconKey = ValueKey<String>(
      'session_tab_custom_icon_${sessionTabIdentityKey(selected.identity)}',
    );
    final tabKey = ValueKey<String>(
      'session_tab_${sessionTabIdentityKey(selected.identity)}',
    );
    Widget appFor(ColorScheme colorScheme) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<ProjectIconProvider>.value(value: icons),
      ],
      child: localizedMaterialApp(
        theme: ThemeData(colorScheme: colorScheme),
        home: Scaffold(
          body: SessionTabStrip(
            tabs: [selected],
            projects: [paletteProject()],
            openProjectIds: const {},
            isCompact: true,
            onActivate: (_) {},
            onClose: (_) {},
            onContextMenu: (_, _, {required haptic}) async {},
            trailingBuilder: (_, _) => null,
          ),
        ),
      ),
    );
    await tester.pumpWidget(appFor(scheme));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Material>(find.byKey(tabKey)).color,
      isNot(scheme.surface),
    );
    expect(tester.widget<Icon>(find.byKey(iconKey)).color, Colors.black);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              ValueKey<String>(
                'session_tab_title_${sessionTabIdentityKey(selected.identity)}',
              ),
            ),
          )
          .style
          ?.color,
      Colors.black,
    );
    await settings.setUseProjectIconTabColors(false);
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(find.byKey(iconKey)).color, scheme.primary);
    await settings.setUseProjectIconTabColors(true);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(appFor(darkScheme));
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(find.byKey(iconKey)).color, darkScheme.primary);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              ValueKey<String>(
                'session_tab_title_${sessionTabIdentityKey(selected.identity)}',
              ),
            ),
          )
          .style
          ?.color,
      darkScheme.onSurface,
    );
    for (final preset in [
      OpenCodeThemePreset.catppuccinFrappe,
      OpenCodeThemePreset.catppuccinMacchiato,
    ]) {
      final darkSurfaceLightScheme = openCodeLightSchemeFor(preset)!;
      await tester.pumpWidget(appFor(darkSurfaceLightScheme));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Material>(find.byKey(tabKey)).color,
        isNot(darkSurfaceLightScheme.surface),
      );
      expect(tester.widget<Icon>(find.byKey(iconKey)).color, Colors.white);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                ValueKey<String>(
                  'session_tab_title_${sessionTabIdentityKey(selected.identity)}',
                ),
              ),
            )
            .style
            ?.color,
        Colors.white,
      );
    }
  });

  test(
    'tints preserve tab label contrast across light, dark and black surfaces',
    () {
      for (final brightness in Brightness.values) {
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        );
        for (final seed in [
          Colors.red,
          Colors.blue,
          Colors.green,
          Colors.yellow,
          Colors.black,
          Colors.white,
        ]) {
          for (final selected in [true, false]) {
            final base = selected
                ? scheme.surface
                : scheme.surfaceContainerHigh;
            final text = brightness == Brightness.light
                ? projectTabPaletteForeground(scheme, seed, selected: selected)
                : selected
                ? scheme.onSurface
                : scheme.onSurfaceVariant;
            final foregrounds = brightness == Brightness.light
                ? [text]
                : [text, scheme.primary];
            final overlays = [
              Colors.transparent,
              scheme.primary.withValues(alpha: .09),
              scheme.primary.withValues(alpha: .14),
            ];
            final fill = projectTabSurface(
              seed,
              base,
              foregrounds,
              selected: selected,
              overlays: overlays,
            );
            for (final overlay in overlays) {
              for (final foreground in foregrounds) {
                expect(
                  _contrast(Color.alphaBlend(overlay, fill), foreground),
                  greaterThanOrEqualTo(
                    math.min(
                      4.5,
                      _contrast(Color.alphaBlend(overlay, base), foreground),
                    ),
                  ),
                );
              }
            }
          }
        }
      }
    },
  );

  testWidgets(
    'disabling colors during stored load does not start hidden discovery',
    (tester) async {
      final settings = _settings();
      final store = PaletteStore(null)..read = Completer();
      final discovery = PaletteDiscovery();
      var extractions = 0;
      final icons = ProjectIconProvider(
        store: store,
        discoveryService: discovery,
        extractColor: (_) async {
          extractions++;
          return Colors.red;
        },
      );
      addTearDown(settings.dispose);
      addTearDown(icons.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<ProjectIconProvider>.value(value: icons),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SessionTabStrip(
                tabs: [_tab('pending', selected: true)],
                projects: [paletteProject()],
                openProjectIds: const {'palette'},
                isCompact: true,
                onActivate: (_) {},
                onClose: (_) {},
                onContextMenu: (_, _, {required haptic}) async {},
                trailingBuilder: (_, _) => null,
              ),
            ),
          ),
        ),
      );
      expect(store.reads, 1);
      await settings.setUseProjectIconTabColors(false);
      store.read!.complete(paletteIcon([1]));
      await tester.pumpAndSettle();
      expect(discovery.calls, 0);
      expect(extractions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Appearance exposes an immediately reactive project colors switch',
    (tester) async {
      final settings = _settings();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: localizedMaterialApp(
            home: const Scaffold(body: AppearanceSettingsSection()),
          ),
        ),
      );
      final toggle = find.byKey(
        const ValueKey('settings_toggle_project_tab_colors'),
      );
      await tester.ensureVisible(toggle);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings.useProjectIconTabColors, isFalse);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    },
  );
}
