import 'dart:convert';

import 'package:codewalk/core/constants/app_constants.dart';
import 'package:codewalk/data/car_messaging/car_messaging_file_store.dart';
import 'package:codewalk/data/car_messaging/car_messaging_store.dart';
import 'package:codewalk/domain/entities/car_messaging.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:codewalk/presentation/services/car_messaging/car_messaging_action_handler.dart';
import 'package:codewalk/presentation/services/car_messaging/car_messaging_notification.dart';
import 'package:codewalk/presentation/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryKeyStorage implements CarMessagingKeyStorage {
  String? value;
  @override
  Future<void> delete() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _MemoryFileStore implements CarMessagingFileStore {
  String? value;
  @override
  Future<void> delete() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();
  @override
  Future<void> writeAtomically(String value) async => this.value = value;
}

class _ThrowingFileStore extends _MemoryFileStore {
  @override
  Future<String?> read() => throw StateError('storage unavailable');
}

class _RecordingNotifier extends CarMessagingNotifier {
  final List<SessionAttentionIdentity> failures = <SessionAttentionIdentity>[];

  @override
  Future<void> showDeliveryFailure({
    required SessionAttentionIdentity identity,
  }) async => failures.add(identity);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'persists local echo and encrypted reply before scheduling work',
    () async {
      final settings = ExperienceSettings.defaults().copyWith(
        androidAutoMessagingEnabled: true,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.experienceSettingsKey: jsonEncode(settings.toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final files = _MemoryFileStore();
      final store = CarMessagingStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: files,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      const identity = SessionAttentionIdentity(
        serverId: 'server-a',
        directory: '/work/app',
        rootSessionId: 'session-a',
      );
      await store.upsertThread(
        const CarMessagingThread(
          identity: identity,
          title: 'Session',
          entries: <CarMessagingEntry>[
            CarMessagingEntry(
              role: CarMessagingRole.agent,
              text: 'Previous',
              timestampEpochMs: 900,
              messageId: 'message-old',
            ),
          ],
          updatedAtEpochMs: 900,
        ),
      );
      var scheduled = false;
      final handler = CarMessagingActionHandler(
        store: store,
        preferences: () async => prefs,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
        featureEnabled: true,
        schedule: (replyId) async {
          final persisted = await store.read();
          expect(persisted.replies.single.id, replyId);
          expect(persisted.threads.single.entries.last.text, 'Continue');
          expect(files.value, isNot(contains('Continue')));
          scheduled = true;
        },
      );
      final payload = NotificationTapPayload(
        category: carMessagingCategory,
        serverId: identity.serverId,
        directory: identity.directory,
        sessionId: identity.rootSessionId,
      ).toRaw();

      await handler.handle(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: carMessagingReplyAction,
          input: 'Continue',
          payload: payload,
        ),
      );

      expect(scheduled, isTrue);
      expect(
        (await store.read()).replies.single.baselineAssistantMessageId,
        'message-old',
      );
    },
  );

  test('gate off leaves durable state untouched', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
    );
    final handler = CarMessagingActionHandler(
      store: store,
      featureEnabled: false,
      schedule: (_) async => fail('must not schedule'),
    );

