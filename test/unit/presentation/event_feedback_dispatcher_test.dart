import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/event_feedback_dispatcher.dart';
import 'package:codewalk/presentation/services/notification_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService();

  String? lastTitle;
  String? lastBody;
  String? lastCategory;
  String? lastSessionId;
  String? lastServerId;
  String? lastDirectory;
  String? lastSessionTitle;
  bool? lastPlaySound;
  SoundOption? lastSoundOption;
  String? lastSoundSource;
  String? clearedSessionId;
  int notifyCalls = 0;

  @override
  Future<bool> notify({
    required String title,
    required String body,
    required String category,
    String? sessionId,
    String? serverId,
    String? directory,
    String? sessionTitle,
    bool playSound = true,
    SoundOption soundOption = SoundOption.systemDefault,
    String? soundSource,
  }) async {
    notifyCalls += 1;
    lastTitle = title;
    lastBody = body;
    lastCategory = category;
    lastSessionId = sessionId;
    lastServerId = serverId;
    lastDirectory = directory;
    lastSessionTitle = sessionTitle;
    lastPlaySound = playSound;
    lastSoundOption = soundOption;
    lastSoundSource = soundSource;
    return true;
  }

  @override
  Future<void> clearNotificationsForSession(String sessionId) async {
    clearedSessionId = sessionId;
  }
}

class _FakeSoundService extends SoundService {
  int calls = 0;

  @override
  Future<bool> play({required SoundOption option, String? source}) async {
    calls += 1;
    return true;
  }
}

