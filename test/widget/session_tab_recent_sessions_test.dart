import 'dart:convert';

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/widgets/session_tab_strip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/chat_page_test_harness.dart';
import '../support/fakes.dart';

final _project = Project(
  id: 'a',
  name: 'Project A',
  path: '/project-a',
  createdAt: DateTime(2026),
);
final _otherProject = Project(
  id: 'b',
  name: 'Project B',
  path: '/project-b',
  createdAt: DateTime(2026),
);

ChatSession _session(
  String id, {
  String? directory,
  String? parentId,
  bool archived = false,
  int age = 0,
}) => ChatSession(
  id: id,
  workspaceId: 'default',
  title: 'Conversation $id',
  directory: directory ?? _project.path,
  parentId: parentId,
  archivedAt: archived ? DateTime.now() : null,
  time: DateTime.now().subtract(Duration(minutes: age)),
);

Future<({ChatProvider chat, SettingsProvider settings})> _pumpChat(
  WidgetTester tester,
  FakeChatRepository repository, {
  bool pane = false,
  double width = 1200,
  Project? currentProject,
  bool integratedChrome = false,
}) async {
  final project = currentProject ?? _project;
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final local = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
  disableAutomaticUpdateChecksForTest(local);
  await local.saveCurrentProjectId(project.id, serverId: 'srv_test');
  await local.saveOpenProjectIdsJson(
    jsonEncode([project.id, _otherProject.id]),
    serverId: 'srv_test',
  );
  final chat = buildChatPageProvider(
    localDataSource: local,
    chatRepository: repository,
    projectRepository: FakeProjectRepository(
      currentProject: project,
      projects: [project, _otherProject],
    ),
  );
  final app = buildChatPageAppProvider(localDataSource: local);
  final settings = SettingsProvider(
    localDataSource: local,
    dioClient: DioClient(),
    soundService: SoundService(),
  );
  await settings.initialize();
  await settings.setShowSessionTabsOverride(true);
  await settings.setDesktopWindowChrome(
    integratedChrome
        ? DesktopWindowChrome.integratedTabs
        : DesktopWindowChrome.systemDecoration,
  );
  await settings.setDesktopPaneVisible(DesktopPane.conversations, pane);
  await tester.pumpWidget(
    buildChatPageTestApp(
      chat,
      app,
      settingsProvider: settings,
      integratedWindowChrome: integratedChrome,
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    chat.dispose();
    chat.projectProvider.dispose();
    app.dispose();
    settings.dispose();
  });
  await tester.pumpAndSettle();
  await chat.loadSessions();
  await chat.selectSession(
    chat.sessions.firstWhere((session) => session.id == 'anchor'),
  );
  await tester.pumpAndSettle();
  return (chat: chat, settings: settings);
}

