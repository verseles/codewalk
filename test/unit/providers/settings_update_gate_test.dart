import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/update_check_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/fakes.dart';
import '../../support/release_history_fakes.dart';

const _v2 = UpdateCheckResult(
  latestVersion: '2.0.0',
  releaseTag: 'v2.0.0',
  releaseUrl: 'https://github.com/verseles/codewalk/releases/tag/v2.0.0',
  apkUrl: 'https://example.com/v2.0.0/codewalk.apk',
  announcement: 'CodeWalk 2 is here',
  isNewer: true,
  isMajorUpgrade: true,
);

const _v1Fix = UpdateCheckResult(
  latestVersion: '1.266.0',
  releaseTag: 'v1.266.0',
  releaseUrl: 'https://github.com/verseles/codewalk/releases/tag/v1.266.0',
  apkUrl: 'https://example.com/v1.266.0/codewalk.apk',
  isNewer: true,
);

/// Scripted updater: [latest] answers the stable path, [v1] the v1-only
/// selector. [latestGate] holds stable answers in flight when set.
class _ScriptedUpdateService extends UpdateCheckService {
  UpdateCheckResult? latest;
  UpdateCheckResult? v1;
  Completer<void>? latestGate;
  int latestCalls = 0;
  int v1Calls = 0;

  @override
  Future<UpdateCheckResult?> check(
    String currentVersion, {
    bool ignoreCooldown = false,
  }) async {
    latestCalls += 1;
    final answer = latest;
    final gate = latestGate;
    if (gate != null) await gate.future;
    return answer;
  }

  @override
  Future<UpdateCheckResult?> checkV1Only(
    String currentVersion, {
    bool ignoreCooldown = false,
  }) async {
    v1Calls += 1;
    return v1;
  }

  @override
  void clearCache() {}
}

/// Holds clearMajorUpdateReminder while [hold] is pending.
class _HeldReminderClear extends InMemoryAppLocalDataSource {
  Completer<void>? hold;

  @override
  Future<void> clearMajorUpdateReminder() async {
    await hold?.future;
    await super.clearMajorUpdateReminder();
  }
}

class _Harness {
  _Harness(this.local, this.service, this.provider);

  final InMemoryAppLocalDataSource local;
  final _ScriptedUpdateService service;
  final SettingsProvider provider;
  final processCalls = <List<String>>[];
  final processEnvironments = <Map<String, String>?>[];
  final launchedUrls = <Uri>[];
  DateTime now = DateTime.utc(2026, 10, 22, 12);
}

Future<_Harness> _harness({
  InMemoryAppLocalDataSource? local,
  _ScriptedUpdateService? service,
}) async {
  final dataSource =
      local ??
      (InMemoryAppLocalDataSource()
        ..experienceSettingsJson = jsonEncode({'checkUpdatesOnOpen': false}));
  final updates = service ?? _ScriptedUpdateService();
  late final _Harness harness;
  final provider = SettingsProvider(
    localDataSource: dataSource,
    dioClient: ReleaseHistoryNoopDioClient(),
    soundService: SoundService(),
    updateCheckService: updates,
    clock: () => harness.now,
    updateProcessRunner: (executable, arguments, {environment}) async {
      harness.processCalls.add(<String>[executable, ...arguments]);
      harness.processEnvironments.add(environment);
      return ProcessResult(0, 0, '', '');
    },
    externalUrlLauncher: (uri) async {
      harness.launchedUrls.add(uri);
      return true;
    },
  );
  harness = _Harness(dataSource, updates, provider);
  addTearDown(provider.dispose);
  await provider.initialize();
  return harness;
}

