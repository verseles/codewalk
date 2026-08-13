import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../../data/car_messaging/car_messaging_store.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';
import 'car_messaging_action_handler.dart';
import 'car_messaging_notification.dart';

class CarMessagingRuntime {
  const CarMessagingRuntime._();

  static bool get _isAndroidRuntime =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> disable({
    CarMessagingStore? store,
    CarMessagingNotifier? notifier,
  }) async {
    final effectiveStore = store ?? CarMessagingStore();
    final state = await effectiveStore.read();
    final effectiveNotifier = notifier ?? CarMessagingNotifier();
    for (final thread in state.threads) {
      await effectiveNotifier.cancel(thread);
    }
    await effectiveStore.clear();
    await cancelPendingReplyWork();
  }

  static Future<void> cancelPendingReplyWork() async {
    if (!_isAndroidRuntime) return;
    await Workmanager().cancelByTag(carMessagingReplyWorkTag);
  }

  static Future<void> removeServer(
    String serverId, {
    CarMessagingStore? store,
    CarMessagingNotifier? notifier,
  }) async {
    if (!_isAndroidRuntime) return;
    final effectiveStore = store ?? CarMessagingStore();
    final state = await effectiveStore.read();
    final effectiveNotifier = notifier ?? CarMessagingNotifier();
    for (final thread in state.threads.where(
      (thread) => thread.identity.serverId == serverId.trim(),
    )) {
      await effectiveNotifier.cancel(thread);
    }
    await effectiveStore.removeServer(serverId);
  }

  static Future<void> removeIdentity(
    SessionAttentionIdentity identity, {
    CarMessagingStore? store,
    CarMessagingNotifier? notifier,
  }) async {
    if (!_isAndroidRuntime) return;
    final effectiveStore = store ?? CarMessagingStore();
    final state = await effectiveStore.read();
    final normalized = identity.normalized();
    final matching = state.threads
        .where((thread) => thread.identity == normalized)
        .firstOrNull;
    final effectiveNotifier = notifier ?? CarMessagingNotifier();
    if (matching != null) {
      await effectiveNotifier.cancel(matching);
    }
    await effectiveStore.removeIdentity(normalized);
  }
}
