import 'dart:io';
import 'dart:ui' as ui;

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/theme/app_theme.dart';
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
import '../v2/hosts/fakes.dart';
import '../v2/sessions/composer_fakes.dart';
import '../v2/sessions/fakes.dart';
import '../v2/sessions/live_fakes.dart';
import '../v2/sessions/workspace_support.dart';

ItemMeta _v2Meta(String id, {String? message, ItemStatus status = ItemStatus.completed}) => ItemMeta(
  id: ItemId('cp5/$id'),
  generation: 'cp5',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('profile_a'), HarnessInstanceId('profile_a')),
    version: '2.0.22',
    nativeType: 'cp5',
  ),
  message: message == null ? null : MessageContext(message: MessageRef(message)),
);

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      (Directory('/home/ubuntu/flutter').existsSync() ? '/home/ubuntu/flutter' : null);
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
    robotoLoader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }
  await robotoLoader.load();

  final iconLoader = FontLoader('MaterialIcons');
  final iconFile = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!iconFile.existsSync()) {
    throw FileSystemException('Required MaterialIcons font file missing', iconFile.path);
  }
  iconLoader.addFont(Future.value(ByteData.view(iconFile.readAsBytesSync().buffer)));
  await iconLoader.load();

  // Load MaterialSymbolsOutlined and Rounded for packages/material_symbols_icons
  final pubCache = Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache';
  final candidates = Directory('$pubCache/hosted/pub.dev')
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('material_symbols_icons'))
      .toList();
  if (candidates.isEmpty) {
    throw StateError('Cannot find material_symbols_icons in pub cache: $pubCache');
  }
  final msiDir = candidates.last.path;

  final outlinedFile = File('$msiDir/lib/fonts/MaterialSymbolsOutlined.ttf');
  if (!outlinedFile.existsSync()) {
    throw FileSystemException('Missing MaterialSymbolsOutlined.ttf', outlinedFile.path);
  }
  final msiOutlined = FontLoader('packages/material_symbols_icons/MaterialSymbolsOutlined');
  msiOutlined.addFont(Future.value(ByteData.view(outlinedFile.readAsBytesSync().buffer)));
  await msiOutlined.load();

  final roundedFile = File('$msiDir/lib/fonts/MaterialSymbolsRounded.ttf');
  if (!roundedFile.existsSync()) {
    throw FileSystemException('Missing MaterialSymbolsRounded.ttf', roundedFile.path);
  }
  final msiRounded = FontLoader('packages/material_symbols_icons/MaterialSymbolsRounded');
  msiRounded.addFont(Future.value(ByteData.view(roundedFile.readAsBytesSync().buffer)));
  await msiRounded.load();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String filename) async {
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final bytes = byteData!.buffer.asUint8List();

  final repoDir = Directory('evidence/cp5/captures');
  if (!repoDir.existsSync()) repoDir.createSync(recursive: true);
  File('${repoDir.path}/$filename').writeAsBytesSync(bytes);

  final runDir = Directory('/home/ubuntu/codewalk-cp5-evidence/run_20261030_cp5/captures');
  if (runDir.existsSync()) {
    File('${runDir.path}/$filename').writeAsBytesSync(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const mobileSize = Size(412, 915);
  const desktopSize = Size(1280, 800);

  final testCases = [
    // Scenario 1: Short turn, connected
    (
      id: 's1',
      title: 'Short turn completed',
      v1Messages: [
        UserMessage(
          id: 'm1',
          sessionId: 'ses_1',
          time: DateTime(2026, 10, 30, 10, 0),
          parts: const [TextPart(id: 'p1', messageId: 'm1', sessionId: 'ses_1', text: 'Fix the build')],
        ),
        AssistantMessage(
          id: 'm2',
          sessionId: 'ses_1',
          time: DateTime(2026, 10, 30, 10, 0, 1),
          completedTime: DateTime(2026, 10, 30, 10, 0, 5),
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
      ],
      v2Items: [
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
      ],
    ),
    // Scenario 2: Rich timeline (reasoning + code)
    (
      id: 's2',
      title: 'Rich timeline with code and reasoning',
      v1Messages: [
        UserMessage(
          id: 'm1',
          sessionId: 'ses_2',
          time: DateTime(2026, 10, 30, 10, 0),
          parts: const [TextPart(id: 'p1', messageId: 'm1', sessionId: 'ses_2', text: 'Show me the parity check code')],
        ),
        AssistantMessage(
          id: 'm2',
          sessionId: 'ses_2',
          time: DateTime(2026, 10, 30, 10, 0, 1),
          completedTime: DateTime(2026, 10, 30, 10, 0, 5),
          providerId: 'nvidia',
          modelId: 'minimax-m3.1-flash',
          parts: const [
            TextPart(
              id: 'p2',
              messageId: 'm2',
              sessionId: 'ses_2',
              text: 'Here is the implementation:\n\n```dart\nvoid checkParity() {\n  print("Parity OK");\n}\n```',
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
        Reasoning(
          meta: _v2Meta('r1', message: 'm1'),
          text: 'Preparing sample code for parity check.',
          complete: true,
        ),
        AssistantText(
          meta: _v2Meta('a1', message: 'm1'),
          text: 'Here is the implementation:\n\n```dart\nvoid checkParity() {\n  print("Parity OK");\n}\n```',
          complete: true,
        ),
      ],
    ),
    // Scenario 5: Empty chat
    (
      id: 's5',
      title: 'Empty session connected',
      v1Messages: <ChatMessage>[],
      v2Items: <TimelineItem>[],
    ),
  ];

  for (final tc in testCases) {
    for (final (platform, size) in [('mobile', mobileSize), ('desktop', desktopSize)]) {
      for (final isDark in [false, true]) {
        final themeName = isDark ? 'dark' : 'light';

        testWidgets('v1 ${tc.id} $platform $themeName', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final source = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
          final session = ChatSession(
            id: 'ses_${tc.id}',
            workspaceId: 'ws_test',
            title: tc.title,
            time: DateTime(2026, 10, 30, 10, 0),
          );
          final chatRepo = FakeChatRepository(sessions: [session]);
          chatRepo.messagesBySession['ses_${tc.id}'] = tc.v1Messages;

          final provider = buildChatPageProvider(localDataSource: source, chatRepository: chatRepo);
          final appProvider = buildChatPageAppProvider(localDataSource: source);
          addTearDown(() {
            provider.dispose();
            provider.projectProvider.dispose();
            appProvider.dispose();
          });

          final rawV1Theme = isDark
              ? AppTheme.darkFrom(
                  ColorScheme.fromSeed(
                    seedColor: AppTheme.seedColor,
                    brightness: Brightness.dark,
                  ),
                )
              : AppTheme.lightFrom(
                  ColorScheme.fromSeed(
                    seedColor: AppTheme.seedColor,
                    brightness: Brightness.light,
                  ),
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
                theme: v1Theme,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await provider.selectSession(session);
          await tester.pumpAndSettle();

          expect(find.text(tc.title), findsWidgets);
          if (tc.v1Messages.isNotEmpty) {
            final part = tc.v1Messages.first.parts.first;
            if (part is TextPart) {
              expect(find.text(part.text), findsWidgets);
            }
          }

          await _capture(tester, key, '${tc.id}_${platform}_${themeName}_v1.png');
        });

        testWidgets('v2 ${tc.id} $platform $themeName', (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final rig = CatalogRig();
          await rig.save('a');
          final directory = LiveDirectory();
          final dependencies = createAppDependencies(
            initialLink: Uri(path: '/sessions'),
            profileRepository: rig.repository,
            endpointProber: FakeProber(),
            sessionCatalogFactory: rig.create,
            sessionLiveDirectory: () => directory,
          );
          addTearDown(dependencies.dispose);
          dependencies.preferences.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);

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
          final row = catalog.row('one', title: tc.title);
          catalog.respond([row]);
          await read;
          await tester.pumpAndSettle();

          final button = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          await tester.pump();

          final ref = row.info.ref;
          final handle = directory.grant(ref, outbox: FakeOutbox())
            ..selectionAvailable = true
            ..selectionState = const SessionSelectionState(
              selection: Selection(modelId: 'minimax-m3.1-flash', agentId: 'build'),
            );
          await tester.pump();

          handle.emit(
            SessionLiveView(
              session: ref,
              phase: SessionLivePhase.live,
              state: liveState(ref, items: tc.v2Items),
            ),
          );
          await tester.pumpAndSettle();

          if (tc.id == 's1') {
            expect(find.text('Fix the build'), findsWidgets);
          } else if (tc.id == 's2') {
            expect(find.text('Show me the parity check code'), findsWidgets);
          }

          await _capture(tester, key, '${tc.id}_${platform}_${themeName}_v2.png');
        });
      }
    }
  }
}
