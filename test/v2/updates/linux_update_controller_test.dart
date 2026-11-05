import 'dart:async';

import 'package:codewalk/features/settings/linux_update_controller.dart';
import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/releases/app_version.dart';
import 'package:codewalk/shared/releases/linux_update.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'release_announcements_controller_test.dart' show Source;

class Installer implements LinuxUpdateInstaller {
  bool supported = true;
  int installs = 0;
  final completion = Completer<void>();
  final events = <String>[];
  @override
  Future<bool> available() async => supported;
  @override
  Future<void> install(
    UpdateCandidate candidate, {
    required void Function(LinuxUpdateStatus, double) onProgress,
  }) async {
    installs++;
    onProgress(LinuxUpdateStatus.installing, 1);
    await completion.future;
  }

  @override
  Future<bool> restart() async {
    events.add('spawn');
    return true;
  }

  @override
  void close() {}
}

void main() {
  final candidate = UpdateCandidate(
    tag: 'v2.0.0-beta.7',
    version: AppVersion.tryParse('2.0.0-beta.7')!,
    assetUrl: Uri.parse(
      'https://github.com/verseles/codewalk/releases/download/v2.0.0-beta.7/codewalk-linux-x64.tar.gz',
    ),
  );
  test(
    'changing to stable clears failed beta activity and retry target',
    () async {
      final checks = UpdateCheckController(
        source: Source(),
        store: V2MetadataStore(backend: FakeMetadataBackend()),
        installedVersion: () async => '2.0.0-beta.1',
        target: UpdateTarget.linuxX64,
      );
      await checks.setChannel(UpdateChannel.beta);
      final controller = LinuxUpdateController(
        Installer()..supported = false,
        checks: checks,
      );
      addTearDown(() {
        controller.dispose();
        checks.dispose();
      });
      await controller.install(candidate);
      expect(controller.status, LinuxUpdateStatus.failed);
      await checks.setChannel(UpdateChannel.stable);
      expect(controller.status, LinuxUpdateStatus.idle);
      expect(controller.candidate, isNull);
      expect(controller.failure, isNull);
    },
  );
  test('one installer runs and drafts flush before spawn and exit', () async {
    final installer = Installer();
    final controller = LinuxUpdateController(
      installer,
      beforeRestart: () async => installer.events.add('flush'),
      afterRestart: () async => installer.events.add('exit'),
    );
    addTearDown(controller.dispose);
    final first = controller.install(candidate);
    await pumpEventQueue();
    await controller.install(candidate);
    expect(installer.installs, 1);
    expect(await controller.restart(), isFalse);
    installer.completion.complete();
    await first;
    expect(controller.status, LinuxUpdateStatus.ready);
    expect(await controller.restart(), isTrue);
    expect(installer.events, ['flush', 'spawn', 'exit']);
  });
  test('unsupported installation never starts a process', () async {
    final installer = Installer()..supported = false;
    final controller = LinuxUpdateController(installer);
    addTearDown(controller.dispose);
    await controller.install(candidate);
    expect(installer.installs, 0);
    expect(controller.failure, LinuxUpdateFailure.unavailable);
  });
}