/// The environment the Linux installer receives for [tag].
Map<String, String> _handoff(
  String tag, {
  String channel = 'stable',
  String migration = 'none',
}) => <String, String>{
  'CODEWALK_UPDATE_CONTRACT': '1',
  'CODEWALK_CHANNEL': channel,
  'CODEWALK_VERSION': tag,
  'CODEWALK_MIGRATION': migration,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    PackageInfo.setMockInitialValues(
      appName: 'CodeWalk',
      packageName: 'com.verseles.codewalk',
      version: '1.265.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('a 1.x to 1.y update keeps the ordinary prompt', () async {
    final h = await _harness();
    h.service.latest = _v1Fix;
    await h.provider.debugRunStartupUpdateCheck();

    expect(h.provider.updateCheckResult, same(_v1Fix));
    expect(h.provider.pendingStartupUpdateToast, isTrue);
    expect(h.provider.majorUpdateCandidate, isNull);
    expect(h.provider.pendingStartupMajorUpdateGate, isFalse);
    expect(h.provider.canInstallUpdateDirectly(), isTrue);
    expect(h.service.v1Calls, 0);

    await h.provider.dismissUpdate('1.266.0');
    expect(h.provider.updateCheckResult, isNull);
    await h.provider.debugRunStartupUpdateCheck();
    expect(h.provider.updateCheckResult, isNull);
  });

  test(
    'a stable same-major desktop install keeps the installer path',
    () async {
      final h = await _harness();
      h.service.latest = _v1Fix;
      await h.provider.debugRunStartupUpdateCheck();

      await h.provider.startInstall();

      expect(h.processCalls, hasLength(1));
      expect(h.processCalls.single.first, 'sh');
      expect(h.processEnvironments.single, _handoff('v1.266.0'));
      expect(h.launchedUrls, isEmpty);
      expect(h.provider.installState, UpdateInstallState.done);
    },
  );

  test('macOS keeps the unpinned installer for the latest release', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final h = await _harness();
    h.service.latest = _v1Fix;
    await h.provider.debugRunStartupUpdateCheck();

    await h.provider.startInstall();

    expect(h.processCalls.single.first, 'sh');
    expect(h.processEnvironments.single, isNull);
  });

  test(
    'a 1.x to 2.y release opens the gate instead of the toast or card',
    () async {
      final local = InMemoryAppLocalDataSource()
        ..experienceSettingsJson = jsonEncode({'checkUpdatesOnOpen': false})
        // A dismissed ordinary prompt for the same version never hides it.
        ..dismissedUpdateVersion = '2.0.0';
      final h = await _harness(local: local);
      h.service.latest = _v1Fix;
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.updateCheckResult, same(_v1Fix));

      h.service.latest = _v2;
      await h.provider.debugRunStartupUpdateCheck();

      expect(h.provider.majorUpdateCandidate, same(_v2));
      expect(h.provider.pendingStartupMajorUpdateGate, isTrue);
      expect(h.provider.updateCheckResult, isNull);
      expect(h.provider.pendingStartupUpdateToast, isFalse);
      expect(h.provider.latestRelease, isNot(same(_v2)));
      expect(h.provider.hasUnseenNews, isFalse);
      expect(h.provider.debugInstallTarget, isNull);

      // Presented once per candidate.
      h.provider.acknowledgeStartupMajorUpdateGate();
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.pendingStartupMajorUpdateGate, isFalse);
      expect(h.provider.majorUpdateCandidate, same(_v2));
    },
  );

  test(
    'startInstall refuses a major release the gate did not approve',
    () async {
      final h = await _harness();
      h.service.latest = _v2;
      await h.provider.debugRunStartupUpdateCheck();

      await h.provider.startInstall();

      expect(h.processCalls, isEmpty);
      expect(h.launchedUrls, isEmpty);
      expect(h.provider.installState, UpdateInstallState.idle);
      expect(
        await h.provider.approveMajorUpdate(
          const UpdateCheckResult(
            latestVersion: '2.0.1',
            releaseTag: 'v2.0.1',
            isNewer: true,
            isMajorUpgrade: true,
          ),
        ),
        isFalse,
      );
      expect(h.provider.debugInstallTarget, isNull);
      expect(h.launchedUrls, isEmpty);
    },
  );

  test('Linux approval installs exactly the approved CodeWalk 2', () async {
    final h = await _harness();
    h.service.latest = _v2;
    await h.provider.debugRunStartupUpdateCheck();
    final latestCalls = h.service.latestCalls;

    expect(await h.provider.approveMajorUpdate(_v2), isTrue);

    expect(h.processCalls.single.first, 'sh');
    expect(
      h.processEnvironments.single,
      _handoff('v2.0.0', migration: 'accept-v2'),
    );
    expect(h.launchedUrls, isEmpty);
    expect(h.provider.installState, UpdateInstallState.done);
    expect(h.service.latestCalls, latestCalls);
  });

  test(
    'macOS approval opens the exact release page instead of the installer',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final h = await _harness();
      h.service.latest = _v2;
      await h.provider.debugRunStartupUpdateCheck();
      final latestCalls = h.service.latestCalls;

      expect(await h.provider.approveMajorUpdate(_v2), isTrue);

      expect(h.processCalls, isEmpty);
      expect(h.launchedUrls, <Uri>[Uri.parse(_v2.releaseUrl!)]);
      expect(h.provider.installState, UpdateInstallState.idle);
      expect(h.service.latestCalls, latestCalls);
      expect(h.provider.pendingStartupMajorUpdateGate, isFalse);
      expect(h.provider.debugInstallTarget, same(_v2));

      // The same tag re-fetched keeps the approved snapshot; a different
      // release drops the approval and asks again.
      h.service.latest = const UpdateCheckResult(
        latestVersion: '2.0.0',
        releaseTag: 'v2.0.0',
        apkUrl: 'https://example.com/other.apk',
        isNewer: true,
        isMajorUpgrade: true,
      );
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.debugInstallTarget, same(_v2));
      h.service.latest = const UpdateCheckResult(
        latestVersion: '2.0.1',
        releaseTag: 'v2.0.1',
        isNewer: true,
        isMajorUpgrade: true,
      );
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.debugInstallTarget, isNull);
      expect(h.provider.pendingStartupMajorUpdateGate, isTrue);
    },
  );

  test(
    'Android approval without an APK fails cleanly without re-querying',
    () async {
      final h = await _harness();
      h.service.latest = const UpdateCheckResult(
        latestVersion: '2.0.0',
        releaseTag: 'v2.0.0',
        releaseUrl: 'https://github.com/verseles/codewalk/releases/tag/v2.0.0',
        isNewer: true,
        isMajorUpgrade: true,
      );
      await h.provider.debugRunStartupUpdateCheck();
      final candidate = h.provider.majorUpdateCandidate!;
      final latestCalls = h.service.latestCalls;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(await h.provider.approveMajorUpdate(candidate), isFalse);
      await h.provider.startInstall();

      expect(h.provider.installState, UpdateInstallState.failed);
      expect(h.service.latestCalls, latestCalls);
      expect(h.service.v1Calls, 0);
      expect(h.launchedUrls, isEmpty);
      expect(h.processCalls, isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    },
  );

  test(
    'Stay offers only CodeWalk 1 until Settings returns to stable',
    () async {
      final h = await _harness();
      h.service
        ..latest = _v2
        ..v1 = _v1Fix;
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.majorUpdateCandidate, same(_v2));
      final latestCalls = h.service.latestCalls;

      await h.provider.stayOnCodeWalk1();

      expect(h.provider.updateChannel, UpdateChannel.v1);
      expect(h.local.updateChannel, 'v1');
      expect(h.provider.majorUpdateCandidate, isNull);
      expect(h.provider.pendingStartupMajorUpdateGate, isFalse);
      expect(h.provider.updateCheckResult, same(_v1Fix));
      expect(h.provider.installState, UpdateInstallState.idle);
      expect(h.service.v1Calls, 1);

      await h.provider.debugRunStartupUpdateCheck();
      await h.provider.checkForUpdate();
      expect(h.service.latestCalls, latestCalls);
      expect(h.service.v1Calls, 3);
      expect(h.provider.majorUpdateCandidate, isNull);

      // CodeWalk-1-only updates install that exact v1 release on Linux and
      // open its release page on the other desktops.
      expect(h.provider.canInstallUpdateDirectly(), isTrue);
      await h.provider.startInstall();
      expect(h.processEnvironments.single, _handoff('v1.266.0', channel: 'v1'));
      expect(h.launchedUrls, isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(h.provider.canInstallUpdateDirectly(), isFalse);
      await h.provider.startInstall();
      expect(h.processCalls, hasLength(1));
      expect(h.launchedUrls, <Uri>[Uri.parse(_v1Fix.releaseUrl!)]);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      // The choice survives a restart.
      final restored = await _harness(local: h.local, service: h.service);
      expect(restored.provider.updateChannel, UpdateChannel.v1);

      await h.provider.setUpdateChannel(UpdateChannel.stable);
      expect(h.local.updateChannel, 'stable');
      expect(h.service.latestCalls, latestCalls + 1);
      expect(h.provider.majorUpdateCandidate, same(_v2));
    },
  );

  test(
    'Later hides the gate until the reminder ends and keeps 1.x fixes',
    () async {
      final h = await _harness();
      h.service
        ..latest = _v2
        ..v1 = _v1Fix;
      await h.provider.debugRunStartupUpdateCheck();

      await h.provider.remindMajorUpdateLater();

      final until = h.now.add(SettingsProvider.majorUpdateRemindInterval);
      expect(h.provider.majorUpdateRemindUntil, until);
      expect(h.local.majorUpdateRemindUntilMs, until.millisecondsSinceEpoch);
      expect(h.local.majorUpdateRemindMajor, 2);
      expect(h.provider.majorUpdateCandidate, isNull);
      expect(h.provider.updateChannel, UpdateChannel.stable);
      expect(h.processCalls, isEmpty);
      expect(h.launchedUrls, isEmpty);

      h.now = until.subtract(const Duration(milliseconds: 1));
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.majorUpdateCandidate, isNull);
      expect(h.provider.pendingStartupMajorUpdateGate, isFalse);
      expect(h.provider.updateCheckResult, same(_v1Fix));
      expect(h.service.v1Calls, 1);

      // The reminder survives a restart.
      final restored = await _harness(local: h.local, service: h.service);
      restored.now = h.now;
      await restored.provider.debugRunStartupUpdateCheck();
      expect(restored.provider.majorUpdateCandidate, isNull);

      h.now = until;
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.majorUpdateCandidate, same(_v2));
      expect(h.provider.pendingStartupMajorUpdateGate, isTrue);
    },
  );

  test(
    'a 1.x fix offered during Later installs exactly that fix on Linux',
    () async {
      final h = await _harness();
      h.service
        ..latest = _v2
        ..v1 = _v1Fix;
      await h.provider.debugRunStartupUpdateCheck();
      await h.provider.remindMajorUpdateLater();
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.updateCheckResult, same(_v1Fix));
      expect(h.provider.updateChannel, UpdateChannel.stable);

      // /releases/latest is CodeWalk 2 here, so the installer gets the fix's
      // exact tag; the unpinned Windows and macOS installers would take
      // CodeWalk 2, so they open its page.
      await h.provider.startInstall();
      expect(h.processEnvironments.single, _handoff('v1.266.0'));
      expect(h.launchedUrls, isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(h.provider.canInstallUpdateDirectly(), isFalse);
      await h.provider.startInstall();
      expect(h.processCalls, hasLength(1));
      expect(h.launchedUrls, <Uri>[Uri.parse(_v1Fix.releaseUrl!)]);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    },
  );

  test('an approved major opens its page where nothing installs', () async {
    final h = await _harness();
    h.service.latest = _v2;
    await h.provider.debugRunStartupUpdateCheck();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(await h.provider.approveMajorUpdate(_v2), isTrue);

    expect(h.processCalls, isEmpty);
    expect(h.launchedUrls, <Uri>[Uri.parse(_v2.releaseUrl!)]);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });

  test(
    'an approval dropped while it is being saved installs nothing',
    () async {
      final local = _HeldReminderClear()
        ..experienceSettingsJson = jsonEncode({'checkUpdatesOnOpen': false});
      final h = await _harness(local: local);
      h.service.latest = _v2;
      await h.provider.debugRunStartupUpdateCheck();
      local.hold = Completer<void>();

      final approval = h.provider.approveMajorUpdate(_v2);
      // The release is gone by the next check: the gate and approval close.
      h.service.latest = _v1Fix;
      await h.provider.debugRunStartupUpdateCheck();
      expect(h.provider.updateCheckResult, same(_v1Fix));
      local.hold!.complete();

      expect(await approval, isFalse);
      expect(h.processCalls, isEmpty);
      expect(h.launchedUrls, isEmpty);
    },
  );

  test('Later applies only to the major it was chosen for', () async {
    final h = await _harness();
    h.service.latest = _v2;
    await h.provider.debugRunStartupUpdateCheck();
    await h.provider.remindMajorUpdateLater();

    h.service.latest = const UpdateCheckResult(
      latestVersion: '3.0.0',
      releaseTag: 'v3.0.0',
      isNewer: true,
      isMajorUpgrade: true,
    );
    await h.provider.debugRunStartupUpdateCheck();

    expect(h.provider.majorUpdateCandidate?.releaseTag, 'v3.0.0');
  });

  test('a manual check bypasses an active reminder', () async {
    final h = await _harness();
    h.service.latest = _v2;
    await h.provider.debugRunStartupUpdateCheck();
    await h.provider.remindMajorUpdateLater();
    expect(h.provider.majorUpdateCandidate, isNull);

    expect(await h.provider.checkForUpdate(), isTrue);

    expect(h.provider.majorUpdateCandidate, same(_v2));
    expect(h.provider.updateCheckResult, isNull);
    expect(h.provider.lastCheckFoundNoUpdate, isFalse);
    expect(h.provider.checkingForUpdate, isFalse);
  });

  test('a stale in-flight result is ignored after Stay', () async {
    final h = await _harness();
    final gate = Completer<void>();
    h.service
      ..latest = _v2
      ..v1 = _v1Fix
      ..latestGate = gate;
    final staleCheck = h.provider.debugRunStartupUpdateCheck();
    await Future<void>.delayed(Duration.zero);
    expect(h.service.latestCalls, 1);

    await h.provider.stayOnCodeWalk1();
    gate.complete();
    await staleCheck;

    expect(h.provider.updateChannel, UpdateChannel.v1);
    expect(h.provider.majorUpdateCandidate, isNull);
    expect(h.provider.pendingStartupMajorUpdateGate, isFalse);
    expect(h.provider.updateCheckResult, same(_v1Fix));
  });

  test('reset clears the update channel policy', () async {
    final h = await _harness();
    h.service.latest = _v2;
    await h.provider.debugRunStartupUpdateCheck();
    await h.provider.remindMajorUpdateLater();
    await h.provider.stayOnCodeWalk1();
    await h.local.saveMajorUpdateReminder(untilMs: 1, major: 2);

    await h.local.clearAll();
    await h.provider.resetToDefaults();

    expect(h.local.updateChannel, isNull);
    expect(h.local.majorUpdateRemindUntilMs, isNull);
    expect(h.local.majorUpdateRemindMajor, isNull);
    expect(h.provider.updateChannel, UpdateChannel.stable);
    expect(h.provider.majorUpdateRemindUntil, isNull);
    expect(h.provider.majorUpdateCandidate, isNull);
  });

  test('the Later interval honours the debug override only in debug', () {
    expect(
      SettingsProvider.resolveMajorUpdateRemindInterval(
        debugMode: false,
        overrideSeconds: 30,
      ),
      const Duration(days: 7),
    );
    expect(
      SettingsProvider.resolveMajorUpdateRemindInterval(
        debugMode: true,
        overrideSeconds: 30,
      ),
      const Duration(seconds: 30),
    );
    expect(
      SettingsProvider.resolveMajorUpdateRemindInterval(
        debugMode: true,
        overrideSeconds: 0,
      ),
      const Duration(days: 7),
    );
  });
}
