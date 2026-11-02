import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/theme/app_theme.dart'
    as v2theme
    show AppDensitySpacing;
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// The two surface sizes of the v1 parity contract (#458): compact phone and
/// wide desktop, both in `en` at text scale 1.0.
const parityPhoneSize = Size(412, 915);
const parityDesktopSize = Size(1280, 800);

/// The reference endpoint profile of the parity fixtures, on both sides.
Future<void> saveReferenceProfile(CatalogRig rig) => rig.repository.save(
  EndpointProfile(
    id: 'profile_a',
    label: 'Test Server',
    endpoint: Uri.parse('http://127.0.0.1:4096/proxy/'),
  ),
  'fake-a',
);

/// The v2 app wired with the parity fakes and the fixed reference clock.
AppDependencies buildReferenceDependencies({
  required CatalogRig rig,
  required LiveDirectory directory,
  required bool dark,
}) {
  final metadata = V2MetadataStore(backend: FakeMetadataBackend());
  final payloads = PreferencesPayloadStore(metadata);
  final dependencies = createAppDependencies(
    initialLink: Uri(path: '/sessions'),
    sessionClock: () => DateTime.utc(2026, 11, 2, 12),
    metadataStore: metadata,
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
    draftStore: SessionDraftStore(payloads: payloads, index: metadata),
    workspaceDraftStore: WorkspaceDraftStore(
      payloads: payloads,
      index: metadata,
    ),
  );
  addTearDown(dependencies.dispose);
  dependencies.preferences.setThemeMode(
    dark ? ThemeMode.dark : ThemeMode.light,
  );
  return dependencies;
}

/// A mounted v2 workspace with the same fakes as the parity suite.
class ParitySurface {
  ParitySurface._(this.dependencies, this.directory, this.rig);

  final AppDependencies dependencies;
  final LiveDirectory directory;
  final CatalogRig rig;

