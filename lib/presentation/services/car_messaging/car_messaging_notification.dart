import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/i18n/l10n_bridge.dart';
import '../../../domain/entities/car_messaging.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';
import '../../services/notification_service.dart';

const String carMessagingCategory = 'car_messaging';
const String carMessagingReplyAction = 'car_reply';
const String carMessagingMarkReadAction = 'car_mark_read';

class CarMessagingNotificationSpec {
  const CarMessagingNotificationSpec({
    required this.id,
    required this.tag,
    required this.payload,
    required this.details,
  });

  final int id;
  final String tag;
  final String payload;
  final AndroidNotificationDetails details;
}

CarMessagingNotificationSpec buildCarMessagingNotification({
  required CarMessagingThread thread,
  required String selfName,
  required String replyLabel,
  required String markReadLabel,
  required String channelName,
  required String channelDescription,
}) {
  final normalized = thread.normalized();
  final token = carMessagingIdentityToken(normalized.identity.key);
  final id = carMessagingNotificationId(normalized.identity.key);
  final tag = carMessagingNotificationTag(normalized.identity.key);
  final self = Person(name: selfName, key: 'codewalk.user');
  final agent = Person(
    bot: true,
    name: normalized.title.isEmpty ? 'CodeWalk' : normalized.title,
    key: 'codewalk.agent.$token',
  );
  final messages = normalized.entries
      .map(
        (entry) => Message(
          entry.text,
          DateTime.fromMillisecondsSinceEpoch(entry.timestampEpochMs),
          entry.role == CarMessagingRole.agent ? agent : null,
        ),
      )
      .toList(growable: false);
  final payload = NotificationTapPayload(
    category: carMessagingCategory,
    sessionId: normalized.identity.rootSessionId,
    serverId: normalized.identity.serverId,
    directory: normalized.identity.directory,
    notificationId: id,
  ).toRaw();
  return CarMessagingNotificationSpec(
    id: id,
    tag: tag,
    payload: payload,
    details: AndroidNotificationDetails(
      'codewalk_car_messaging_v1',
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: MessagingStyleInformation(
        self,
        conversationTitle: normalized.title,
        groupConversation: false,
        messages: messages,
      ),
      tag: tag,
      groupKey: tag,
      autoCancel: false,
      onlyAlertOnce:
          normalized.entries.lastOrNull?.role == CarMessagingRole.user,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          carMessagingReplyAction,
          replyLabel,
          showsUserInterface: false,
          allowGeneratedReplies: true,
          cancelNotification: false,
          semanticAction: SemanticAction.reply,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: replyLabel),
          ],
        ),
        AndroidNotificationAction(
          carMessagingMarkReadAction,
          markReadLabel,
          showsUserInterface: false,
          cancelNotification: true,
          semanticAction: SemanticAction.markAsRead,
        ),
      ],
    ),
  );
}

String carMessagingIdentityToken(String identityKey) =>
    sha256.convert(utf8.encode(identityKey)).toString();

int carMessagingNotificationId(String identityKey) =>
    int.parse(
      carMessagingIdentityToken(identityKey).substring(0, 7),
      radix: 16,
    ) &
    0x7fffffff;

String carMessagingNotificationTag(String identityKey) =>
    'codewalk.car.${carMessagingIdentityToken(identityKey)}';

class CarMessagingNotifier {
  CarMessagingNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> show(CarMessagingThread thread) async {
    await _ensureInitialized();
    final l10n = L10nBridge.current;
    final spec = buildCarMessagingNotification(
      thread: thread,
      selfName: l10n?.chatMessageYou ?? 'You',
      replyLabel: l10n?.carMessagingReply ?? 'Reply',
      markReadLabel: l10n?.carMessagingMarkRead ?? 'Mark as read',
      channelName:
          l10n?.carMessagingConversations ?? 'Android Auto conversations',
      channelDescription:
          l10n?.carMessagingChannelDescription ??
          'Experimental CodeWalk conversation replies',
    );
    await _plugin.show(
      id: spec.id,
      title: thread.title,
      body: thread.entries.lastOrNull?.text,
      notificationDetails: NotificationDetails(android: spec.details),
      payload: spec.payload,
    );
  }

  Future<void> cancel(CarMessagingThread thread) {
    return _plugin.cancel(
      id: carMessagingNotificationId(thread.identity.key),
      tag: carMessagingNotificationTag(thread.identity.key),
    );
  }

  Future<void> showDeliveryFailure({
    required SessionAttentionIdentity identity,
  }) async {
    await _ensureInitialized();
    final l10n = L10nBridge.current;
    final id = carMessagingNotificationId(identity.key);
    await _plugin.show(
      id: id,
      title: l10n?.carMessagingDeliveryFailedTitle ?? 'Couldn\'t send reply',
      body:
          l10n?.carMessagingDeliveryFailedBody ??
          'Your voice reply could not be delivered. Open CodeWalk to retry.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'codewalk_car_messaging_v1',
          'Android Auto conversations',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
      ),
      payload: const NotificationTapPayload(
        category: carMessagingCategory,
      ).toRaw(),
    );
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
    );
    _initialized = true;
  }
}