Future<void> _openMenu(
  WidgetTester tester,
  SessionTabRecord tab, {
  bool touch = false,
}) async {
  final target = find.byKey(
    ValueKey<String>(
      'session_tab_activate_${sessionTabIdentityKey(tab.identity)}',
    ),
  );
  if (touch) {
    await tester.longPress(target);
  } else {
    await tester.tap(
      target,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settleNavigation(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recent session activation supports root project-ID scopes', (
    tester,
  ) async {
    final root = Project(
      id: 'root',
      name: 'Root',
      path: '/',
      createdAt: DateTime(2026),
    );
    final fixture = await _pumpChat(
      tester,
      FakeChatRepository(
        sessions: [
          for (final id in ['anchor', 'other'])
            ChatSession(
              id: id,
              workspaceId: 'default',
              title: id,
              time: DateTime.now(),
            ),
        ],
      ),
      currentProject: root,
    );
    final anchor = fixture.chat.sessionTabs.singleWhere(
      (tab) => tab.isSelected,
    );
    expect(anchor.identity.directory, root.id);
    await _openMenu(tester, anchor);
    await tester.tap(
      find.byKey(const ValueKey<String>('session_tab_recent_other')),
    );
    await _settleNavigation(tester);
    expect(fixture.chat.currentSession?.id, 'other');
    expect(fixture.chat.projectProvider.currentProject?.id, root.id);
  });

  for (final action in ['switch', 'new', 'close-last']) {
    testWidgets(
      'integrated titlebar $action dismisses the project picker',
      (tester) async {
        final fixture = await _pumpChat(
          tester,
          FakeChatRepository(sessions: [_session('anchor'), _session('other')]),
          integratedChrome: true,
        );
        final anchor = fixture.chat.sessionTabs.singleWhere(
          (tab) => tab.isSelected,
        );
        if (action == 'close-last') {
          for (final tab in fixture.chat.sessionTabs.where(
            (tab) => tab.identity != anchor.identity,
          )) {
            fixture.chat.closeSessionTab(tab.identity);
          }
          await tester.pumpAndSettle();
        }
        await _openMenu(tester, anchor);
        await tester.tap(
          find.byKey(const ValueKey<String>('session_tab_menu_show_more')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('project_session_picker')),
          findsOneWidget,
        );
        final strip = tester.widget<SessionTabStrip>(
          find.byType(SessionTabStrip),
        );
        switch (action) {
          case 'switch':
            strip.onActivate(
              fixture.chat.sessionTabs.singleWhere(
                (tab) => tab.identity.sessionId == 'other',
              ),
            );
          case 'new':
            strip.onNewChatForProject!(anchor);
          case 'close-last':
            strip.onClose(anchor);
        }
        await _settleNavigation(tester);
        expect(
          find.byKey(const ValueKey<String>('project_session_picker')),
          findsNothing,
        );
        expect(
          fixture.chat.currentSession?.id,
          action == 'switch' ? 'other' : isNot('anchor'),
        );
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );
  }

  testWidgets(
    'session tab menu recent uses an inactive project snapshot for navigation',
    (tester) async {
      final repository = FakeChatRepository(
        sessions: [
          _session('anchor'),
          _session('other'),
          _session('foreign', directory: _otherProject.path),
        ],
      );
      final fixture = await _pumpChat(tester, repository);
      final anchor = fixture.chat.sessionTabs.singleWhere(
        (tab) => tab.isSelected,
      );
      await fixture.chat.projectProvider.switchProject(_otherProject.id);
      await fixture.chat.onProjectScopeChanged();
      await fixture.chat.selectSession(
        fixture.chat.sessions.singleWhere((session) => session.id == 'foreign'),
      );
      await tester.pumpAndSettle();
      final calls = repository.getSessionsCallCount;
      await _openMenu(tester, anchor);
      expect(repository.getSessionsCallCount, calls);
      expect(fixture.chat.currentSession?.id, 'foreign');
      expect(
        find.byKey(const ValueKey<String>('session_tab_recent_other')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('session_tab_recent_foreign')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('session_tab_recent_other')),
      );
      await _settleNavigation(tester);
      expect(fixture.chat.projectProvider.currentProject?.id, _project.id);
      expect(fixture.chat.currentSession?.id, 'other');
    },
  );

  testWidgets(
    'session tab menu recent alternatives are scoped, capped and cache-only',
    (tester) async {
      final repository = FakeChatRepository(
        sessions: [
          _session('anchor'),
          for (var i = 0; i < 7; i++) _session('other$i', age: i + 1),
          _session('foreign', directory: _otherProject.path),
          _session('child', parentId: 'anchor'),
          _session('archived', archived: true),
        ],
      );
      final fixture = await _pumpChat(tester, repository);
      final calls = repository.getSessionsCallCount;
      await _openMenu(
        tester,
        fixture.chat.sessionTabs.singleWhere((tab) => tab.isSelected),
      );
      expect(repository.getSessionsCallCount, calls);
      expect(fixture.chat.currentSession?.id, 'anchor');
      expect(
        find.byKey(const ValueKey<String>('session_tab_recent_anchor')),
        findsNothing,
      );
      for (var i = 0; i < 5; i++) {
        expect(
          find.byKey(ValueKey<String>('session_tab_recent_other$i')),
          findsOneWidget,
        );
      }
      for (final id in ['other5', 'foreign', 'child', 'archived']) {
        expect(
          find.byKey(ValueKey<String>('session_tab_recent_$id')),
          findsNothing,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey<String>('session_tab_recent_other0')),
      );
      await _settleNavigation(tester);
      expect(fixture.chat.currentSession?.id, 'other0');
      expect(
        find.byKey(const ValueKey<String>('session_tab_recent_header')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'session tab menu recent show more opens searchable full project selector',
    (tester) async {
      final repository = FakeChatRepository(
        sessions: [
          _session('anchor'),
          for (var i = 0; i < 7; i++) _session('other$i', age: i + 1),
          _session('foreign', directory: _otherProject.path),
        ],
      );
      final fixture = await _pumpChat(tester, repository);
      await _openMenu(
        tester,
        fixture.chat.sessionTabs.singleWhere((tab) => tab.isSelected),
      );
      final calls = repository.getSessionsCallCount;
      await tester.tap(
        find.byKey(const ValueKey<String>('session_tab_menu_show_more')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('project_session_picker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('session_tab_recent_header')),
        findsNothing,
      );
      expect(
        fixture.settings.isDesktopPaneVisible(DesktopPane.conversations),
        isFalse,
      );
      expect(fixture.chat.currentSession?.id, 'anchor');
      expect(repository.getSessionsCallCount, calls);
      await tester.enterText(
        find.byKey(const ValueKey<String>('project_session_picker_search')),
        'other6',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('project_session_picker_other6')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('project_session_picker_foreign')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('project_session_picker_other6')),
      );
      await _settleNavigation(tester);
      expect(fixture.chat.currentSession?.id, 'other6');
      expect(
        find.byKey(const ValueKey<String>('project_session_picker')),
        findsNothing,
      );
      expect(
        fixture.settings.isDesktopPaneVisible(DesktopPane.conversations),
        isFalse,
      );
    },
  );

  for (final width in [750.0, 1200.0]) {
    testWidgets(
      'session tab menu recent respects pane visibility at width $width',
      (tester) async {
        final fixture = await _pumpChat(
          tester,
          FakeChatRepository(sessions: [_session('anchor'), _session('other')]),
          pane: true,
          width: width,
        );
        await _openMenu(
          tester,
          fixture.chat.sessionTabs.singleWhere((tab) => tab.isSelected),
        );
        expect(
          find.byKey(const ValueKey<String>('session_tab_recent_header')),
          findsNothing,
        );
        await tester.tapAt(const Offset(10, 990));
        await tester.pumpAndSettle();
        await fixture.settings.setDesktopPaneVisible(
          DesktopPane.conversations,
          false,
        );
        await tester.pumpAndSettle();
        await _openMenu(
          tester,
          fixture.chat.sessionTabs.singleWhere((tab) => tab.isSelected),
        );
        expect(
          find.byKey(const ValueKey<String>('session_tab_recent_other')),
          findsOneWidget,
        );
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );
  }

  testWidgets('session tab menu recent compact touch opens fullscreen picker', (
    tester,
  ) async {
    final fixture = await _pumpChat(
      tester,
      FakeChatRepository(sessions: [_session('anchor'), _session('other')]),
      pane: true,
      width: 400,
    );
    await _openMenu(
      tester,
      fixture.chat.sessionTabs.singleWhere((tab) => tab.isSelected),
      touch: true,
    );
    expect(
      find.byKey(const ValueKey<String>('session_tab_recent_other')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('session_tab_menu_show_more')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Dialog>(
            find.byKey(const ValueKey<String>('project_session_picker')),
          )
          .insetPadding,
      EdgeInsets.zero,
    );
    expect(fixture.chat.currentSession?.id, 'anchor');
  });

  testWidgets(
    'session tab menu recent absent for current-only and rejects deleted target',
    (tester) async {
      final repository = FakeChatRepository(sessions: [_session('anchor')]);
      final fixture = await _pumpChat(tester, repository);
      await _openMenu(
        tester,
        fixture.chat.sessionTabs.singleWhere((tab) => tab.isSelected),
      );
      expect(
        find.byKey(const ValueKey<String>('session_tab_recent_header')),
        findsNothing,
      );
      await tester.tapAt(const Offset(10, 990));
      await tester.pumpAndSettle();
      repository.sessions.add(_session('other'));
      await fixture.chat.loadSessions();
      await tester.pumpAndSettle();
      await _openMenu(
        tester,
        fixture.chat.sessionTabs.singleWhere((tab) => tab.isSelected),
      );
      repository.sessions.removeWhere((session) => session.id == 'other');
      await fixture.chat.loadSessions();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('session_tab_recent_other')),
      );
      await _settleNavigation(tester);
      expect(fixture.chat.currentSession?.id, 'anchor');
      expect(tester.takeException(), isNull);
    },
  );
}
