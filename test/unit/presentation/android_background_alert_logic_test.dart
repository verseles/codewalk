import 'dart:ui';

import 'package:codewalk/core/i18n/l10n_bridge.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/l10n/generated/app_localizations_en.dart';
import 'package:codewalk/l10n/generated/app_localizations_pt.dart';
import 'package:codewalk/presentation/services/android_background_alert_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = BackgroundAlertPlanner();

  group('background locale resolution', () {
    tearDown(() => L10nBridge.update(null));

    test('resolves a persisted locale code to its localizations', () {
      final pt = resolveBackgroundAlertLocalizations('pt');
      expect(pt, isA<AppLocalizationsPt>());
      expect(pt.localeName, 'pt');
      expect(pt.notificationSession, AppLocalizationsPt().notificationSession);
      expect(
        pt.notificationChannelErrors,
        AppLocalizationsPt().notificationChannelErrors,
      );
    });

    test('accepts a region-qualified locale code', () {
      expect(
        resolveBackgroundAlertLocalizations('pt-BR'),
        isA<AppLocalizationsPt>(),
      );
    });

    test('falls back to English for unsupported locale codes', () {
      final en = resolveBackgroundAlertLocalizations('xx');
      expect(en, isA<AppLocalizationsEn>());
      expect(en.localeName, 'en');
    });

    test('falls back to English when no locale is persisted', () {
      expect(
        resolveBackgroundAlertLocalizations(
          null,
          systemLocale: const Locale('en'),
        ),
        isA<AppLocalizationsEn>(),
      );
    });

    test('uses the supported system locale when none is persisted', () {
      expect(
        resolveBackgroundAlertLocalizations(
          null,
          systemLocale: const Locale('pt'),
        ),
        isA<AppLocalizationsPt>(),
      );
    });

    test('resolves an RTL system locale when none is persisted', () {
      expect(
        resolveBackgroundAlertLocale(null, systemLocale: const Locale('ar')),
        const Locale('ar'),
      );
    });

    test('planner emits translated strings when the locale bridge is set', () {
      L10nBridge.update(resolveBackgroundAlertLocalizations('pt'));

      const current = BackgroundPollingState(
        sessionStatusById: <String, String>{'ses_1': 'busy'},
        sessionUpdatedAtById: <String, int>{'ses_1': 100},
        sessionTitleById: <String, String>{},
        permissionRequests: <BackgroundInteractionRequest>[
          BackgroundInteractionRequest(id: 'perm_1', sessionId: 'ses_1'),
        ],
        questionRequests: <BackgroundInteractionRequest>[],
      );

      final plan = planner.plan(
        previous: BackgroundAlertSnapshot.empty(),
        current: current,
        settings: ExperienceSettings.defaults(),
        nowEpochMs: 200,
      );

      final signal = plan.signals.single;
      expect(signal.kind, BackgroundAlertKind.permission);
      expect(signal.title, AppLocalizationsPt().notificationSession);
      expect(
        signal.body,
        AppLocalizationsPt().notificationPermissionNeedsInput,
      );
    });
  });

  test('detects active sessions for busy and retry statuses', () {
    expect(
      hasActiveBackgroundSessions(const <String, String>{
        'ses_idle': 'idle',
        'ses_busy': 'busy',
      }),
      isTrue,
    );
    expect(
      hasActiveBackgroundSessions(const <String, String>{'ses_retry': 'retry'}),
      isTrue,
    );
  });

  test('ignores idle and unknown statuses when detecting active sessions', () {
    expect(
      hasActiveBackgroundSessions(const <String, String>{
        'ses_idle': 'idle',
        'ses_done': 'finished',
      }),
      isFalse,
    );
  });

  test('uses three-minute fast probe cadence', () {
    expect(kBackgroundFastProbeInterval, const Duration(minutes: 3));
  });

  test('uses five-minute tail probe cadence', () {
    expect(kBackgroundTailProbeInterval, const Duration(minutes: 5));
  });

  test(
    'background alerts require master switch and one notification category',
    () {
      final defaults = ExperienceSettings.defaults();
      expect(shouldRunAndroidBackgroundAlerts(defaults), isTrue);

      final disabledMaster = defaults.copyWith(
        androidBackgroundAlertsEnabled: false,
      );
      expect(shouldRunAndroidBackgroundAlerts(disabledMaster), isFalse);

      final disabledCategories = defaults.copyWith(
        notifications: const <NotificationCategory, bool>{
          NotificationCategory.agent: false,
          NotificationCategory.permissions: false,
          NotificationCategory.errors: false,
        },
      );
      expect(shouldRunAndroidBackgroundAlerts(disabledCategories), isFalse);
    },
  );

  test('cellular data saver disables background network only on cellular', () {
    final defaults = ExperienceSettings.defaults();

    expect(
      shouldDisableBackgroundNetworkForDataSaver(
        settings: defaults,
        isCellularTransport: true,
      ),
      isTrue,
    );

    expect(
      shouldDisableBackgroundNetworkForDataSaver(
        settings: defaults,
        isCellularTransport: false,
      ),
      isFalse,
    );

    expect(
      shouldDisableBackgroundNetworkForDataSaver(
        settings: defaults.copyWith(dataSaverEnabled: false),
        isCellularTransport: true,
      ),
      isFalse,
    );
  });

  test(
    'fallback completion requires a transition or post-heartbeat update',
    () {
      expect(
        shouldResolveFallbackCompletion(
          previousStatus: null,
          sessionUpdatedAtEpochMs: 900,
          lastMainHeartbeatEpochMs: 1000,
          nowEpochMs: 1100,
          durableCompletedAtEpochMs: 0,
        ),
        isFalse,
      );
      expect(
        shouldResolveFallbackCompletion(
          previousStatus: null,
          sessionUpdatedAtEpochMs: 1050,
          lastMainHeartbeatEpochMs: 1000,
          nowEpochMs: 1100,
          durableCompletedAtEpochMs: 0,
        ),
        isTrue,
      );
      expect(
        shouldResolveFallbackCompletion(
          previousStatus: null,
          sessionUpdatedAtEpochMs: 1200,
          lastMainHeartbeatEpochMs: 1000,
          nowEpochMs: 1100,
          durableCompletedAtEpochMs: 0,
        ),
        isFalse,
      );
      expect(
        shouldResolveFallbackCompletion(
          previousStatus: 'busy',
          sessionUpdatedAtEpochMs: 900,
          lastMainHeartbeatEpochMs: 1000,
          nowEpochMs: 1100,
          durableCompletedAtEpochMs: 0,
        ),
        isTrue,
      );
    },
  );

  test('schedules tail probe only when active sessions just ended', () {
    expect(
      shouldScheduleBackgroundTailProbe(
        previousSessionStatusById: const <String, String>{'ses_1': 'busy'},
        currentSessionStatusById: const <String, String>{'ses_1': 'idle'},
      ),
      isTrue,
    );

    expect(
      shouldScheduleBackgroundTailProbe(
        previousSessionStatusById: const <String, String>{'ses_1': 'idle'},
        currentSessionStatusById: const <String, String>{'ses_1': 'idle'},
      ),
      isFalse,
    );

    expect(
      shouldScheduleBackgroundTailProbe(
        previousSessionStatusById: const <String, String>{'ses_1': 'busy'},
        currentSessionStatusById: const <String, String>{'ses_1': 'retry'},
      ),
      isFalse,
    );
  });

  test('first run emits actionable permission and question requests', () {
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_1': 'busy'},
      sessionUpdatedAtById: <String, int>{'ses_1': 100},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      permissionRequests: <BackgroundInteractionRequest>[
        BackgroundInteractionRequest(id: 'perm_1', sessionId: 'ses_1'),
      ],
      questionRequests: <BackgroundInteractionRequest>[
        BackgroundInteractionRequest(id: 'q_1', sessionId: 'ses_1'),
      ],
    );

    final plan = planner.plan(
      previous: BackgroundAlertSnapshot.empty(),
      current: current,
      settings: ExperienceSettings.defaults(),
      nowEpochMs: 200,
    );

    expect(plan.baselineOnly, isFalse);
    expect(plan.signals.length, 2);
    expect(
      plan.signals.map((signal) => signal.kind),
      containsAll(<BackgroundAlertKind>[
        BackgroundAlertKind.permission,
        BackgroundAlertKind.question,
      ]),
    );
    expect(plan.nextSnapshot.sessionStatusById['ses_1'], 'busy');
    expect(plan.nextSnapshot.notifiedPermissionRequestIds, contains('perm_1'));
    expect(plan.nextSnapshot.notifiedQuestionRequestIds, contains('q_1'));
  });

  test('creates silent baseline when nothing actionable exists', () {
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_1': 'busy'},
      sessionUpdatedAtById: <String, int>{'ses_1': 100},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      permissionRequests: <BackgroundInteractionRequest>[],
      questionRequests: <BackgroundInteractionRequest>[],
    );

    final plan = planner.plan(
      previous: BackgroundAlertSnapshot.empty(),
      current: current,
      settings: ExperienceSettings.defaults(),
      nowEpochMs: 200,
    );

    expect(plan.baselineOnly, isTrue);
    expect(plan.signals, isEmpty);
  });

  test('first run emits error for retry status', () {
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_1': 'retry'},
      sessionUpdatedAtById: <String, int>{'ses_1': 100},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      permissionRequests: <BackgroundInteractionRequest>[],
      questionRequests: <BackgroundInteractionRequest>[],
    );

    final plan = planner.plan(
      previous: BackgroundAlertSnapshot.empty(),
      current: current,
      settings: ExperienceSettings.defaults(),
      nowEpochMs: 200,
    );

    expect(plan.baselineOnly, isFalse);
    expect(plan.signals.length, 1);
    expect(plan.signals.first.kind, BackgroundAlertKind.error);
    expect(plan.signals.first.title, 'Build feature');
  });

  test('emits completion when session transitions busy to idle', () {
    const previous = BackgroundAlertSnapshot(
      sessionStatusById: <String, String>{'ses_1': 'busy'},
      sessionUpdatedAtById: <String, int>{'ses_1': 100},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      notifiedPermissionRequestIds: <String>[],
      notifiedQuestionRequestIds: <String>[],
      lastPolledAtEpochMs: 100,
    );
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_1': 'idle'},
      sessionUpdatedAtById: <String, int>{'ses_1': 200},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      permissionRequests: <BackgroundInteractionRequest>[],
      questionRequests: <BackgroundInteractionRequest>[],
    );

    final plan = planner.plan(
      previous: previous,
      current: current,
      settings: ExperienceSettings.defaults(),
      nowEpochMs: 200,
    );

    expect(plan.baselineOnly, isFalse);
    expect(plan.signals.length, 1);
    expect(plan.signals.first.kind, BackgroundAlertKind.completion);
    expect(plan.signals.first.categoryKey, 'agent');
    expect(plan.signals.first.title, 'Build feature');
  });

  test('suppresses completion when the idle session is a child session', () {
    const previous = BackgroundAlertSnapshot(
      sessionStatusById: <String, String>{'ses_child': 'busy'},
      sessionUpdatedAtById: <String, int>{'ses_child': 100},
      sessionTitleById: <String, String>{'ses_child': 'Child Session'},
      notifiedPermissionRequestIds: <String>[],
      notifiedQuestionRequestIds: <String>[],
      lastPolledAtEpochMs: 100,
    );
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_child': 'idle'},
      sessionUpdatedAtById: <String, int>{'ses_child': 200},
      sessionTitleById: <String, String>{'ses_child': 'Child Session'},
      parentSessionIdByChild: <String, String>{'ses_child': 'ses_root'},
      permissionRequests: <BackgroundInteractionRequest>[],
      questionRequests: <BackgroundInteractionRequest>[],
    );

    final plan = planner.plan(
      previous: previous,
      current: current,
      settings: ExperienceSettings.defaults(),
      nowEpochMs: 200,
    );

    expect(
      plan.signals.where(
        (signal) => signal.kind == BackgroundAlertKind.completion,
      ),
      isEmpty,
    );
  });

  test('emits error when session transitions to retry', () {
    const previous = BackgroundAlertSnapshot(
      sessionStatusById: <String, String>{'ses_1': 'busy'},
      sessionUpdatedAtById: <String, int>{'ses_1': 100},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      notifiedPermissionRequestIds: <String>[],
      notifiedQuestionRequestIds: <String>[],
      lastPolledAtEpochMs: 100,
    );
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_1': 'retry'},
      sessionUpdatedAtById: <String, int>{'ses_1': 200},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      permissionRequests: <BackgroundInteractionRequest>[],
      questionRequests: <BackgroundInteractionRequest>[],
    );

    final plan = planner.plan(
      previous: previous,
      current: current,
      settings: ExperienceSettings.defaults(),
      nowEpochMs: 200,
    );

    expect(plan.signals.length, 1);
    expect(plan.signals.first.kind, BackgroundAlertKind.error);
    expect(plan.signals.first.categoryKey, 'errors');
    expect(plan.signals.first.title, 'Build feature');
  });

  test('emits action-required for unseen permission and question ids', () {
    const previous = BackgroundAlertSnapshot(
      sessionStatusById: <String, String>{'ses_1': 'idle'},
      sessionUpdatedAtById: <String, int>{'ses_1': 100},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      notifiedPermissionRequestIds: <String>['perm_seen'],
      notifiedQuestionRequestIds: <String>['q_seen'],
      lastPolledAtEpochMs: 100,
    );
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_1': 'idle'},
      sessionUpdatedAtById: <String, int>{'ses_1': 200},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      permissionRequests: <BackgroundInteractionRequest>[
        BackgroundInteractionRequest(id: 'perm_seen', sessionId: 'ses_1'),
        BackgroundInteractionRequest(id: 'perm_new', sessionId: 'ses_1'),
      ],
      questionRequests: <BackgroundInteractionRequest>[
        BackgroundInteractionRequest(id: 'q_seen', sessionId: 'ses_1'),
        BackgroundInteractionRequest(id: 'q_new', sessionId: 'ses_1'),
      ],
    );

    final plan = planner.plan(
      previous: previous,
      current: current,
      settings: ExperienceSettings.defaults(),
      nowEpochMs: 200,
    );

    expect(plan.signals.length, 2);
    expect(
      plan.signals.map((signal) => signal.kind),
      containsAll(<BackgroundAlertKind>[
        BackgroundAlertKind.permission,
        BackgroundAlertKind.question,
      ]),
    );
  });

  test('respects disabled notification categories', () {
    const previous = BackgroundAlertSnapshot(
      sessionStatusById: <String, String>{'ses_1': 'busy'},
      sessionUpdatedAtById: <String, int>{'ses_1': 100},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      notifiedPermissionRequestIds: <String>[],
      notifiedQuestionRequestIds: <String>[],
      lastPolledAtEpochMs: 100,
    );
    const current = BackgroundPollingState(
      sessionStatusById: <String, String>{'ses_1': 'retry'},
      sessionUpdatedAtById: <String, int>{'ses_1': 200},
      sessionTitleById: <String, String>{'ses_1': 'Build feature'},
      permissionRequests: <BackgroundInteractionRequest>[
        BackgroundInteractionRequest(id: 'perm_new', sessionId: 'ses_1'),
      ],
      questionRequests: <BackgroundInteractionRequest>[],
    );
    final settings = ExperienceSettings.defaults().copyWith(
      notifications: const <NotificationCategory, bool>{
        NotificationCategory.agent: false,
        NotificationCategory.permissions: false,
        NotificationCategory.errors: false,
      },
    );

    final plan = planner.plan(
      previous: previous,
      current: current,
      settings: settings,
      nowEpochMs: 200,
    );

    expect(plan.signals, isEmpty);
  });

  group('snapshot title pruning', () {
    test('drops titles for sessions absent from the live poll', () {
      final pruned = pruneBackgroundAlertSessionTitles(
        titles: const <String, String>{
          'ses_live': 'Live title',
          'ses_gone': 'Stale title',
        },
        updatedAtById: const <String, int>{'ses_live': 2, 'ses_gone': 1},
        liveSessionIds: const <String>{'ses_live'},
      );
      expect(pruned, <String, String>{'ses_live': 'Live title'});
    });

    test('caps entries by recency when over budget', () {
      final titles = <String, String>{
        for (var i = 0; i < 10; i++) 'ses_$i': 'Title $i',
      };
      final updatedAt = <String, int>{
        for (var i = 0; i < 10; i++) 'ses_$i': i,
      };
      final pruned = pruneBackgroundAlertSessionTitles(
        titles: titles,
        updatedAtById: updatedAt,
        liveSessionIds: titles.keys.toSet(),
        maxEntries: 3,
      );
      expect(pruned.keys, <String>['ses_9', 'ses_8', 'ses_7']);
    });

    test('fromJson bounds oversized legacy title maps', () {
      final json = <String, dynamic>{
        'sessionStatusById': <String, dynamic>{},
        'sessionUpdatedAtById': <String, dynamic>{},
        'sessionTitleById': <String, dynamic>{
          for (var i = 0; i < kBackgroundAlertSnapshotMaxSessions + 100; i++)
            'ses_$i': 'Title $i',
        },
        'notifiedPermissionRequestIds': <String>[],
        'notifiedQuestionRequestIds': <String>[],
        'lastPolledAtEpochMs': 1,
      };
      final snapshot = BackgroundAlertSnapshot.fromJson(json);
      expect(
        snapshot.sessionTitleById.length,
        kBackgroundAlertSnapshotMaxSessions,
      );
    });

    test('planner next snapshot keeps only live session titles', () {
      const current = BackgroundPollingState(
        sessionStatusById: <String, String>{'ses_live': 'busy'},
        sessionUpdatedAtById: <String, int>{
          'ses_live': 200,
          'ses_gone': 100,
        },
        sessionTitleById: <String, String>{
          'ses_live': 'Live title',
          'ses_gone': 'Stale title',
        },
        permissionRequests: <BackgroundInteractionRequest>[],
        questionRequests: <BackgroundInteractionRequest>[],
      );
      final plan = planner.plan(
        previous: BackgroundAlertSnapshot.empty(),
        current: current,
        settings: ExperienceSettings.defaults(),
        nowEpochMs: 300,
      );
      expect(
        plan.nextSnapshot.sessionTitleById,
        <String, String>{'ses_live': 'Live title'},
      );
      expect(
        plan.nextSnapshot.sessionUpdatedAtById,
        <String, int>{'ses_live': 200},
      );
    });
  });
}
