import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/composer_input.dart';
import 'package:codewalk/features/sessions/session_message_info.dart';
import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
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
  String link = '/sessions',
}) {
  final metadata = V2MetadataStore(backend: FakeMetadataBackend());
  final payloads = PreferencesPayloadStore(metadata);
  final dependencies = createAppDependencies(
    initialLink: Uri.parse(link),
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
    String link = '/sessions',
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
      link: link,
    );
    dependencies.preferences.setDensity(density);
    if (locale != null) dependencies.preferences.setLocale(locale);

    await tester.pumpWidget(
      CodeWalkV2Bootstrap(
        dependencies: dependencies,
        dynamicColors: (builder) => builder(null, null),
      ),
    );
    // A session link opens its own page; only the list needs the drawer.
    if (link == '/sessions') await showSessionList(tester);
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
    expect(find.byIcon(Symbols.settings), findsOneWidget);
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

void composerGroup() {
  testWidgets('composer send is a 42 dp circle with a 24 dp v1 glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ComposerSendButton(tooltip: 'Send', onPressed: () {}),
          ),
        ),
      ),
    );
    // v1: chat_input_widget.dart:355 (42 dp), :1685 (elevation 1.5 when
    // sendable), :1728 (send_rounded 24).
    expect(tester.getSize(find.byType(IconButton)), const Size(42, 42));
    expect(tester.widget<Icon>(find.byIcon(Symbols.send_rounded)).size, 24);
    expect(tester.takeException(), isNull);
  });
}

