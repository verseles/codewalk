import 'package:codewalk/domain/entities/car_messaging.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:codewalk/presentation/services/car_messaging/car_messaging_notification.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const identity = SessionAttentionIdentity(
  serverId: 'server-a',
  directory: '/work/app',
  rootSessionId: 'session-a',
);

void main() {
  test('builds stable MessagingStyle with one RemoteInput and mark-read', () {
    final thread = CarMessagingThread(
      identity: identity,
      title: 'Session title',
      entries: <CarMessagingEntry>[
        CarMessagingEntry(
          role: CarMessagingRole.agent,
          text: 'Final answer',
          timestampEpochMs: DateTime(2026).millisecondsSinceEpoch,
        ),
      ],
      updatedAtEpochMs: DateTime(2026).millisecondsSinceEpoch,
      unread: true,
    );
    final first = buildCarMessagingNotification(
      thread: thread,
      selfName: 'You',
      replyLabel: 'Reply',
      markReadLabel: 'Mark as read',
      channelName: 'Conversations',
      channelDescription: 'Description',
    );
    final second = buildCarMessagingNotification(
      thread: thread,
      selfName: 'You',
      replyLabel: 'Reply',
      markReadLabel: 'Mark as read',
      channelName: 'Conversations',
      channelDescription: 'Description',
    );

    expect(first.id, second.id);
    expect(first.tag, second.tag);
    expect(first.details.category, AndroidNotificationCategory.message);
    final style = first.details.styleInformation as MessagingStyleInformation;
    expect(style.conversationTitle, 'Session title');
    expect(style.messages!.single.text, 'Final answer');
    expect(style.messages!.single.person!.bot, isTrue);
    final actions = first.details.actions!;
    expect(actions, hasLength(2));
    expect(actions.first.semanticAction, SemanticAction.reply);
    expect(actions.first.showsUserInterface, isFalse);
    expect(actions.first.cancelNotification, isFalse);
    expect(actions.first.inputs, hasLength(1));
    expect(actions.first.inputs.single.allowFreeFormInput, isTrue);
    expect(actions.first.inputs.single.label, 'Reply');
    expect(actions.last.semanticAction, SemanticAction.markAsRead);
    expect(actions.last.inputs, isEmpty);
  });
}