    await handler.handle(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: carMessagingReplyAction,
        input: 'Continue',
      ),
    );

    expect((await store.read()).replies, isEmpty);
  });

  test('rejects replies from a stale or unsupported server profile', () async {
    final settings = ExperienceSettings.defaults().copyWith(
      androidAutoMessagingEnabled: true,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.experienceSettingsKey: jsonEncode(settings.toJson()),
      AppConstants.activeServerIdKey: 'server-b',
      AppConstants.serverProfilesKey: jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'server-b',
          'url': 'http://localhost:4099',
          'oauthEnabled': true,
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    const identity = SessionAttentionIdentity(
      serverId: 'server-a',
      directory: '/work/app',
      rootSessionId: 'session-a',
    );
    await store.upsertThread(
      const CarMessagingThread(
        identity: identity,
        title: 'Session',
        entries: <CarMessagingEntry>[],
        updatedAtEpochMs: 900,
      ),
    );
    final handler = CarMessagingActionHandler(
      store: store,
      preferences: () async => prefs,
      featureEnabled: true,
      schedule: (_) async => fail('must not schedule'),
    );
    final payload = NotificationTapPayload(
      category: carMessagingCategory,
      serverId: identity.serverId,
      directory: identity.directory,
      sessionId: identity.rootSessionId,
    ).toRaw();

    await handler.handle(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: carMessagingReplyAction,
        input: 'Continue',
        payload: payload,
      ),
    );

    expect((await store.read()).replies, isEmpty);
  });

  test('tolerates corrupt persisted settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.experienceSettingsKey: '{broken json',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
    );
    final handler = CarMessagingActionHandler(
      store: store,
      preferences: () async => prefs,
      featureEnabled: true,
      schedule: (_) async => fail('must not schedule'),
    );

    await handler.handle(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: carMessagingReplyAction,
        input: 'Continue',
      ),
    );

    expect((await store.read()).replies, isEmpty);
  });

  test('reports storage failure without scheduling a reply', () async {
    final settings = ExperienceSettings.defaults().copyWith(
      androidAutoMessagingEnabled: true,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.experienceSettingsKey: jsonEncode(settings.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = _RecordingNotifier();
    final handler = CarMessagingActionHandler(
      store: CarMessagingStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: _ThrowingFileStore(),
      ),
      notifier: notifier,
      preferences: () async => prefs,
      featureEnabled: true,
      schedule: (_) async => fail('must not schedule'),
    );
    final payload = const NotificationTapPayload(
      category: carMessagingCategory,
      serverId: 'server-a',
      directory: '/work/app',
      sessionId: 'session-a',
    ).toRaw();

    await handler.handle(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: carMessagingReplyAction,
        input: 'Continue',
        payload: payload,
      ),
    );

    expect(notifier.failures, hasLength(1));
  });

  test(
    'reports failure and does not schedule when reply queue is full',
    () async {
      final settings = ExperienceSettings.defaults().copyWith(
        androidAutoMessagingEnabled: true,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.experienceSettingsKey: jsonEncode(settings.toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final store = CarMessagingStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: _MemoryFileStore(),
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      const identity = SessionAttentionIdentity(
        serverId: 'server-a',
        directory: '/work/app',
        rootSessionId: 'session-a',
      );
      await store.upsertThread(
        const CarMessagingThread(
          identity: identity,
          title: 'Session',
          entries: <CarMessagingEntry>[
            CarMessagingEntry(
              role: CarMessagingRole.agent,
              text: 'Previous',
              timestampEpochMs: 900,
            ),
          ],
          updatedAtEpochMs: 900,
        ),
      );
      for (var index = 0; index < 5; index += 1) {
        await store.enqueueReply(
          CarMessagingReply(
            id: 'reply-$index',
            identity: identity,
            text: 'reply $index',
            createdAtEpochMs: 900 + index,
          ),
        );
      }
      final notifier = _RecordingNotifier();
      final handler = CarMessagingActionHandler(
        store: store,
        notifier: notifier,
        preferences: () async => prefs,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
        featureEnabled: true,
        schedule: (_) async => fail('must not schedule'),
      );
      final payload = NotificationTapPayload(
        category: carMessagingCategory,
        serverId: identity.serverId,
        directory: identity.directory,
        sessionId: identity.rootSessionId,
      ).toRaw();

      await handler.handle(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: carMessagingReplyAction,
          input: 'Continue',
          payload: payload,
        ),
      );

      final state = await store.read();
      expect(state.replies, hasLength(5));
      expect(
        state.threads.single.entries.any((entry) => entry.text == 'Continue'),
        isFalse,
      );
      expect(notifier.failures, hasLength(1));
    },
  );
}
