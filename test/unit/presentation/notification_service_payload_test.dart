import 'package:codewalk/presentation/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel notificationChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('serializes and parses notification payload with session id', () {
    const payload = NotificationTapPayload(
      category: 'agent',
      sessionId: 'ses_123',
      serverId: 'server-a',
      directory: '/tmp/workspace',
    );

    final raw = payload.toRaw();
    final parsed = NotificationTapPayload.fromRaw(raw);

    expect(parsed, isNotNull);
    expect(parsed?.category, 'agent');
    expect(parsed?.sessionId, 'ses_123');
    expect(parsed?.serverId, 'server-a');
    expect(parsed?.directory, '/tmp/workspace');
    expect(parsed?.notificationId, isNull);
  });

  test('serializes and parses notification id metadata', () {
    const payload = NotificationTapPayload(
      category: 'agent',
      sessionId: 'ses_123',
      notificationId: 42,
    );

    final parsed = NotificationTapPayload.fromRaw(payload.toRaw());

    expect(parsed?.notificationId, 42);
  });

  test('keeps notification id zero valid', () {
    const payload = NotificationTapPayload(
      category: 'agent',
      sessionId: 'ses_123',
      notificationId: 0,
    );

    final parsed = NotificationTapPayload.fromRaw(payload.toRaw());

    expect(parsed?.notificationId, 0);
  });

  test(
    'notification tap activates app, emits payload, and clears session',
    () async {
      final calls = <String>[];
      final service = NotificationService(
        activateApp: () async {
          calls.add('activate');
        },
        activeNotificationsReader: () async => const <ActiveNotification>[],
        notificationCanceller: ({required id, tag}) async {
          calls.add('cancel:$id:${tag ?? ''}');
        },
        assumeInitialized: true,
      );
      addTearDown(service.dispose);
      const payload = NotificationTapPayload(
        category: 'agent',
        sessionId: 'ses_1',
        notificationId: 42,
      );

      final emitted = expectLater(
        service.onNotificationTapped,
        emits(
          isA<NotificationTapPayload>()
              .having((item) => item.sessionId, 'sessionId', 'ses_1')
              .having((item) => item.notificationId, 'notificationId', 42),
        ),
      );

      await service.debugHandleRawTap(payload.toRaw());
      await emitted;

      expect(calls.first, 'activate');
      expect(calls, contains('cancel:42:session:ses_1'));
    },
  );

  test(
    'clearNotificationsForSession cancels active notifications by payload',
    () async {
      final cancelled = <int>[];
      final service = NotificationService(
        activeNotificationsReader: () async => <ActiveNotification>[
          ActiveNotification(
            id: 7,
            payload: const NotificationTapPayload(
              category: 'agent',
              sessionId: 'ses_1',
            ).toRaw(),
          ),
          ActiveNotification(
            id: 8,
            payload: const NotificationTapPayload(
              category: 'agent',
              sessionId: 'other',
            ).toRaw(),
          ),
        ],
        notificationCanceller: ({required id, tag}) async {
          cancelled.add(id);
        },
        assumeInitialized: true,
      );
      addTearDown(service.dispose);

      await service.clearNotificationsForSession('ses_1');

      expect(cancelled, contains(7));
      expect(cancelled, isNot(contains(8)));
    },
  );

  test(
    'clearNotificationsForSession broadly clears Windows tracked toasts when history is unavailable',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });
      final calls = <String>[];
      final service = NotificationService(
        activeNotificationsReader: () async => const <ActiveNotification>[],
        notificationCanceller: ({required id, tag}) async {
          calls.add('cancel:$id');
        },
        allNotificationsCanceller: () async {
          calls.add('cancelAll');
        },
        assumeInitialized: true,
      );
      addTearDown(service.dispose);

      service.debugTrackNotificationForSession('ses_1', 7);
      await service.clearNotificationsForSession('ses_1');

      expect(calls, contains('cancel:7'));
      expect(calls, contains('cancelAll'));
    },
  );

  test(
    'clearNotificationsForSession skips Windows native history when no toast is tracked',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });
      var activeReads = 0;
      final calls = <String>[];
      final service = NotificationService(
        activeNotificationsReader: () async {
          activeReads += 1;
          return const <ActiveNotification>[];
        },
        notificationCanceller: ({required id, tag}) async {
          calls.add('cancel:$id');
        },
        allNotificationsCanceller: () async {
          calls.add('cancelAll');
        },
        assumeInitialized: true,
      );
      addTearDown(service.dispose);

      await service.clearNotificationsForSession('ses_without_toasts');

      expect(activeReads, 0);
      expect(calls, isEmpty);
    },
  );

  test('supports payload without directory metadata', () {
    const payload = NotificationTapPayload(
      category: 'agent',
      sessionId: 'ses_1',
    );

    final raw = payload.toRaw();
    final parsed = NotificationTapPayload.fromRaw(raw);

    expect(parsed, isNotNull);
    expect(parsed?.sessionId, 'ses_1');
    expect(parsed?.directory, isNull);
  });

  test('returns null for invalid payload', () {
    expect(NotificationTapPayload.fromRaw('invalid-json'), isNull);
    expect(NotificationTapPayload.fromRaw('{}'), isNull);
  });

  test(
    'android group summary uses the resolved session title',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      addTearDown(() {
        FlutterLocalNotificationsPlatform.instance =
            AndroidFlutterLocalNotificationsPlugin();
      });
      final shows = await _captureShows();

      final service = NotificationService(
        assumeInitialized: true,
      );
      addTearDown(service.dispose);

      final result = await service.notify(
        title: 'Build feature',
        body: 'Agent finished',
        category: 'agent',
        sessionId: 'ses_1',
        serverId: 'server-a',
        directory: '/tmp/workspace',
        sessionTitle: 'Build feature',
      );

      expect(result, isTrue);
      expect(shows, hasLength(2));
      final summary = shows.singleWhere(
        (show) => show.isGroupSummary,
      );
      expect(summary.title, 'Build feature');
      expect(summary.body, isNotNull);
      final payload = NotificationTapPayload.fromRaw(summary.payload);
      expect(payload?.sessionId, 'ses_1');
      expect(payload?.serverId, 'server-a');
      expect(payload?.directory, '/tmp/workspace');
    },
  );

  test(
    'android group summary falls back when session title is blank',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      addTearDown(() {
        FlutterLocalNotificationsPlatform.instance =
            AndroidFlutterLocalNotificationsPlugin();
      });
      final shows = await _captureShows();

      final service = NotificationService(
        assumeInitialized: true,
      );
      addTearDown(service.dispose);

      await service.notify(
        title: 'Conversation',
        body: 'Agent finished',
        category: 'agent',
        sessionId: 'ses_2',
        sessionTitle: '   ',
      );

      final summary = shows.singleWhere(
        (show) => show.isGroupSummary,
      );
      expect(summary.title, 'Conversation updates');
    },
  );

  test(
    'android group summary is skipped when there is no session id',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      addTearDown(() {
        FlutterLocalNotificationsPlatform.instance =
            AndroidFlutterLocalNotificationsPlugin();
      });
      final shows = await _captureShows();

      final service = NotificationService(
        assumeInitialized: true,
      );
      addTearDown(service.dispose);

      await service.notify(
        title: 'Alert',
        body: 'Body',
        category: 'agent',
      );

      expect(shows, hasLength(1));
      expect(shows.single.isGroupSummary, isFalse);
    },
  );
}

Future<List<_RecordedShow>> _captureShows() async {
  final shows = <_RecordedShow>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(notificationChannel, (call) async {
    if (call.method == 'show') {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final specifics =
          Map<String, dynamic>.from(args['platformSpecifics'] as Map? ?? const {});
      shows.add(
        _RecordedShow(
          id: args['id'] as int? ?? 0,
          title: args['title']?.toString(),
          body: args['body']?.toString(),
          payload: args['payload']?.toString(),
          setAsGroupSummary: specifics['setAsGroupSummary'] == true,
        ),
      );
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(notificationChannel, null);
  });
  return shows;
}

class _RecordedShow {
  const _RecordedShow({
    required this.id,
    this.title,
    this.body,
    this.payload,
    this.setAsGroupSummary = false,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
  final bool setAsGroupSummary;

  bool get isGroupSummary => setAsGroupSummary;
}
