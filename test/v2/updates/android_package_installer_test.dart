import 'dart:async';
import 'dart:io';

import 'package:codewalk/platform/releases/apk_installer_io.dart';
import 'package:codewalk/shared/releases/apk_update.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(kApkInstallChannelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'non-Android platform returns noInstaller without calling channel',
    () async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            called = true;
            return 'committed';
          });
      final installer = MethodChannelApkInstaller(
        channel: channel,
        isAndroid: false,
      );
      expect(
        await installer.open(
          '/tmp/update.apk',
          versionCode: 2,
          tag: 'v2.2.1',
          notificationTitle: 'Title',
          notificationBody: 'Body',
          notificationChannel: 'Updates',
        ),
        ApkInstallOutcome.noInstaller,
      );
      await installer.clearPendingMarker();
      expect(called, isFalse);
    },
  );

  test('maps open outcomes, platform exceptions, and status signals', () async {
    MethodCall? lastCall;
    var response = 'committed';
    PlatformException? throwError;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          lastCall = call;
          if (throwError case final err?) throw err;
          if (call.method == 'clearPendingMarker') return null;
          return response;
        });

    final installer = MethodChannelApkInstaller(
      channel: channel,
      isAndroid: true,
    );

    expect(
      await installer.open(
        '/data/user/0/com.verseles.codewalk/no_backup/updates/v2.2.1/codewalk-android-arm64.apk',
        versionCode: 42,
        tag: 'v2.2.1',
        notificationTitle: 'CodeWalk updated',
        notificationBody: 'Tap to reopen CodeWalk.',
        notificationChannel: 'Version and updates',
      ),
      ApkInstallOutcome.committed,
    );
    expect(lastCall?.method, 'open');
    expect(lastCall?.arguments, <String, Object?>{
      'path':
          '/data/user/0/com.verseles.codewalk/no_backup/updates/v2.2.1/codewalk-android-arm64.apk',
      'versionCode': 42,
      'tag': 'v2.2.1',
      'notificationTitle': 'CodeWalk updated',
      'notificationBody': 'Tap to reopen CodeWalk.',
      'notificationChannel': 'Version and updates',
    });

    for (final (raw, expected) in <(String, ApkInstallOutcome)>[
      ('opened', ApkInstallOutcome.opened),
      ('denied', ApkInstallOutcome.denied),
      ('noInstaller', ApkInstallOutcome.noInstaller),
      ('fileMissing', ApkInstallOutcome.fileMissing),
      ('storage', ApkInstallOutcome.storage),
      ('failed', ApkInstallOutcome.failed),
      ('unexpected', ApkInstallOutcome.failed),
    ]) {
      response = raw;
      expect(await installer.open('/tmp/a.apk'), expected);
    }

    throwError = PlatformException(code: 'STORAGE');
    expect(await installer.open('/tmp/a.apk'), ApkInstallOutcome.storage);
    throwError = PlatformException(code: 'DENIED');
    expect(await installer.open('/tmp/a.apk'), ApkInstallOutcome.denied);
    throwError = PlatformException(code: 'FILE_MISSING');
    expect(await installer.open('/tmp/a.apk'), ApkInstallOutcome.fileMissing);
    throwError = PlatformException(code: 'OTHER');
    expect(await installer.open('/tmp/a.apk'), ApkInstallOutcome.failed);
    throwError = null;

    await installer.clearPendingMarker();
    expect(lastCall?.method, 'clearPendingMarker');

    final received = <ApkInstallSignal>[];
    final sub = installer.signals.listen(received.add);
    addTearDown(sub.cancel);

    Future<void> pushSignal(String kind) async {
      const codec = StandardMethodCodec();
      final data = codec.encodeMethodCall(
        MethodCall('status', <String, Object?>{'kind': kind}),
      );
      final completer = Completer<void>();
      unawaited(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              kApkInstallChannelName,
              data,
              (_) => completer.complete(),
            ),
      );
      await completer.future;
      await pumpEventQueue();
    }

    await pushSignal('confirmation');
    await pushSignal('aborted');
    await pushSignal('storage');
    await pushSignal('failed');
    await pushSignal('succeeded');
    await pushSignal('unknown');

    expect(received, <ApkInstallSignal>[
      ApkInstallSignal.confirmation,
      ApkInstallSignal.aborted,
      ApkInstallSignal.storage,
      ApkInstallSignal.failed,
      ApkInstallSignal.succeeded,
    ]);
  });

  test(
    'AndroidManifest declares unattended update permissions and unexported receivers without preview-colliding names',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
      expect(
        manifest,
        contains('android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION'),
      );
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android:name=".ApkInstallStatusReceiver"'));
      expect(manifest, contains('android:name=".SelfUpdateReceiver"'));
      expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
      // Neither custom <permission> nor hardcoded non-interpolated authorities
      // may be added, preserving side-by-side .v2preview installation.
      expect(manifest, isNot(contains('<permission ')));
      expect(
        RegExp(
          'android:authorities="[^"]*',
        ).allMatches(manifest).map((m) => m.group(0)),
        everyElement(contains(r'${applicationId}')),
      );
    },
  );
}