  /// Pumps the v2 workspace at [size] in the requested brightness and settles
  /// its first frames. Tests own [tester] and the teardown of the view size.
  static Future<ParitySurface> pump(
    WidgetTester tester, {
    required Size size,
    bool dark = false,
    AppDensity density = AppDensity.normal,
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rig = CatalogRig();
    await saveReferenceProfile(rig);
    final directory = LiveDirectory();
    final dependencies = buildReferenceDependencies(
      rig: rig,
      directory: directory,
      dark: dark,
    );
    dependencies.preferences.setDensity(density);
    if (locale != null) dependencies.preferences.setLocale(locale);

    await tester.pumpWidget(
      CodeWalkV2Bootstrap(
        dependencies: dependencies,
        dynamicColors: (builder) => builder(null, null),
      ),
    );
    await showSessionList(tester);
    return ParitySurface._(dependencies, directory, rig);
  }
}

void sidePanelGroup() {
  testWidgets('side panel server row uses the v1 cloud pill', (tester) async {
    await ParitySurface.pump(tester, size: parityPhoneSize);
    // v1: chat_page_status_presenter.dart:644 (cloud 16), :718 (arrow 18).
    final server = find.byKey(const ValueKey('sessions-profile'));
    expect(server, findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: server, matching: find.byIcon(Symbols.cloud)),
          )
          .size,
      16,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: server,
              matching: find.byIcon(Symbols.arrow_drop_down),
            ),
          )
          .size,
      18,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('side panel header uses the v1 Symbols glyphs', (tester) async {
    await ParitySurface.pump(tester, size: parityPhoneSize);
    // v1: chat_page_scaffold.dart:242 (search), :293 (add_comment), :272
    // (folder_open for the project picker), :602 (filter_list).
    expect(find.byIcon(Symbols.search), findsOneWidget);
    expect(find.byIcon(Symbols.filter_list), findsOneWidget);
    expect(find.byIcon(Symbols.folder_open), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sessions-create')),
        matching: find.byIcon(Symbols.add_comment),
      ),
      findsOneWidget,
    );
    expect(find.byType(IconButton), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

void main() {
  toolbarGroup();
  sidePanelGroup();
  // Each size shows its own session surface: the compact list drawer on a
  // phone, the persistent sidebar on desktop.
  final surfaces = {
    'phone': (size: parityPhoneSize, surface: 'workspace-drawer'),
    'desktop': (size: parityDesktopSize, surface: 'workspace-sidebar'),
  };
  for (final entry in surfaces.entries) {
    for (final dark in [false, true]) {
      testWidgets(
        'parity workspace mounts at ${entry.key} size, ${dark ? 'dark' : 'light'}',
        (tester) async {
          await ParitySurface.pump(tester, size: entry.value.size, dark: dark);

          expect(find.byType(CodeWalkV2Bootstrap), findsOneWidget);
          expect(find.byKey(ValueKey(entry.value.surface)), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

/// Toolbar group (#458 S5, decisions 8 to 10): one bar on the home screen at
/// both sizes, v1 height per density, leading width and title spacing.
void toolbarGroup() {
  const offsets = {
    AppDensity.extraDense: -4.0,
    AppDensity.dense: -2.0,
    AppDensity.normal: 0.0,
    AppDensity.spacious: 4.0,
    AppDensity.extraSpacious: 8.0,
  };
  for (final entry in {
    'phone': parityPhoneSize,
    'desktop': parityDesktopSize,
  }.entries) {
    final compact = entry.key == 'phone';
    for (final density in AppDensity.values) {
      testWidgets(
        'toolbar has one bar and v1 metrics on ${entry.key} at ${density.name}',
        (tester) async {
          await ParitySurface.pump(tester, size: entry.value, density: density);

          expect(find.byType(AppBar), findsOneWidget);
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          // v1: chat_page_chrome.dart:719 (menu), :1230 (new chat).
          final leading = find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(compact ? Symbols.menu : Symbols.menu_open),
          );
          expect(leading, findsOneWidget);
          // The drawer header shows the same new-chat glyph beside the list.
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byIcon(Symbols.add_comment),
            ),
            findsOneWidget,
          );
          expect(find.byIcon(Symbols.more_vert), findsOneWidget);

          // v1: lib/presentation/pages/chat_page/chat_page_chrome.dart:634.
          expect(
            bar.toolbarHeight,
            (compact ? 46.0 : 44.0) + offsets[density]!,
          );
          if (compact) {
            // v1: lib/presentation/pages/chat_page/chat_page_chrome.dart:700,872.
            expect(bar.leadingWidth, 42);
            expect(bar.titleSpacing, 0);
          } else {
            // v1: lib/presentation/pages/chat_page/chat_page_chrome.dart:874.
            expect(
              bar.titleSpacing,
              v2theme.AppDensitySpacing.appBarTitleSpacing(density),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('toolbar overflow uses the v1 menu below the bar', (
    tester,
  ) async {
    await ParitySurface.pump(tester, size: parityPhoneSize);
    tester.firstState<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
    await tester.pumpAndSettle();
    final bottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    await tester.tap(find.byKey(const ValueKey('workspace-actions')));
    await tester.pumpAndSettle();
    // v1: chat_page_mobile_overflow.dart:230-276 (MenuAnchor / MenuItemButton).
    final items = find.byType(MenuItemButton);
    expect(items, findsNWidgets(5));
    expect(tester.getTopLeft(items.first).dy, greaterThanOrEqualTo(bottom));
    // v1: chat_page_mobile_overflow.dart:245-250 (18dp pins), :261 (dividers).
    final pin = tester.widget<IconButton>(
      find.byKey(const ValueKey('workspace-pin-newChat')),
    );
    expect(pin.iconSize, 18);
    expect(find.byType(Divider), findsNWidgets(4));
    // Decision 10 order: undo follows the pinned actions; disabled on home as in v1.
    expect(
      tester
          .widget<MenuItemButton>(find.byKey(const ValueKey('turn-menu-undo')))
          .onPressed,
      isNull,
    );
    expect(find.byIcon(Symbols.refresh), findsOneWidget);
    expect(find.byIcon(Symbols.settings), findsOneWidget);
    expect(find.byIcon(Symbols.dns), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar keeps one bar in Arabic at text scale 2', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await ParitySurface.pump(
      tester,
      size: parityPhoneSize,
      locale: const Locale('ar'),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(AppBar))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