void main() {
  test('formats finished notification title with session hint', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_1'},
      ),
      sessionTitleHint: 'Refactor login flow',
    );

    expect(notificationService.lastCategory, 'agent');
    expect(notificationService.lastSessionId, 'ses_1');
    expect(notificationService.lastTitle, 'Refactor login flow');
  });

  test('propagates directory metadata to notification payload', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();

    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{
          'sessionID': 'ses_dir',
          'directory': '/tmp/workspace-a',
        },
      ),
      isAppInForeground: false,
    );

    expect(notificationService.lastSessionId, 'ses_dir');
    expect(notificationService.lastDirectory, '/tmp/workspace-a');
  });

  test('suppresses child-session completion notifications', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();

    final notificationService = _FakeNotificationService();
    final soundService = _FakeSoundService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: soundService,
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_child'},
      ),
      sessionTitleHint: 'Child Session',
      isRootSession: false,
    );

    expect(notificationService.lastTitle, isNull);
    expect(soundService.calls, 0);
  });

  test(
    'supports notification disabled and sound enabled independently',
    () async {
      final settingsProvider = SettingsProvider(
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        soundService: _FakeSoundService(),
      );
      await settingsProvider.initialize();
      await settingsProvider.setNotificationEnabled(
        NotificationCategory.agent,
        false,
      );
      await settingsProvider.setSoundEnabledForNotification(
        NotificationCategory.agent,
        true,
      );

      final notificationService = _FakeNotificationService();
      final soundService = _FakeSoundService();
      final dispatcher = EventFeedbackDispatcher(
        settingsProvider: settingsProvider,
        notificationService: notificationService,
        soundService: soundService,
      );

      await dispatcher.handle(
        const ChatEvent(
          type: 'session.idle',
          properties: <String, dynamic>{'sessionID': 'ses_2'},
        ),
        sessionTitleHint: 'Session Two',
      );

      expect(notificationService.lastTitle, isNull);
      expect(soundService.calls, 1);
    },
  );

  test('respects notify only when app is background', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    await settingsProvider.setNotifyOnlyWhenBackground(
      NotificationCategory.agent,
      true,
    );
    await settingsProvider.setSoundEnabledForNotification(
      NotificationCategory.agent,
      false,
    );

    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_bg_1'},
      ),
      isAppInForeground: true,
    );
    expect(notificationService.lastTitle, isNull);

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_bg_2'},
      ),
      isAppInForeground: false,
    );
    expect(notificationService.lastTitle, isNotNull);
  });

  test('respects sound only when another conversation', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    await settingsProvider.setNotificationEnabled(
      NotificationCategory.agent,
      false,
    );
    await settingsProvider.setSoundOnlyWhenAnotherSession(
      NotificationCategory.agent,
      true,
    );

    final notificationService = _FakeNotificationService();
    final soundService = _FakeSoundService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: soundService,
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_same'},
      ),
      currentSessionId: 'ses_same',
      isAppInForeground: true,
    );
    expect(soundService.calls, 0);

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_other'},
      ),
      currentSessionId: 'ses_same',
      isAppInForeground: true,
    );
    expect(soundService.calls, 1);
  });

  test('v2 permission ask dispatches pending interaction feedback', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'permission.v2.asked',
        properties: <String, dynamic>{
          'request': <String, dynamic>{'id': 'perm_v2', 'sessionID': 'ses_v2'},
        },
      ),
      sessionTitleHint: 'Background task',
      currentSessionId: 'ses_current',
    );

    expect(notificationService.lastCategory, 'permissions');
    expect(notificationService.lastSessionId, 'ses_v2');
    expect(notificationService.lastTitle, 'Background task');
  });

  test('resolves session title from nested v2 request payload', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'permission.v2.asked',
        properties: <String, dynamic>{
          'request': <String, dynamic>{
            'id': 'perm_v2',
            'sessionID': 'ses_v2',
            'sessionTitle': 'Nested build',
          },
        },
      ),
      currentSessionId: 'ses_current',
    );

    expect(notificationService.lastSessionId, 'ses_v2');
    expect(notificationService.lastTitle, 'Nested build');
    expect(notificationService.lastSessionTitle, 'Nested build');
  });

  test('resolves session title from nested session object key', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{
          'sessionID': 'ses_s',
          'session': <String, dynamic>{'title': 'Title from session object'},
        },
      ),
    );

    expect(notificationService.lastTitle, 'Title from session object');
  });

  test('falls back to l10n Session label when no title and no hint', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_x'},
      ),
    );

    expect(notificationService.lastTitle, 'Session');
    expect(notificationService.lastSessionTitle, isNull);
  });

  test('session.error uses resolved title from event', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.error',
        properties: <String, dynamic>{
          'sessionID': 'ses_e',
          'title': 'Crash task',
        },
      ),
    );

    expect(notificationService.lastCategory, 'errors');
    expect(notificationService.lastTitle, 'Crash task');
    expect(notificationService.lastSessionTitle, 'Crash task');
  });

  test('propagates serverId to notification service', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_srv'},
      ),
      sessionTitleHint: 'Server Session',
      serverId: 'server-a',
    );

    expect(notificationService.lastServerId, 'server-a');
    expect(notificationService.lastTitle, 'Server Session');
  });

  test('does not throttle different sessions in the same category', () async {
    final settingsProvider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: _FakeSoundService(),
    );
    await settingsProvider.initialize();
    final notificationService = _FakeNotificationService();
    final dispatcher = EventFeedbackDispatcher(
      settingsProvider: settingsProvider,
      notificationService: notificationService,
      soundService: _FakeSoundService(),
    );

    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_1'},
      ),
      sessionTitleHint: 'Session 1',
      currentSessionId: 'current',
    );
    await dispatcher.handle(
      const ChatEvent(
        type: 'session.idle',
        properties: <String, dynamic>{'sessionID': 'ses_2'},
      ),
      sessionTitleHint: 'Session 2',
      currentSessionId: 'current',
    );

    expect(notificationService.notifyCalls, 2);
    expect(notificationService.lastSessionId, 'ses_2');
  });

  test(
    'dismissForSession clears notifications for the given session',
    () async {
      final settingsProvider = SettingsProvider(
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        soundService: _FakeSoundService(),
      );
      await settingsProvider.initialize();
      final notificationService = _FakeNotificationService();
      final dispatcher = EventFeedbackDispatcher(
        settingsProvider: settingsProvider,
        notificationService: notificationService,
        soundService: _FakeSoundService(),
      );

      await dispatcher.dismissForSession('ses_clear');

      expect(notificationService.clearedSessionId, 'ses_clear');
    },
  );
}
