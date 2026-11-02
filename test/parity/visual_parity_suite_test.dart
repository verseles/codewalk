import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/features/sessions/session_live_timeline.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/theme/app_theme.dart';
import 'package:codewalk/presentation/widgets/chat_input_widget.dart';
import 'package:codewalk/presentation/widgets/session_tab_strip.dart'
    as legacy_tabs;
import 'package:codewalk/shared/sessions/session_activity.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/chat_page_test_harness.dart';
import '../support/fakes.dart';
import '../v2/sessions/composer_fakes.dart';
import '../v2/sessions/fakes.dart';
import '../v2/sessions/live_fakes.dart';
import '../v2/sessions/v1_surface_parity_test.dart' as surface;
import '../v2/sessions/workspace_support.dart';
import 'capture_writer.dart';

ItemMeta _v2Meta(
  String id, {
  String? message,
  ItemStatus status = ItemStatus.completed,
}) => ItemMeta(
  id: ItemId('cp5/$id'),
  generation: 'cp5',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: const HarnessRef(
      HostId('profile_a'),
      HarnessInstanceId('profile_a'),
    ),
    version: '2.0.22',
    nativeType: 'cp5',
  ),
  message: message == null
      ? null
      : MessageContext(message: MessageRef(message)),
);

SessionSummary _referenceTime(SessionSummary row, int hour) => SessionSummary(
  info: row.info,
  execution: row.execution,
  updatedAt: DateTime.utc(2026, 10, 30, hour),
  createdAt: row.createdAt,
  outcome: row.outcome,
  view: row.view,
);

Future<void> _loadFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      (Directory('/home/ubuntu/flutter').existsSync()
          ? '/home/ubuntu/flutter'
          : null);
  if (flutterRoot == null) {
    throw StateError('Cannot locate Flutter SDK for font loading');
  }

  final robotoLoader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Light.ttf',
    'Roboto-Thin.ttf',
  ]) {
    final file = File('$flutterRoot/bin/cache/artifacts/material_fonts/$name');
    if (!file.existsSync()) {
      throw FileSystemException('Required Roboto font file missing', file.path);
    }
    robotoLoader.addFont(
      Future.value(ByteData.view(file.readAsBytesSync().buffer)),
    );
  }
  await robotoLoader.load();

  final iconLoader = FontLoader('MaterialIcons');
  final iconFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!iconFile.existsSync()) {
    throw FileSystemException(
      'Required MaterialIcons font file missing',
      iconFile.path,
    );
  }
  iconLoader.addFont(
    Future.value(ByteData.view(iconFile.readAsBytesSync().buffer)),
  );
  await iconLoader.load();

  // Load MaterialSymbolsOutlined and Rounded for packages/material_symbols_icons
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final candidates = Directory('$pubCache/hosted/pub.dev')
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('material_symbols_icons'))
      .toList();
  if (candidates.isEmpty) {
    throw StateError(
      'Cannot find material_symbols_icons in pub cache: $pubCache',
    );
  }
  final msiDir = candidates.last.path;

  final outlinedFile = File('$msiDir/lib/fonts/MaterialSymbolsOutlined.ttf');
  if (!outlinedFile.existsSync()) {
    throw FileSystemException(
      'Missing MaterialSymbolsOutlined.ttf',
      outlinedFile.path,
    );
  }
  final msiOutlined = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsOutlined',
  );
  msiOutlined.addFont(
    Future.value(ByteData.view(outlinedFile.readAsBytesSync().buffer)),
  );
  await msiOutlined.load();

  final roundedFile = File('$msiDir/lib/fonts/MaterialSymbolsRounded.ttf');
  if (!roundedFile.existsSync()) {
    throw FileSystemException(
      'Missing MaterialSymbolsRounded.ttf',
      roundedFile.path,
    );
  }
  final msiRounded = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  msiRounded.addFont(
    Future.value(ByteData.view(roundedFile.readAsBytesSync().buffer)),
  );
  await msiRounded.load();

  final monoFile = File(
    '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto_Mono/RobotoMono-Regular.ttf',
  );
  final sysMono = File('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf');
  final effectiveMono = monoFile.existsSync()
      ? monoFile
      : (sysMono.existsSync() ? sysMono : null);
  if (effectiveMono != null) {
    final monoLoader = FontLoader('monospace');
    monoLoader.addFont(
      Future.value(ByteData.view(effectiveMono.readAsBytesSync().buffer)),
    );
    await monoLoader.load();
  }
}

