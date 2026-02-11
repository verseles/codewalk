import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/event_feedback_dispatcher.dart';
import 'package:codewalk/presentation/services/notification_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';

import '../../support/fakes.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService();

  String? lastTitle;
  String? lastBody;
  String? lastCategory;
  String? lastSessionId;

  @override
  Future<bool> notify({
    required String title,
    required String body,
    required String category,
    String? sessionId,
  }) async {
    lastTitle = title;
    lastBody = body;
    lastCategory = category;
    lastSessionId = sessionId;
    return true;
  }
}

class _FakeSoundService extends SoundService {
  @override
  Future<bool> play(SoundOption option) async {
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
    expect(notificationService.lastTitle, 'Finished: Refactor login flow');
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
      final dispatcher = EventFeedbackDispatcher(
        settingsProvider: settingsProvider,
        notificationService: notificationService,
        soundService: _FakeSoundService(),
      );

      await dispatcher.handle(
        const ChatEvent(
          type: 'session.idle',
          properties: <String, dynamic>{'sessionID': 'ses_2'},
        ),
        sessionTitleHint: 'Session Two',
      );

      expect(notificationService.lastTitle, isNull);
    },
  );
}
