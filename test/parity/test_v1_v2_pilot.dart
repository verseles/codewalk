import 'dart:io';
import 'dart:ui' as ui;

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/chat_page_test_harness.dart';
import '../support/fakes.dart';
import '../v2/hosts/fakes.dart';
import '../v2/sessions/composer_fakes.dart';
import '../v2/sessions/fakes.dart';
import '../v2/sessions/live_fakes.dart';
import '../v2/sessions/workspace_support.dart';

ItemMeta _v2Meta(String id, {String? message}) => ItemMeta(
  id: ItemId('p/$id'),
  generation: 'p',
  status: const OpenValue.known(ItemStatus.completed),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('p')),
    version: '2.0.22',
    nativeType: 'p',
  ),
  message: message == null ? null : MessageContext(message: MessageRef(message)),
);

Future<void> _capture(WidgetTester tester, GlobalKey key, String filename) async {
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final dir = Directory('/home/ubuntu/codewalk-cp5-evidence/run_20261030_cp5/captures');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('${dir.path}/$filename').writeAsBytesSync(byteData!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('render v1 chat S1 mobile', (tester) async {
    const size = Size(412, 915);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final source = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
    final chatSession = ChatSession(
      id: 'ses_s1',
      workspaceId: 'ws_test',
      title: 'Parity Test Session',
      time: DateTime(2026, 10, 30, 10, 0),
    );
    final chatRepo = FakeChatRepository(sessions: [chatSession]);
    chatRepo.messagesBySession['ses_s1'] = [
      UserMessage(
        id: 'm1',
        sessionId: 'ses_s1',
        time: DateTime(2026, 10, 30, 10, 0),
        parts: const [
          TextPart(id: 'p1', messageId: 'm1', sessionId: 'ses_s1', text: 'Fix the build'),
        ],
      ),
      AssistantMessage(
        id: 'm2',
        sessionId: 'ses_s1',
        time: DateTime(2026, 10, 30, 10, 0, 1),
        completedTime: DateTime(2026, 10, 30, 10, 0, 5),
        providerId: 'nvidia',
        modelId: 'minimax-m3.1-flash',
        parts: const [
          TextPart(
            id: 'p2',
            messageId: 'm2',
            sessionId: 'ses_s1',
            text: 'The build is fixed: the parser accepts empty input again.',
          ),
        ],
      ),
    ];

    final provider = buildChatPageProvider(localDataSource: source, chatRepository: chatRepo);
    final appProvider = buildChatPageAppProvider(localDataSource: source);
    addTearDown(() {
      provider.dispose();
      provider.projectProvider.dispose();
      appProvider.dispose();
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: buildChatPageTestApp(provider, appProvider),
      ),
    );
    await tester.pumpAndSettle();
    await provider.selectSession(chatSession);
    await tester.pumpAndSettle();

    await _capture(tester, key, 's1_mobile_light_v1.png');
  });

  testWidgets('render v2 chat S1 mobile', (tester) async {
    const size = Size(412, 915);
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

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CodeWalkV2Bootstrap(dependencies: dependencies),
      ),
    );
    await showSessionList(tester);
    final read = dependencies.sessions!.selectProfile('profile_a');
    final catalog = rig.sources.single;
    final row = catalog.row('one');
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
        state: liveState(
          ref,
          items: [
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
      ),
    );
    await tester.pumpAndSettle();

    await _capture(tester, key, 's1_mobile_light_v2.png');
  });
}