late Directory _captureDirectory;
var _removeCaptureDirectory = false;

/// The window toolbar: the widest app bar on screen. A desktop session has a
/// second bar in its chat column, which must not stand in for the toolbar.
Finder _fullWidthAppBar(WidgetTester tester) {
  Element? widest;
  var widestWidth = -1.0;
  for (final element in find.byType(AppBar).evaluate()) {
    final width = tester
        .getSize(find.byElementPredicate((candidate) => candidate == element))
        .width;
    if (width > widestWidth) {
      widest = element;
      widestWidth = width;
    }
  }
  return widest == null
      ? find.byType(AppBar)
      : find.byElementPredicate((candidate) => candidate == widest);
}

// Every region named here must match exactly one widget on the captured side;
// a missing or ambiguous region fails the capture instead of being resolved
// by its first match.
Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String filename, {
  required Map<String, Finder> regions,
}) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final bytes = byteData!.buffer.asUint8List();

  final output = File('${_captureDirectory.path}/$filename');
  writeParityCapture(output, bytes);

  final origin = tester.getTopLeft(find.byKey(key));
  final rects = <String, Map<String, double>>{};
  for (final entry in regions.entries) {
    final matches = entry.value.evaluate().length;
    if (matches != 1) {
      throw StateError(
        'Parity region ${entry.key} in $filename matches $matches widgets, expected 1',
      );
    }
    final rect = tester.getRect(entry.value).shift(-origin);
    rects[entry.key] = {
      'x': rect.left,
      'y': rect.top,
      'w': rect.width,
      'h': rect.height,
    };
  }
  File(
    '${_captureDirectory.path}/${filename.replaceFirst('.png', '.regions.json')}',
  ).writeAsStringSync(jsonEncode({'regions': rects}));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final requested = Platform.environment['CODEWALK_PARITY_CAPTURE_DIR'];
    if (requested != null && requested.isNotEmpty) {
      _captureDirectory = Directory(requested);
      if (_captureDirectory.existsSync() &&
          _captureDirectory.listSync().isNotEmpty) {
        throw StateError('Parity capture directory must be empty');
      }
      _captureDirectory.createSync(recursive: true);
    } else {
      final tempRoot = Directory('${Directory.systemTemp.path}/opencode');
      tempRoot.createSync(recursive: true);
      _captureDirectory = tempRoot.createTempSync('codewalk-parity-');
      _removeCaptureDirectory = true;
    }
    await _loadFonts();
  });

  tearDownAll(() {
    if (_removeCaptureDirectory) _captureDirectory.deleteSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // v1 time labels are "N d ago" within 30 days and absolute dates beyond it,
  // read from the real clock. Fixtures dated 2026-09-01 always render the
  // absolute form, so captures do not depend on the day they are taken.
  const mobileSize = Size(412, 915);
  const desktopSize = Size(1280, 800);

  // The short turn shared by s1 and s7 (s7 differs only in its toolbar title).
  final shortTurnV1Messages = <ChatMessage>[
    UserMessage(
      id: 'm1',
      sessionId: 'ses_1',
      time: DateTime(2026, 9, 1, 10, 0),
      parts: const [
        TextPart(
          id: 'p1',
          messageId: 'm1',
          sessionId: 'ses_1',
          text: 'Fix the build',
        ),
      ],
    ),
    AssistantMessage(
      id: 'm2',
      sessionId: 'ses_1',
      time: DateTime(2026, 9, 1, 10, 0, 1),
      completedTime: DateTime(2026, 9, 1, 10, 0, 5),
      providerId: 'nvidia',
      modelId: 'minimax-m3.1-flash',
      parts: const [
        TextPart(
          id: 'p2',
          messageId: 'm2',
          sessionId: 'ses_1',
          text: 'The build is fixed: the parser accepts empty input again.',
        ),
      ],
    ),
  ];
  final shortTurnV2Items = <TimelineItem>[
    UserInput(
      meta: _v2Meta('u1'),
      text: 'Fix the build',
      delivery: const OpenValue.known(DeliveryState.delivered),
    ),
    AssistantText(
      meta: _v2Meta('a1', message: 'm1'),
      text: 'The build is fixed: the parser accepts empty input again.',
      complete: true,
    ),
  ];
  final testCases = [
    // Scenario 1: Short turn, connected
    (
      id: 's1',
      title: 'Short turn completed',
      opensSession: true,
      composer: true,
      v1Messages: shortTurnV1Messages,
      v2Items: shortTurnV2Items,
    ),
    // Scenario 2: Rich timeline with code on both sides.
    (
      id: 's2',
      title: 'Rich timeline with code',
      opensSession: true,
      composer: true,
      v1Messages: [
        UserMessage(
          id: 'm1',
          sessionId: 'ses_2',
          time: DateTime(2026, 9, 1, 10, 0),
          parts: const [
            TextPart(
              id: 'p1',
              messageId: 'm1',
              sessionId: 'ses_2',
              text: 'Show me the parity check code',
            ),
          ],
        ),
        AssistantMessage(
          id: 'm2',
          sessionId: 'ses_2',
          time: DateTime(2026, 9, 1, 10, 0, 1),
          completedTime: DateTime(2026, 9, 1, 10, 0, 5),
          providerId: 'nvidia',
          modelId: 'minimax-m3.1-flash',
          parts: const [
            TextPart(
              id: 'p2',
              messageId: 'm2',
              sessionId: 'ses_2',
              text:
                  'Here is the implementation:\n\n```dart\nvoid checkParity() {\n  print("Parity OK");\n}\n```',
            ),
          ],
        ),
      ],
      v2Items: [
        UserInput(
          meta: _v2Meta('u1'),
          text: 'Show me the parity check code',
          delivery: const OpenValue.known(DeliveryState.delivered),
        ),
        AssistantText(
          meta: _v2Meta('a1', message: 'm1'),
          text:
              'Here is the implementation:\n\n```dart\nvoid checkParity() {\n  print("Parity OK");\n}\n```',
          complete: true,
        ),
      ],
    ),
    // Scenario 5: Empty chat
    (
      id: 's5',
      title: 'Empty session connected',
      opensSession: true,
      composer: true,
      v1Messages: <ChatMessage>[],
      v2Items: <TimelineItem>[],
    ),
    (
      id: 's9',
      title: 'Third session',
      opensSession: true,
      composer: true,
      v1Messages: <ChatMessage>[],
      v2Items: <TimelineItem>[],
    ),
    (
      id: 's10',
      title: 'Third session',
      opensSession: true,
      composer: true,
      v1Messages: <ChatMessage>[],
      v2Items: <TimelineItem>[],
    ),
    // Scenario 7: Toolbar with an open session (same turn as s1, toolbar title differs)
    (
      id: 's7',
      title: 'Toolbar with an open session',
      opensSession: true,
      composer: true,
      v1Messages: shortTurnV1Messages,
      v2Items: shortTurnV2Items,
    ),
    // Scenario 6: Toolbar on the home screen, no session open
    (
      id: 's6',
      title: 'Home screen',
      opensSession: false,
      composer: false,
      v1Messages: <ChatMessage>[],
      v2Items: <TimelineItem>[],
    ),
    (
      id: 's12',
      title: 'Home screen',
      opensSession: false,
      composer: false,
      v1Messages: <ChatMessage>[],
      v2Items: <TimelineItem>[],
    ),
    for (final state in ['empty', 'multiline', 'busy'])
      (
        id: 's13_$state',
        title: 'Composer session',
        opensSession: true,
        composer: true,
        v1Messages: <ChatMessage>[
          if (state == 'busy')
            UserMessage(
              id: 'busy_message',
              sessionId: 'ses_s13_busy',
              time: DateTime(2026, 9, 1, 10),
              parts: const [
                TextPart(
                  id: 'busy_part',
                  messageId: 'busy_message',
                  sessionId: 'ses_s13_busy',
                  text: 'Working on the build',
                ),
              ],
            ),
        ],
        v2Items: <TimelineItem>[
          if (state == 'busy')
            UserInput(
              meta: _v2Meta('busy'),
              text: 'Working on the build',
              delivery: const OpenValue.known(DeliveryState.delivered),
            ),
        ],
      ),
  ];

  for (final tc in testCases) {
    for (final (platform, size) in [
      ('mobile', mobileSize),
      ('desktop', desktopSize),
    ]) {
      if (tc.id == 's12' && platform == 'desktop') continue;
      for (final isDark in [false, true]) {
        final themeName = isDark ? 'dark' : 'light';

        testWidgets('v1 ${tc.id} $platform $themeName', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final source = InMemoryAppLocalDataSource()
            ..activeServerId = 'srv_test';
          final session = ChatSession(
            id: 'ses_${tc.id}',
            workspaceId: 'ws_test',
            title: tc.title,
            time: DateTime(2026, 9, 1, 10, 0),
            directory: '/work/a',
          );
          final extraSessions = (tc.id == 's9' || tc.id == 's10')
              ? [
                  ChatSession(
                    id: 'ses_first',
                    workspaceId: 'ws_test',
                    title: 'First session',
                    time: DateTime(2026, 9, 1, 10),
                    directory: '/work/a',
                  ),
                  ChatSession(
                    id: 'ses_second',
                    workspaceId: 'ws_test',
                    title: 'Second session',
                    time: DateTime(2026, 9, 1, 10),
                    directory: '/work/a',
                  ),
                ]
              : <ChatSession>[];
          final chatRepo = FakeChatRepository(
            sessions: tc.opensSession ? [...extraSessions, session] : [],
          );
          chatRepo.messagesBySession['ses_${tc.id}'] = tc.v1Messages;

          final provider = buildChatPageProvider(
            localDataSource: source,
            chatRepository: chatRepo,
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'project_a',
                name: 'a',
                path: '/work/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: [
                Project(
                  id: 'project_a',
                  name: 'a',
                  path: '/work/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
              ],
            ),
          );
          final appProvider = buildChatPageAppProvider(localDataSource: source);
          await appProvider.checkConnection();
          appProvider.setHealthForTesting(
            'srv_test',
            ServerHealthStatus.healthy,
          );
          addTearDown(() {
            provider.dispose();
            provider.projectProvider.dispose();
            appProvider.dispose();
          });

          // Decision 3: the v1 reference is always the refined style.
          final rawV1Theme = isDark
              ? AppTheme.darkFrom(
                  ColorScheme.fromSeed(
                    seedColor: AppTheme.seedColor,
                    brightness: Brightness.dark,
                  ),
                  visualStyle: VisualStyle.refined,
                )
              : AppTheme.lightFrom(
                  ColorScheme.fromSeed(
                    seedColor: AppTheme.seedColor,
                    brightness: Brightness.light,
                  ),
                  visualStyle: VisualStyle.refined,
                );
          final v1Theme = rawV1Theme.copyWith(
            textTheme: rawV1Theme.textTheme.apply(fontFamily: 'Roboto'),
          );

          final settings = await surface.v1ReferenceSettings(source);
          if (extraSessions.isNotEmpty) {
            await settings.setShowSessionTabsOverride(true);
          }
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: buildChatPageTestApp(
                provider,
                appProvider,
                integratedWindowChrome: platform == 'desktop',
                settingsProvider: settings,
                theme: v1Theme,
              ),
            ),
          );
          await tester.pumpAndSettle();
          appProvider.setHealthForTesting(
            'srv_test',
            ServerHealthStatus.healthy,
          );
          await tester.pump();
          for (final extra in extraSessions) {
            await provider.selectSession(extra);
            await tester.pumpAndSettle();
          }
          if (platform == 'desktop') {
            // Decision 3: the conversation pane keeps its 300 dp default.
            expect(
              tester
                  .getSize(
                    find.byKey(
                      const ValueKey<String>('desktop_pane_conversations'),
                    ),
                  )
                  .width,
              300,
            );
          }
          if (tc.opensSession) {
            await provider.selectSession(session);
            await tester.pumpAndSettle();
            expect(find.text(tc.title), findsWidgets);
          }
          if (tc.id == 's13_busy') {
            chatRepo.sessionStatusById[session.id] = const SessionStatusInfo(
              type: SessionStatusType.busy,
            );
            await provider.refreshSessionStatusSnapshot();
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<ChatInputWidget>(find.byType(ChatInputWidget))
                  .isResponding,
              isTrue,
            );
          }
          if (tc.id == 's13_multiline') {
            await tester.enterText(
              find
                  .descendant(
                    of: find.byType(ChatInputWidget),
                    matching: find.byType(TextField),
                  )
                  .first,
              'First line\nSecond line\nThird line',
            );
            await tester.pumpAndSettle();
          }
          if (extraSessions.isNotEmpty) {
            expect(provider.sessionTabs, hasLength(3));
            expect(
              provider.sessionTabs.where((tab) => tab.isSelected),
              hasLength(1),
            );
          }
          if (tc.id == 's10') {
            await tester.longPress(
              find
                  .descendant(
                    of: find.byType(legacy_tabs.SessionTabStrip),
                    matching: find.text(tc.title),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
          }
          if (tc.v1Messages.isNotEmpty) {
            final part = tc.v1Messages.first.parts.first;
            if (part is TextPart) {
              expect(find.text(part.text), findsWidgets);
            }
            if (tc.id == 's2') {
              expect(
                find.textContaining('Here is the implementation'),
                findsWidgets,
              );
              expect(
                find.textContaining('checkParity', findRichText: true),
                findsWidgets,
              );
            }
          }

          if (tc.id == 's12') {
            await tester.tap(
              find.byKey(const ValueKey('mobile_appbar_overflow_button')),
            );
            await tester.pumpAndSettle();
          }
          await _capture(
            tester,
            key,
            '${tc.id}_${platform}_${themeName}_v1.png',
            regions: {
              'toolbar': _fullWidthAppBar(tester),
              if (tc.v1Messages.isNotEmpty)
                'timeline': find.byType(CustomScrollView),
              if (tc.composer) 'composer': find.byType(ChatInputWidget),
              if (extraSessions.isNotEmpty)
                'tabs': find.byType(legacy_tabs.SessionTabStrip),
              if (tc.id == 's10')
                'overlay': find
                    .ancestor(
                      of: find
                          .byWidgetPredicate(
                            (widget) => widget is PopupMenuEntry,
                          )
                          .first,
                      matching: find.byType(Material),
                    )
                    .first,
              if (tc.id == 's12')
                'overlay': find
                    .ancestor(
                      of: find.byType(MenuItemButton).first,
                      matching: find.byType(Material),
                    )
                    .first,
              if (platform == 'desktop')
                'side_panel': find.byKey(
                  const ValueKey('desktop_pane_conversations'),
                ),
            },
          );
        });

        testWidgets('v2 ${tc.id} $platform $themeName', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final rig = CatalogRig();
          await surface.saveReferenceProfile(rig);
          final directory = LiveDirectory();
          final dependencies = surface.buildReferenceDependencies(
            rig: rig,
            directory: directory,
            dark: isDark,
          );

          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: CodeWalkV2Bootstrap(
                dependencies: dependencies,
                dynamicColors: (builder) => builder(null, null),
              ),
            ),
          );
          await showSessionList(tester);
          final read = dependencies.sessions!.selectProfile('profile_a');
          final catalog = rig.sources.last;
          final row = _referenceTime(
            catalog.row('one', title: tc.title, directory: '/work/a'),
            10,
          );
          final extraRows = (tc.id == 's9' || tc.id == 's10')
              ? [
                  _referenceTime(
                    catalog.row(
                      'first',
                      title: 'First session',
                      directory: '/work/a',
                    ),
                    10,
                  ),
                  _referenceTime(
                    catalog.row(
                      'second',
                      title: 'Second session',
                      directory: '/work/a',
                    ),
                    10,
                  ),
                ]
              : <SessionSummary>[];
          catalog.respond(tc.opensSession ? [...extraRows, row] : []);
          await read;
          await tester.pumpAndSettle();
          if (!dependencies.projectContexts!.open.contains('/work/a')) {
            expect(
              await dependencies.projectContexts!.openContext('/work/a'),
              isTrue,
            );
            await tester.pumpAndSettle();
          }

          // Extra tabs open before the active row, so the tab order matches v1
          // (the active session is the last tab in both).
          for (final extra in extraRows) {
            await dependencies.sessionTabs!.open(extra);
            await tester.pumpAndSettle();
          }
          if (tc.opensSession) {
            if (platform == 'mobile') {
              final drawer = find.byKey(const ValueKey('workspace-drawer'));
              tester
                  .state<ScaffoldState>(
                    find
                        .ancestor(of: drawer, matching: find.byType(Scaffold))
                        .last,
                  )
                  .closeDrawer();
              await tester.pumpAndSettle();
              dependencies.router.go(
                Uri(
                  pathSegments: ['', 's', 'profile_a', row.info.ref.nativeId],
                ).toString(),
              );
            } else {
              final button = find.byKey(
                ValueKey('live-open-${row.info.ref.storageKey}'),
              );
              await tester.ensureVisible(button);
              await tester.tap(button);
            }
            await tester.pump();
            await tester.pump();

            final ref = row.info.ref;
            final handle = directory.grant(ref, outbox: FakeOutbox())
              ..selectionAvailable = true
              ..stopAvailable = tc.id == 's13_busy'
              ..selectionState = const SessionSelectionState(
                selection: Selection(modelId: 'model_1', agentId: 'Build'),
              );
            await tester.pump();

            handle.emit(
              SessionLiveView(
                session: ref,
                phase: SessionLivePhase.live,
                state: liveState(
                  ref,
                  items: tc.v2Items,
                  execution: tc.id == 's13_busy'
                      ? const ExecutionState(
                          kind: OpenValue.known(ExecutionKind.running),
                        )
                      : null,
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (tc.id == 's13_busy') {
              expect(find.byKey(const ValueKey('live-stop')), findsOneWidget);
            }
            if (tc.id == 's13_multiline') {
              await tester.enterText(
                find.byKey(const ValueKey('live-composer-input')),
                'First line\nSecond line\nThird line',
              );
              await tester.pumpAndSettle();
            }
          }

          if (extraRows.isNotEmpty) {
            await dependencies.sessionTabs!.open(row);
            await tester.pumpAndSettle();
            expect(dependencies.sessionTabs!.tabs, hasLength(3));
            expect(
              dependencies.sessionTabs!.selectedFor(row.info.ref.host),
              row.info.ref,
            );
            for (final extra in extraRows) {
              expect(
                find.byKey(
                  ValueKey('session-tab-${extra.info.ref.storageKey}'),
                ),
                findsOneWidget,
              );
            }
          }
          if (tc.id == 's10') {
            await tester.longPress(
              find.byKey(ValueKey('session-tab-${row.info.ref.storageKey}')),
            );
            await tester.pumpAndSettle();
          }

          if (tc.id == 's1') {
            expect(find.text('Fix the build'), findsWidgets);
          } else if (tc.id == 's2') {
            expect(find.text('Show me the parity check code'), findsWidgets);
            expect(
              find.textContaining('Here is the implementation'),
              findsWidgets,
            );
            expect(
              find.textContaining('checkParity', findRichText: true),
              findsWidgets,
            );
          }

          if ((tc.id == 's6' || tc.id == 's12') && platform == 'mobile') {
            final drawer = find.byKey(const ValueKey('workspace-drawer'));
            tester
                .state<ScaffoldState>(
                  find
                      .ancestor(of: drawer, matching: find.byType(Scaffold))
                      .last,
                )
                .closeDrawer();
            await tester.pumpAndSettle();
          }
          if (tc.id == 's12') {
            await tester.tap(find.byKey(const ValueKey('workspace-actions')));
            await tester.pumpAndSettle();
          }
          await _capture(
            tester,
            key,
            '${tc.id}_${platform}_${themeName}_v2.png',
            regions: {
              'toolbar': _fullWidthAppBar(tester),
              if (tc.v2Items.isNotEmpty)
                'timeline': find.byType(SessionLiveTimeline),
              if (tc.composer)
                'composer': find.byKey(const ValueKey('live-composer')),
              if (extraRows.isNotEmpty)
                'tabs': find.byKey(const ValueKey('session-tabs')),
              if (tc.id == 's10')
                'overlay': find
                    .ancestor(
                      of: find
                          .byWidgetPredicate(
                            (widget) => widget is PopupMenuEntry,
                          )
                          .first,
                      matching: find.byType(Material),
                    )
                    .first,
              if (tc.id == 's12')
                'overlay': find
                    .ancestor(
                      of: find
                          .byWidgetPredicate(
                            (widget) => widget is PopupMenuEntry,
                          )
                          .first,
                      matching: find.byType(Material),
                    )
                    .first,
              if (platform == 'desktop')
                'side_panel': find.byKey(const ValueKey('workspace-sidebar')),
            },
          );
        });
      }
    }
  }

  // Scenario 8: drawer open on a phone, pane visible on desktop, two projects
  // and three sessions. Running and unread marks exist only on v2; the v1 side
  // has no public fixture for them (owner decision B, #458).
  for (final (platform, size) in [
    ('mobile', mobileSize),
    ('desktop', desktopSize),
  ]) {
    for (final isDark in [false, true]) {
      final themeName = isDark ? 'dark' : 'light';
      for (final scenario in ['s8', 's11_session', 's11_project']) {
        testWidgets('v1 $scenario $platform $themeName', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final source = InMemoryAppLocalDataSource()
            ..activeServerId = 'srv_test';
          final chatRepo = FakeChatRepository(
            sessions: [
              ChatSession(
                id: 'ses_a1',
                workspaceId: 'ws_test',
                title: 'Running build',
                time: DateTime(2026, 9, 1, 10, 0),
                directory: '/work/a',
              ),
              ChatSession(
                id: 'ses_a2',
                workspaceId: 'ws_test',
                title: 'Unread review',
                time: DateTime(2026, 9, 1, 9, 0),
                directory: '/work/a',
              ),
              ChatSession(
                id: 'ses_b1',
                workspaceId: 'ws_test',
                title: 'Parser notes',
                time: DateTime(2026, 9, 1, 8, 0),
                directory: '/work/b',
              ),
            ],
          );
          // Two projects; /work/a is current, so its sessions are listed and
          // /work/b appears only as a project (owner decision A, #458).
          final projectA = Project(
            id: 'project_a',
            name: 'a',
            path: '/work/a',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          );
          final projectB = Project(
            id: 'project_b',
            name: 'b',
            path: '/work/b',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          );
          final provider = buildChatPageProvider(
            localDataSource: source,
            chatRepository: chatRepo,
            projectRepository: FakeProjectRepository(
              currentProject: projectA,
              projects: [projectA, projectB],
            ),
          );
          final appProvider = buildChatPageAppProvider(localDataSource: source);
          await appProvider.checkConnection();
          appProvider.setHealthForTesting(
            'srv_test',
            ServerHealthStatus.healthy,
          );
          addTearDown(() {
            provider.dispose();
            provider.projectProvider.dispose();
            appProvider.dispose();
          });

          // Decision 3: the v1 reference is always the refined style.
          final rawV1Theme = isDark
              ? AppTheme.darkFrom(
                  ColorScheme.fromSeed(
                    seedColor: AppTheme.seedColor,
                    brightness: Brightness.dark,
                  ),
                  visualStyle: VisualStyle.refined,
                )
              : AppTheme.lightFrom(
                  ColorScheme.fromSeed(
                    seedColor: AppTheme.seedColor,
                    brightness: Brightness.light,
                  ),
                  visualStyle: VisualStyle.refined,
                );
          final v1Theme = rawV1Theme.copyWith(
            textTheme: rawV1Theme.textTheme.apply(fontFamily: 'Roboto'),
          );

          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: buildChatPageTestApp(
                provider,
                appProvider,
                integratedWindowChrome: platform == 'desktop',
                settingsProvider: await surface.v1ReferenceSettings(source),
                theme: v1Theme,
              ),
            ),
          );
          await tester.pumpAndSettle();
          appProvider.setHealthForTesting(
            'srv_test',
            ServerHealthStatus.healthy,
          );
          await tester.pump();
          expect(
            await provider.projectProvider.reopenProject(
              'project_b',
              makeActive: false,
            ),
            isTrue,
          );
          await tester.pumpAndSettle();
          expect(provider.projectProvider.currentProject?.id, 'project_a');
          expect(
            provider.projectProvider.openProjectIds,
            contains('project_b'),
          );
          if (platform == 'mobile') {
            tester
                .state<ScaffoldState>(find.byType(Scaffold).first)
                .openDrawer();
            await tester.pumpAndSettle();
          }
          expect(find.text('a'), findsWidgets);
          expect(find.text('b'), findsOneWidget);
          if (scenario != 's8') {
            final target = scenario == 's11_session'
                ? find.byKey(const ValueKey('chat_session_tile_ses_a1'))
                : find.byKey(const ValueKey('project_group_tile_project_a'));
            await tester.longPress(target);
            await tester.pumpAndSettle();
          }

          await _capture(
            tester,
            key,
            '${scenario}_${platform}_${themeName}_v1.png',
            regions: {
              'toolbar': _fullWidthAppBar(tester),
              'side_panel': platform == 'mobile'
                  ? find.byType(Drawer)
                  : find.byKey(const ValueKey('desktop_pane_conversations')),
              if (scenario != 's8')
                'overlay': find
                    .ancestor(
                      of: find
                          .byWidgetPredicate(
                            (widget) => widget is PopupMenuEntry,
                          )
                          .first,
                      matching: find.byType(Material),
                    )
                    .first,
            },
          );
        });

        testWidgets('v2 $scenario $platform $themeName', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final rig = CatalogRig();
          await surface.saveReferenceProfile(rig);
          final directory = LiveDirectory();
          final dependencies = surface.buildReferenceDependencies(
            rig: rig,
            directory: directory,
            dark: isDark,
          );

          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: CodeWalkV2Bootstrap(
                dependencies: dependencies,
                dynamicColors: (builder) => builder(null, null),
              ),
            ),
          );
          await showSessionList(tester);
          final read = dependencies.sessions!.selectProfile('profile_a');
          final catalog = rig.sources.last;
          final unread = _referenceTime(
            catalog.row(
              'one',
              title: 'Unread review',
              directory: '/work/a',
              view: SessionViewMarker(idleAt: DateTime.utc(2026, 11, 2, 12)),
            ),
            9,
          );
          final running = _referenceTime(
            catalog.row('two', title: 'Running build', directory: '/work/a'),
            10,
          );
          final parser = _referenceTime(
            catalog.row('three', title: 'Parser notes', directory: '/work/b'),
            8,
          );
          catalog.activityAnswer = SessionActivity(running: {running.info.ref});
          catalog.respond([unread, running, parser]);
          await read;
          await tester.pumpAndSettle();
          expect(
            await dependencies.projectContexts!.openContext('/work/b'),
            isTrue,
          );
          expect(
            await dependencies.projectContexts!.activate('/work/a'),
            isTrue,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('project-context-/work/b')),
            findsOneWidget,
          );
          if (scenario != 's8') {
            final target = scenario == 's11_session'
                ? find.byKey(
                    ValueKey('live-open-${running.info.ref.storageKey}'),
                  )
                : find.byKey(const ValueKey('project-context-/work/a'));
            await tester.longPress(target);
            await tester.pumpAndSettle();
          }

          await _capture(
            tester,
            key,
            '${scenario}_${platform}_${themeName}_v2.png',
            regions: {
              'toolbar': _fullWidthAppBar(tester),
              'side_panel': platform == 'mobile'
                  ? find.byType(Drawer)
                  : find.byKey(const ValueKey('workspace-sidebar')),
              if (scenario != 's8')
                'overlay': find
                    .ancestor(
                      of: find
                          .byWidgetPredicate(
                            (widget) => widget is PopupMenuEntry,
                          )
                          .first,
                      matching: find.byType(Material),
                    )
                    .first,
            },
          );
        });
      }
    }
  }
}
