import 'dart:convert';
import 'dart:math' as math;

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/pages/settings/sections/appearance_settings_section.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_icon_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/project_icon_models.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
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

void main() {
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
          var scheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: mode == 'light' ? Brightness.light : Brightness.dark,
          );
          if (mode == 'amoled') {
            scheme = scheme.copyWith(
              surface: Colors.black,
              surfaceContainerHigh: Colors.black,
            );
          }
          final selected = _tab('active', selected: true);
          final inactive = _tab('inactive', pinned: true);
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

  test(
    'tints preserve text contrast across light, dark and black surfaces',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return (math.max(x, y) + .05) / (math.min(x, y) + .05);
      }

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
            final text = selected ? scheme.onSurface : scheme.onSurfaceVariant;
            final fill = projectTabSurface(seed, base, [
              text,
              scheme.primary,
            ], selected: selected);
            expect(contrast(fill, text), greaterThanOrEqualTo(4.5));
          }
        }
      }
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