/// Settles the tab strip and its reads with the fake clock.
Future<void> _settleTabs(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the sessions [ids] of project `/work/a` as tabs, ending on the last.
Future<void> _openTabs(
  WidgetTester tester,
  ParitySurface surface,
  List<String> ids,
) async {
  // The catalog source exists once the first frames of the page have run.
  await _settleTabs(tester);
  final source = surface.rig.sources.single;
  source.respond([
    for (final id in ids) source.row(id, title: id, directory: '/work/a'),
  ]);
  await _settleTabs(tester);
  for (final id in ids) {
    surface.dependencies.router.go('/s/profile_a/ses_$id');
    await _settleTabs(tester);
    final ref = source.row(id).info.ref;
    for (final (read, task) in source.reads.toList()) {
      if (read != ref || task.completion.isCompleted) continue;
      task.completion.complete(
        source.served.firstWhere((row) => row.info.ref == ref),
      );
      await _settleTabs(tester);
    }
    if (surface.directory.handles.every((handle) => handle.session != ref)) {
      surface.directory.grant(ref);
      await tester.pump();
    }
  }
}

Finder _tabOf(ParitySurface surface, String id) => find.byKey(
  ValueKey(
    'session-tab-${surface.rig.sources.single.row(id).info.ref.storageKey}',
  ),
);

Finder _closeOf(ParitySurface surface, String id) => find.byKey(
  ValueKey(
    'session-tab-close-${surface.rig.sources.single.row(id).info.ref.storageKey}',
  ),
);

/// Tabs group (#458 S7, decision 13 and owner decision B): the strip keeps the
/// v1 height (46.4 compact, 43.2 wide), each tab 38.4 dp, the shown tab leads
/// its project group, and only the shown tab has a close control.
void tabsGroup() {
  for (final entry in {
    'phone': parityPhoneSize,
    'desktop': parityDesktopSize,
  }.entries) {
    testWidgets('tab strip keeps the v1 heights and order on ${entry.key}', (
      tester,
    ) async {
      final surface = await ParitySurface.pump(
        tester,
        size: entry.value,
        link: '/s/profile_a/ses_one',
      );
      await _openTabs(tester, surface, ['one', 'two', 'three']);
      // The compact session drawer opens over the strip; close it to measure.
      tester.firstState<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
      await _settleTabs(tester);

      expect(find.byKey(const ValueKey('session-tabs')), findsOneWidget);
      final strip = find.byKey(const ValueKey('session-tabs'));
      expect(
        tester.getSize(strip).height,
        closeTo(entry.key == 'phone' ? 46.4 : 43.2, 0.01),
      );
      expect(tester.getSize(strip).width, closeTo(entry.value.width, 0.01));
      if (entry.key == 'desktop') {
        final sidebar = find.byKey(const ValueKey('workspace-sidebar'));
        expect(sidebar, findsOneWidget);
        expect(tester.getTopLeft(strip).dx, tester.getTopLeft(sidebar).dx);
        expect(tester.getBottomLeft(strip).dy, tester.getTopLeft(sidebar).dy);
      }
      for (final id in ['one', 'two', 'three']) {
        expect(tester.getSize(_tabOf(surface, id)).height, closeTo(38.4, 0.01));
      }
      // The shown tab, `three`, leads its project group.
      expect(
        tester.getTopLeft(_tabOf(surface, 'three')).dx,
        lessThan(tester.getTopLeft(_tabOf(surface, 'one')).dx),
      );
      expect(
        tester.getTopLeft(_tabOf(surface, 'three')).dx,
        lessThan(tester.getTopLeft(_tabOf(surface, 'two')).dx),
      );
      expect(_closeOf(surface, 'three'), findsOneWidget);
      for (final id in ['one', 'two']) {
        expect(_closeOf(surface, id), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

/// Menus group (#458 S6, v1 session_context_menu.dart): a tab menu opens
/// without selecting its tab, and the glyph and label of an item keep the v1
/// 8 dp gap.
void menusGroup() {
  testWidgets('a tab menu opens without selecting the tab; glyph gap is 8 dp', (
    tester,
  ) async {
    final surface = await ParitySurface.pump(
      tester,
      size: parityDesktopSize,
      link: '/s/profile_a/ses_one',
    );
    await _openTabs(tester, surface, ['one', 'two']);
    String location() => surface
        .dependencies
        .router
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();
    final before = location();

    await tester.longPress(_tabOf(surface, 'one'));
    await _settleTabs(tester);

    expect(location(), before);
    final glyph = find.byIcon(Symbols.push_pin).first;
    expect(glyph, findsOneWidget);
    final row = find.ancestor(of: glyph, matching: find.byType(Row)).first;
    final label = find.descendant(of: row, matching: find.byType(Text)).first;
    expect(
      tester.getRect(label).left - tester.getRect(glyph).right,
      closeTo(8, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('session row menu items use a 24 dp glyph and an 8 dp gap', (
    tester,
  ) async {
    final surface = await ParitySurface.pump(tester, size: parityDesktopSize);
    await _settleTabs(tester);
    final source = surface.rig.sources.single;
    source.respond([
      source.row('one', title: 'one', directory: '/work/a'),
      source.row('two', title: 'two', directory: '/work/a'),
    ]);
    await _settleTabs(tester);
    // v1: session_context_menu.dart:346-351 (PopupMenuItem with the default
    // 24 dp Icon, then SizedBox(width: 8) before the label).
    // The tab strip above the pane shows the same menus for open tabs, so the
    // search stays in the side pane where the session rows are.
    final row = find.descendant(
      of: find.byKey(const ValueKey('workspace-sidebar')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'session-actions-',
            ),
      ),
    );
    expect(row, findsWidgets);
    final menu = find.descendant(
      of: row.first,
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Symbols.push_pin), findsWidgets);

    final item = find.byWidgetPredicate((widget) => widget is PopupMenuItem);
    expect(item, findsWidgets);
    final glyph = find.descendant(of: item.first, matching: find.byType(Icon));
    final label = find.descendant(of: item.first, matching: find.byType(Text));
    expect(tester.getSize(glyph.first).width, closeTo(24, 0.5));
    expect(
      tester.getRect(label.first).left - tester.getRect(glyph.first).right,
      closeTo(8, 0.5),
    );
    expect(tester.takeException(), isNull);
  });
}

/// Message header of a standalone timeline tile, the same frame as the
/// timeline tests use.
Widget _timelineSurface(Widget child) => MaterialApp(
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

ItemMeta _timelineMeta(String id, {MessageContext? message}) => ItemMeta(
  id: ItemId('parity/$id'),
  generation: 'parity',
  status: OpenValue.unknown('parity'),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('parity')),
    version: '2.0.22',
    nativeType: 'assistant',
  ),
  message: message,
);

/// Timeline group (#458 S9, decision 16, v1 chat_message_content.dart): a user
/// header shows "You" and the clock time; an assistant header shows its clock
/// time and its elapsed chip; an assistant message with none has no header.
void timelineGroup() {
  final created = DateTime.utc(2026, 11, 2, 12, 5);
  final context = MessageContext(
    message: MessageRef('msg_a'),
    created: created,
    completed: created.add(const Duration(seconds: 3)),
    modelId: 'model-x',
    modelProviderId: 'provider-y',
    tokens: TokenBreakdown(input: 10, output: 5),
    finish: 'stop',
  );

  String clockOf(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold));
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(created.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  testWidgets('a user header shows You and the clock, with no elapsed chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timelineSurface(
        SessionTimelineTile(
          item: UserInput(
            meta: _timelineMeta('u', message: context),
            text: 'Hi',
            delivery: const OpenValue.known(DeliveryState.delivered),
          ),
          messageHeader: true,
        ),
      ),
    );
    expect(find.text('You'), findsOneWidget);
    expect(find.text(clockOf(tester)), findsOneWidget);
    expect(find.byType(MessageElapsedChip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an assistant header shows its clock and its elapsed chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _timelineSurface(
        SessionTimelineTile(
          item: AssistantText(
            meta: _timelineMeta('a', message: context),
            text: 'Body',
            complete: true,
          ),
          messageHeader: true,
        ),
      ),
    );
    expect(find.text(clockOf(tester)), findsOneWidget);
    expect(find.byType(MessageElapsedChip), findsOneWidget);
    expect(find.text('3s'), findsOneWidget);
    expect(find.text('You'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an assistant without time, duration or action has no header', (
    tester,
  ) async {
    // Without a header the body starts 14 dp below the card's top edge; an
    // empty header row and its 8 dp gap would move it down.
    await tester.pumpWidget(
      _timelineSurface(
        Column(
          children: [
            for (final header in [false, true])
              SessionTimelineTile(
                item: AssistantText(
                  meta: _timelineMeta(header ? 'bare' : 'plain'),
                  text: 'Body',
                  complete: true,
                ),
                messageHeader: header,
              ),
          ],
        ),
      ),
    );
    double bodyOffset(int card) =>
        tester
            .getTopLeft(
              find.descendant(
                of: find.byType(Card).at(card),
                matching: find.text('Body'),
              ),
            )
            .dy -
        tester.getTopLeft(find.byType(Card).at(card)).dy;
    expect(bodyOffset(0), closeTo(14, 0.5));
    expect(bodyOffset(1), closeTo(14, 0.5));
    expect(find.byType(MessageElapsedChip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void main() {
  toolbarGroup();
  sidePanelGroup();
  composerGroup();
  tabsGroup();
  menusGroup();
  timelineGroup();
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
    expect(items, findsNWidgets(4));
    expect(tester.getTopLeft(items.first).dy, greaterThanOrEqualTo(bottom));
    // v1: chat_page_mobile_overflow.dart:245-250 (18dp pins), :261 (dividers).
    final pin = tester.widget<IconButton>(
      find.byKey(const ValueKey('workspace-pin-newChat')),
    );
    expect(pin.iconSize, 18);
    expect(find.byType(Divider), findsNWidgets(3));
    // Decision 10 order: undo follows the pinned actions; disabled on home as in v1.
    expect(
      tester
          .widget<MenuItemButton>(find.byKey(const ValueKey('turn-menu-undo')))
          .onPressed,
      isNull,
    );
    expect(find.byIcon(Symbols.refresh), findsOneWidget);
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
