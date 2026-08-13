import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/car_messaging/car_messaging_store.dart';
import '../../../domain/entities/car_messaging.dart';
import '../../../domain/entities/experience_settings.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';
import 'car_messaging_gate.dart';
import 'car_messaging_notification.dart';

const String carMessagingReplyTaskName = 'codewalk.car.messaging.reply';
const String carMessagingReplyWorkTag = 'codewalk.car.messaging';

typedef CarMessagingTaskScheduler = Future<void> Function(String replyId);

@pragma('vm:entry-point')
void codewalkCarMessagingBackgroundResponse(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  await CarMessagingActionHandler().handle(response);
}

class CarMessagingActionHandler {
  CarMessagingActionHandler({
    CarMessagingStore? store,
    CarMessagingNotifier? notifier,
    CarMessagingTaskScheduler? schedule,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
    bool? featureEnabled,
  }) : _store = store ?? CarMessagingStore(),
       _notifier = notifier ?? CarMessagingNotifier(),
       _schedule = schedule ?? _scheduleReply,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _featureEnabled =
           featureEnabled ?? FeatureFlags.androidAutoMessagingPrototype;

  final CarMessagingStore _store;
  final CarMessagingNotifier _notifier;
  final CarMessagingTaskScheduler _schedule;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final bool _featureEnabled;

  Future<void> handle(NotificationResponse response) async {
    if (!_featureEnabled) return;
    final prefs = await _preferences();
    final rawSettings = prefs.getString(AppConstants.experienceSettingsKey);
    final settings = _readSettings(rawSettings);
    if (!settings.androidBackgroundAlertsEnabled ||
        !settings.androidAutoMessagingEnabled) {
      return;
    }
    final payload = _CarMessagingActionPayload.fromRaw(response.payload);
    if (payload == null) {
      return;
    }
    if (!_isSupportedActiveServer(prefs, payload.serverId)) return;
    CarMessagingState state;
    try {
      state = await _store.read();
    } catch (_) {
      await _notifier.showDeliveryFailure(
        identity: SessionAttentionIdentity(
          serverId: payload.serverId,
          directory: payload.directory,
          rootSessionId: payload.sessionId,
        ).normalized(),
      );
      return;
    }
    final thread = state.threads
        .where(
          (thread) =>
              thread.identity.serverId == payload.serverId &&
              thread.identity.directory == payload.directory &&
              thread.identity.rootSessionId == payload.sessionId,
        )
        .firstOrNull;
    if (thread == null) return;
    final identity = thread.identity;
    if (response.actionId == carMessagingMarkReadAction) {
      await _store.markRead(identity);
      return;
    }
    final text = response.input?.trim();
    if (response.actionId != carMessagingReplyAction ||
        text == null ||
        text.isEmpty) {
      return;
    }
    final now = _now();
    final replyId = sha256
        .convert(
          utf8.encode(
            '${identity.key}\u0000${now.microsecondsSinceEpoch}\u0000$text',
          ),
        )
        .toString()
        .substring(0, 24);
    final baselineAssistantMessageId = thread.entries
        .where((entry) => entry.role == CarMessagingRole.agent)
        .map((entry) => entry.messageId)
        .whereType<String>()
        .lastOrNull;
    try {
      final enqueued = await _store.enqueueReply(
        CarMessagingReply(
          id: replyId,
          identity: identity,
          text: text,
          createdAtEpochMs: now.millisecondsSinceEpoch,
          baselineAssistantMessageId: baselineAssistantMessageId,
        ),
      );
      if (!enqueued) {
        await _notifier.showDeliveryFailure(identity: identity);
        return;
      }
      await _store.upsertThread(
        CarMessagingThread(
          identity: identity,
          title: thread.title,
          entries: <CarMessagingEntry>[
            ...thread.entries,
            CarMessagingEntry(
              role: CarMessagingRole.user,
              text: text,
              timestampEpochMs: now.millisecondsSinceEpoch,
            ),
          ],
          updatedAtEpochMs: now.millisecondsSinceEpoch,
        ),
      );
      await _schedule(replyId);
    } catch (_) {
      await _notifier.showDeliveryFailure(identity: identity);
    }
  }

  ExperienceSettings _readSettings(String? rawSettings) {
    if (rawSettings == null || rawSettings.trim().isEmpty) {
      return ExperienceSettings.defaults();
    }
    try {
      final decoded = jsonDecode(rawSettings);
      if (decoded is Map) {
        return ExperienceSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Corrupt persisted settings fail closed to defaults.
    }
    return ExperienceSettings.defaults();
  }

  bool _isSupportedActiveServer(
    SharedPreferences prefs,
    String payloadServerId,
  ) {
    final activeServerId =
        prefs.getString(AppConstants.activeServerIdKey)?.trim() ?? '';
    if (activeServerId.isNotEmpty && activeServerId != payloadServerId) {
      return false;
    }
    final profilesRaw = prefs.getString(AppConstants.serverProfilesKey);
    if (profilesRaw == null || profilesRaw.trim().isEmpty) {
      return true;
    }
    try {
      final decoded = jsonDecode(profilesRaw);
      if (decoded is! List) return false;
      for (final raw in decoded.whereType<Map>()) {
        final profile = Map<String, dynamic>.from(raw);
        if (profile['id']?.toString() != payloadServerId) continue;
        return supportsCarMessagingServerProfile(profile);
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static Future<void> _scheduleReply(String replyId) {
    return Workmanager().registerOneOffTask(
      'codewalk.car.messaging.reply.$replyId',
      carMessagingReplyTaskName,
      inputData: <String, dynamic>{'replyId': replyId},
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
      outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
      tag: carMessagingReplyWorkTag,
    );
  }
}

class _CarMessagingActionPayload {
  const _CarMessagingActionPayload({
    required this.serverId,
    required this.directory,
    required this.sessionId,
  });

  final String serverId;
  final String directory;
  final String sessionId;

  static _CarMessagingActionPayload? fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (decoded['category'] != carMessagingCategory) return null;
      final serverId = decoded['serverId']?.toString().trim() ?? '';
      final directory = decoded['directory']?.toString().trim() ?? '';
      final sessionId = decoded['sessionId']?.toString().trim() ?? '';
      if (serverId.isEmpty || directory.isEmpty || sessionId.isEmpty) {
        return null;
      }
      return _CarMessagingActionPayload(
        serverId: serverId,
        directory: directory,
        sessionId: sessionId,
      );
    } catch (_) {
      return null;
    }
  }
}
