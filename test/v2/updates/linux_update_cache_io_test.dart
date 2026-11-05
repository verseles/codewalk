import 'dart:io';

import 'package:codewalk/platform/releases/apk_file_store_io.dart';
import 'package:codewalk/platform/releases/linux_installer_io.dart';
import 'package:codewalk/platform/releases/linux_update_cache_io.dart';
import 'package:codewalk/shared/releases/apk_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('cw-private-cache-');
  });
  tearDown(() async => temporary.delete(recursive: true));

  test('cache is private and only stale owned partials are removed', () async {
    final root = await prepareLinuxUpdateCache(
      Directory('${temporary.path}/cache'),
    );
    expect(root.statSync().mode & 0x1ff, 0x1c0);
    final path = await linuxUpdatePartPath(
      root,
      'v2.0.0-beta.6',
      'asset.tar.gz',
    );
    final recent = File(path);
    await recent.writeAsString('resume me');
    final stale = File('$path.json');
    await stale.writeAsString('stale');
    await stale.setLastModified(
      DateTime.now().subtract(const Duration(days: 2)),
    );
    final unrelated = File('${root.path}/keep.txt');
    await unrelated.writeAsString('keep');
    await unrelated.setLastModified(
      DateTime.now().subtract(const Duration(days: 2)),
    );
    await prepareLinuxUpdateCache(root);
    expect(await recent.readAsString(), 'resume me');
    expect(stale.existsSync(), isFalse);
    expect(await unrelated.readAsString(), 'keep');
  });

  test(
    'orphan installer cleanup preserves links, recent work and unrelated data',
    () async {
      final root = await prepareLinuxUpdateCache(
        Directory('${temporary.path}/cache'),
      );
      final external = File('${temporary.path}/preserve');
      await external.writeAsString('external');
      final orphan = Directory('${root.path}/codewalk-install-123');
      await orphan.create();
      await File('${orphan.path}/archive.tar.gz').writeAsString('interrupted');
      await Link('${orphan.path}/external-link').create(external.path);
      final recent = Directory('${root.path}/codewalk-install-456');
      await recent.create();
      final unrelated = Directory('${root.path}/codewalk-install-manual');
      await unrelated.create();
      // Touch only the owned directory's mtime, keeping files irrelevant to age.
      await Process.run('/usr/bin/touch', [
        '-d',
        '2 days ago',
        orphan.path,
        unrelated.path,
      ]);
      await Link('${root.path}/codewalk-install-789').create(temporary.path);
      await prepareLinuxUpdateCache(root);
      expect(orphan.existsSync(), isFalse);
      expect(recent.existsSync(), isTrue);
      expect(unrelated.existsSync(), isTrue);
      expect(await external.readAsString(), 'external');
      expect(Link('${root.path}/codewalk-install-789').existsSync(), isTrue);
    },
  );

  test('cache and release-directory links cannot redirect writes', () async {
    final victim = Directory('${temporary.path}/victim');
    await victim.create();
    final rootLink = Link('${temporary.path}/linked-cache');
    await rootLink.create(victim.path);
    await expectLater(
      prepareLinuxUpdateCache(Directory(rootLink.path)),
      throwsA(isA<FileSystemException>()),
    );
    final root = await prepareLinuxUpdateCache(
      Directory('${temporary.path}/cache'),
    );
    await Link('${root.path}/v2.0.0-beta.6').create(victim.path);
    await expectLater(
      linuxUpdatePartPath(root, 'v2.0.0-beta.6', 'asset.tar.gz'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await victim.list().isEmpty, isTrue);
  });

  test(
    'installer subprocess uses private TMPDIR instead of public parent temporary',
    () async {
      final root = await prepareLinuxUpdateCache(
        Directory('${temporary.path}/cache'),
      );
      final environment = linuxInstallerEnvironment({
        ...Platform.environment,
        'TMPDIR': '/tmp/public-updates',
        'CODEWALK_LOCAL_ARCHIVE': 'untrusted',
      }, temporary: root.path);
      final process = await Process.run(
        '/bin/sh',
        ['-c', 'printf "%s" "\$TMPDIR"'],
        environment: environment,
        includeParentEnvironment: false,
      );
      expect(process.exitCode, 0);
      expect(process.stdout, root.path);
      expect(environment.containsKey('CODEWALK_LOCAL_ARCHIVE'), isFalse);
    },
  );

  test('final rename failure is reported as storage', () async {
    final store = ApkFileStoreIo(
      temporaryDirectory: () async => temporary.path,
    );
    await expectLater(
      store.rename('${temporary.path}/missing', '${temporary.path}/final.apk'),
      throwsA(
        isA<ApkDownloadException>().having(
          (e) => e.failure,
          'failure',
          ApkUpdateFailure.storage,
        ),
      ),
    );
  });

  for (final rootLink in [false, true]) {
    test(
      'APK cleanup cannot traverse a ${rootLink ? 'root' : 'child'} link',
      () async {
        final victim = Directory('${temporary.path}/victim');
        await victim.create();
        final protected = File('${victim.path}/old.apk');
        await protected.writeAsString('preserve');
        await protected.setLastModified(
          DateTime.now().subtract(const Duration(days: 2)),
        );
        final updates = '${temporary.path}/updates';
        if (rootLink) {
          await Link(updates).create(victim.path);
        } else {
          await Directory(updates).create();
          await Link('$updates/linked').create(victim.path);
          final owned = File('$updates/owned.part');
          await owned.writeAsString('stale');
          await owned.setLastModified(
            DateTime.now().subtract(const Duration(days: 2)),
          );
        }
        final store = ApkFileStoreIo(
          temporaryDirectory: () async => temporary.path,
        );
        await store.cleanupStale();
        expect(await protected.readAsString(), 'preserve');
        if (!rootLink) {
          expect(File('$updates/owned.part').existsSync(), isFalse);
        }
      },
    );
  }

  test(
    'detached relaunch preserves desktop locale and display credentials',
    () async {
      final output = '${temporary.path}/environment';
      final marker = '${temporary.path}/complete';
      final launcher = File('${temporary.path}/launcher');
      await launcher.writeAsString(
        '#!/bin/sh\nprintf "%s\\n%s\\n" "\$LANG" "\$XAUTHORITY" > "$output"\nmkdir "$marker"\n',
      );
      expect(
        (await Process.run('/bin/chmod', ['700', launcher.path])).exitCode,
        0,
      );
      final completed = temporary
          .watch()
          .firstWhere((event) => event.path == marker)
          .timeout(const Duration(seconds: 5));
      await launchUpdatedLinuxApp(launcher.path);
      await completed;
      final values = await File(output).readAsLines();
      expect(values, [
        Platform.environment['LANG'] ?? '',
        Platform.environment['XAUTHORITY'] ?? '',
      ]);
    },
  );
}
