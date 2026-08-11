import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/services/android_background_alert_worker.dart';
import 'package:codewalk/presentation/services/permission_auto_approve_runtime.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('always returns always reply unconditionally', () {
    expect(
      permissionAutoApproveReplyForAlwaysPatterns(const <String>[
        'git status*',
      ]),
      'always',
    );
    expect(
      permissionAutoApproveReplyForAlwaysPatterns(const <String>['', ' ']),
      'always',
    );
  });

  test('derives permission reply from chat permission request', () {
    const request = ChatPermissionRequest(
      id: 'perm_1',
      sessionId: 'ses_root',
      permission: 'bash',
      patterns: <String>['*'],
      always: <String>['git status*'],
      metadata: <String, dynamic>{},
    );

    expect(permissionAutoApproveReplyForRequest(request), 'always');
  });

  test('collects descendant session ids transitively', () {
    expect(
      collectThreadSessionIds(
        currentSessionId: 'ses_root',
        parentSessionIdByChild: const <String, String>{
          'ses_child': 'ses_root',
          'ses_grandchild': 'ses_child',
          'ses_other': 'ses_elsewhere',
        },
      ),
      equals(<String>{'ses_root', 'ses_child', 'ses_grandchild'}),
    );
  });

  test(
    'resolves background thread session ids from stored and derived data',
    () {
      const context = PermissionAutoApproveBackgroundContext(
        serverId: 'srv_1',
        scopeId: '/repo',
        currentSessionId: 'ses_root',
        threadSessionIds: <String>['ses_root', 'ses_existing_child'],
        updatedAtEpochMs: 123,
      );

      expect(
        resolveThreadSessionIdsForBackgroundContext(
          context: context,
          parentSessionIdByChild: const <String, String>{
            'ses_existing_child': 'ses_root',
            'ses_new_child': 'ses_root',
          },
        ),
        equals(<String>{'ses_root', 'ses_existing_child', 'ses_new_child'}),
      );
    },
  );

  test('clears background auto-approve context on server change', () {
    expect(
      shouldClearBackgroundPermissionAutoApproveContextForTransition(
        currentServerId: 'srv_a',
        currentScopeId: '/repo-a',
        currentDirectory: '/repo-a',
        nextServerId: 'srv_b',
        nextScopeId: '/repo-a',
        nextDirectory: '/repo-a',
      ),
      isTrue,
    );
  });

  test('clears background auto-approve context on scope change', () {
    expect(
      shouldClearBackgroundPermissionAutoApproveContextForTransition(
        currentServerId: 'srv_a',
        currentScopeId: '/repo-a',
        currentDirectory: '/repo-a',
        nextServerId: 'srv_a',
        nextScopeId: '/repo-b',
        nextDirectory: '/repo-b',
      ),
      isTrue,
    );
  });

  test('keeps background auto-approve context when scope is unchanged', () {
    expect(
      shouldClearBackgroundPermissionAutoApproveContextForTransition(
        currentServerId: 'srv_a',
        currentScopeId: '/repo-a',
        currentDirectory: '/repo-a',
        nextServerId: 'srv_a',
        nextScopeId: '/repo-a',
        nextDirectory: '/repo-a',
      ),
      isFalse,
    );
  });

  test('worker context stays disabled until a valid context is primed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    const context = PermissionAutoApproveBackgroundContext(
      serverId: 'srv_test',
      scopeId: '/repo/a',
      currentSessionId: 'ses_a',
      threadSessionIds: <String>['ses_a'],
      updatedAtEpochMs: 123,
    );
    const contextKey =
        'codewalk.android.background.permission_auto_approve.v1::srv_test';
    const disabledKey =
        'codewalk.android.background.permission_auto_approve.v1-disabled::srv_test';

    await AndroidBackgroundAlertWorker.primePermissionAutoApproveContext(
      context: context,
    );
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(contextKey), isNotNull);
    expect(prefs.getBool(disabledKey), isFalse);
    expect(
      await AndroidBackgroundAlertWorker.hasEnabledPermissionAutoApproveContext(
        serverId: 'srv_test',
      ),
      isTrue,
    );

    var generationChecks = 0;
    await AndroidBackgroundAlertWorker.primePermissionAutoApproveContext(
      context: context,
      isCurrent: () {
        generationChecks += 1;
        return generationChecks == 1;
      },
    );
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(contextKey), isNotNull);
    expect(prefs.getBool(disabledKey), isTrue);
    expect(
      await AndroidBackgroundAlertWorker.hasEnabledPermissionAutoApproveContext(
        serverId: 'srv_test',
      ),
      isFalse,
    );

    await AndroidBackgroundAlertWorker.primePermissionAutoApproveContext(
      context: context,
    );

    await AndroidBackgroundAlertWorker.disablePermissionAutoApproveContext(
      serverId: 'srv_test',
    );
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(contextKey), isNotNull);
    expect(prefs.getBool(disabledKey), isTrue);
    expect(
      await AndroidBackgroundAlertWorker.hasEnabledPermissionAutoApproveContext(
        serverId: 'srv_test',
      ),
      isFalse,
    );

    await AndroidBackgroundAlertWorker.clearPermissionAutoApproveContext(
      serverId: 'srv_test',
    );
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(contextKey), isNull);
    expect(prefs.getBool(disabledKey), isTrue);
    expect(
      await AndroidBackgroundAlertWorker.hasEnabledPermissionAutoApproveContext(
        serverId: 'srv_test',
      ),
      isFalse,
    );
  });
}
