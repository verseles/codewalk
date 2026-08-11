import 'dart:io';

import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repositoryRoot = Directory.current;
  final installScript = File('${repositoryRoot.path}/install.sh');
  final uninstallScript = File('${repositoryRoot.path}/uninstall.sh');

  Future<ProcessResult> sourceScript(
    File script,
    String command, {
    required Directory home,
    required Directory dataHome,
    required String sourceOnlyVariable,
    Map<String, String> extraEnvironment = const <String, String>{},
  }) {
    return Process.run(
      'sh',
      <String>['-c', '. "\$1"; $command', 'codewalk-test', script.path],
      environment: <String, String>{
        ...Platform.environment,
        'HOME': home.path,
        'XDG_DATA_HOME': dataHome.path,
        sourceOnlyVariable: '1',
        ...extraEnvironment,
      },
    );
  }

  group('Linux installer data preservation', () {
    late Directory root;
    late Directory home;
    late Directory dataHome;

    setUp(() {
      root = Directory.systemTemp.createTempSync('codewalk_installer_test_');
      home = Directory('${root.path}/home')..createSync(recursive: true);
      dataHome = Directory('${root.path}/xdg data')
        ..createSync(recursive: true);
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('scripts support source-only syntax validation', () async {
      expect(
        installScript.readAsStringSync(),
        contains('CODEWALK_INSTALLER_SOURCE_ONLY'),
      );
      expect(
        uninstallScript.readAsStringSync(),
        contains('CODEWALK_UNINSTALLER_SOURCE_ONLY'),
      );

      final installSyntax = await Process.run('sh', <String>[
        '-n',
        installScript.path,
      ]);
      final uninstallSyntax = await Process.run('sh', <String>[
        '-n',
        uninstallScript.path,
      ]);

      expect(installSyntax.exitCode, 0, reason: '${installSyntax.stderr}');
      expect(uninstallSyntax.exitCode, 0, reason: '${uninstallSyntax.stderr}');
    });

    test('Linux bundle path is separate from legacy user data', () async {
      expect(
        installScript.readAsStringSync(),
        contains('CODEWALK_INSTALLER_SOURCE_ONLY'),
      );

      final result = await sourceScript(
        installScript,
        'platform=linux; configure_install_paths; '
        'printf "%s\\n%s\\n" "\$INSTALL_DIR" '
        '"\$LEGACY_INSTALL_DIR"',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect((result.stdout as String).trim().split('\n'), <String>[
        '${dataHome.path}/codewalk-app',
        '${dataHome.path}/codewalk',
      ]);
    });

    test('macOS keeps the existing installer staging path', () async {
      final result = await sourceScript(
        installScript,
        'platform=macos; configure_install_paths; printf "%s" "\$INSTALL_DIR"',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect((result.stdout as String).trim(), '${dataHome.path}/codewalk');
    });

    test('Linux restart falls back to the installer symlink', () {
      final legacyExecutable = '${dataHome.path}/codewalk/codewalk';
      final installerLink = '${home.path}/.local/bin/codewalk';

      expect(
        resolveDesktopRestartExecutable(
          targetPlatform: TargetPlatform.linux,
          resolvedExecutable: legacyExecutable,
          environment: <String, String>{'HOME': home.path},
          fileExists: (path) => path == installerLink,
        ),
        installerLink,
      );
      expect(
        resolveDesktopRestartExecutable(
          targetPlatform: TargetPlatform.linux,
          resolvedExecutable: legacyExecutable,
          environment: <String, String>{'HOME': home.path},
          fileExists: (path) => path == legacyExecutable,
        ),
        legacyExecutable,
      );
    });

    test('installer cleanup removes only legacy bundle entries', () async {
      expect(
        installScript.readAsStringSync(),
        contains('CODEWALK_INSTALLER_SOURCE_ONLY'),
      );

      final legacy = Directory('${dataHome.path}/codewalk')
        ..createSync(recursive: true);
      File('${legacy.path}/codewalk').writeAsStringSync('binary');
      File('${legacy.path}/.installed-version').writeAsStringSync('v1');
      for (final name in <String>['bin', 'data', 'lib']) {
        final directory = Directory('${legacy.path}/$name')
          ..createSync(recursive: true);
        File('${directory.path}/bundle').writeAsStringSync(name);
      }
      File('${legacy.path}/shared_preferences.json').writeAsStringSync('{}');
      final cache = Directory('${legacy.path}/chat_cache_v1')
        ..createSync(recursive: true);
      File('${cache.path}/payload.json').writeAsStringSync('{}');
      File('${legacy.path}/.custom-state').writeAsStringSync('keep');

      final result = await sourceScript(
        installScript,
        'platform=linux; configure_install_paths; '
        'cleanup_legacy_linux_bundle',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(File('${legacy.path}/codewalk').existsSync(), isFalse);
      expect(File('${legacy.path}/.installed-version').existsSync(), isFalse);
      expect(Directory('${legacy.path}/bin').existsSync(), isFalse);
      expect(Directory('${legacy.path}/data').existsSync(), isFalse);
      expect(Directory('${legacy.path}/lib').existsSync(), isFalse);
      expect(
        File('${legacy.path}/shared_preferences.json').existsSync(),
        isTrue,
      );
      expect(Directory('${legacy.path}/chat_cache_v1').existsSync(), isTrue);
      expect(File('${legacy.path}/.custom-state').existsSync(), isTrue);
    });

    test('Linux update replaces bundle and preserves legacy data', () async {
      expect(
        installScript.readAsStringSync(),
        contains('CODEWALK_INSTALLER_SOURCE_ONLY'),
      );

      final archiveRoot = Directory('${root.path}/archive')
        ..createSync(recursive: true);
      final binary = File('${archiveRoot.path}/codewalk')
        ..writeAsStringSync('#!/usr/bin/env sh\nexit 0\n');
      final chmod = await Process.run('chmod', <String>['+x', binary.path]);
      expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
      final archiveData = Directory('${archiveRoot.path}/data')
        ..createSync(recursive: true);
      File(
        '${archiveData.path}/com.verseles.codewalk.png',
      ).writeAsStringSync('icon');
      File('${archiveData.path}/icudtl.dat').writeAsStringSync('icu');
      final flutterAssets = Directory('${archiveData.path}/flutter_assets')
        ..createSync(recursive: true);
      File(
        '${flutterAssets.path}/AssetManifest.bin',
      ).writeAsStringSync('assets');
      final archiveLib = Directory('${archiveRoot.path}/lib')
        ..createSync(recursive: true);
      File(
        '${archiveLib.path}/libflutter_linux_gtk.so',
      ).writeAsStringSync('runtime');
      File('${archiveLib.path}/libapp.so').writeAsStringSync('application');
      final archive = File('${root.path}/fixture.tar.gz');
      final tar = await Process.run('tar', <String>[
        '-czf',
        archive.path,
        '-C',
        archiveRoot.path,
        '.',
      ]);
      expect(tar.exitCode, 0, reason: '${tar.stderr}');

      final legacy = Directory('${dataHome.path}/codewalk')
        ..createSync(recursive: true);
      File('${legacy.path}/codewalk').writeAsStringSync('old binary');
      File('${legacy.path}/.installed-version').writeAsStringSync('v1');
      for (final name in <String>['data', 'lib']) {
        final directory = Directory('${legacy.path}/$name')
          ..createSync(recursive: true);
        File('${directory.path}/old').writeAsStringSync(name);
      }
      File('${legacy.path}/shared_preferences.json').writeAsStringSync('{}');
      final cache = Directory('${legacy.path}/chat_cache_v1')
        ..createSync(recursive: true);
      File('${cache.path}/payload.json').writeAsStringSync('{}');
      final previousInstall = Directory('${dataHome.path}/codewalk-app')
        ..createSync(recursive: true);
      File('${previousInstall.path}/codewalk').writeAsStringSync('old app');
      File('${previousInstall.path}/obsolete').writeAsStringSync('remove');

      final result = await sourceScript(
        installScript,
        'fetch() { cat "\$CODEWALK_TEST_ASSET"; }; '
        'platform=linux; configure_install_paths; '
        'version=v2; asset=fixture.tar.gz; REPO=test/repo; '
        'download_and_install',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
        extraEnvironment: <String, String>{'CODEWALK_TEST_ASSET': archive.path},
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final installed = Directory('${dataHome.path}/codewalk-app');
      expect(File('${installed.path}/codewalk').existsSync(), isTrue);
      expect(
        File('${installed.path}/codewalk').readAsStringSync(),
        startsWith('#!/usr/bin/env sh'),
      );
      expect(File('${installed.path}/obsolete').existsSync(), isFalse);
      expect(
        File('${installed.path}/data/com.verseles.codewalk.png').existsSync(),
        isTrue,
      );
      expect(
        File('${installed.path}/.installed-version').readAsStringSync().trim(),
        'v2',
      );
      expect(
        Link('${home.path}/.local/bin/codewalk').targetSync(),
        '${installed.path}/codewalk',
      );
      expect(File('${legacy.path}/codewalk').existsSync(), isFalse);
      expect(Directory('${legacy.path}/data').existsSync(), isFalse);
      expect(Directory('${legacy.path}/lib').existsSync(), isFalse);
      expect(
        File('${legacy.path}/shared_preferences.json').existsSync(),
        isTrue,
      );
      expect(Directory('${legacy.path}/chat_cache_v1').existsSync(), isTrue);
      expect(
        dataHome.listSync().where(
          (entry) =>
              entry.path.contains('codewalk-app.staged-') ||
              entry.path.contains('codewalk-app.backup-'),
        ),
        isEmpty,
      );
    });

    test('invalid Linux archive leaves existing bundles untouched', () async {
      final archiveRoot = Directory('${root.path}/invalid-archive')
        ..createSync(recursive: true);
      final binary = File('${archiveRoot.path}/codewalk')
        ..writeAsStringSync('#!/usr/bin/env sh\nexit 0\n');
      final chmod = await Process.run('chmod', <String>['+x', binary.path]);
      expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
      final archiveData = Directory('${archiveRoot.path}/data')
        ..createSync(recursive: true);
      File(
        '${archiveData.path}/com.verseles.codewalk.png',
      ).writeAsStringSync('icon');
      File('${archiveData.path}/icudtl.dat').writeAsStringSync('icu');
      final invalidAssets = Directory('${archiveData.path}/flutter_assets')
        ..createSync(recursive: true);
      File(
        '${invalidAssets.path}/AssetManifest.bin',
      ).writeAsStringSync('assets');
      final invalidLib = Directory('${archiveRoot.path}/lib')
        ..createSync(recursive: true);
      File(
        '${invalidLib.path}/libflutter_linux_gtk.so',
      ).writeAsStringSync('runtime');
      final archive = File('${root.path}/invalid-fixture.tar.gz');
      final tar = await Process.run('tar', <String>[
        '-czf',
        archive.path,
        '-C',
        archiveRoot.path,
        '.',
      ]);
      expect(tar.exitCode, 0, reason: '${tar.stderr}');

      final installed = Directory('${dataHome.path}/codewalk-app')
        ..createSync(recursive: true);
      File('${installed.path}/codewalk').writeAsStringSync('current binary');
      final legacy = Directory('${dataHome.path}/codewalk')
        ..createSync(recursive: true);
      File('${legacy.path}/codewalk').writeAsStringSync('legacy binary');
      File('${legacy.path}/shared_preferences.json').writeAsStringSync('{}');

      final result = await sourceScript(
        installScript,
        'fetch() { cat "\$CODEWALK_TEST_ASSET"; }; '
        'platform=linux; configure_install_paths; '
        'version=v2; asset=invalid-fixture.tar.gz; REPO=test/repo; '
        'download_and_install',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
        extraEnvironment: <String, String>{'CODEWALK_TEST_ASSET': archive.path},
      );

      expect(result.exitCode, isNot(0));
      expect(
        File('${installed.path}/codewalk').readAsStringSync(),
        'current binary',
      );
      expect(
        File('${legacy.path}/codewalk').readAsStringSync(),
        'legacy binary',
      );
      expect(
        File('${legacy.path}/shared_preferences.json').existsSync(),
        isTrue,
      );
    });

    test('post-activation failure restores the previous bundle', () async {
      final archiveRoot = Directory('${root.path}/rollback-archive')
        ..createSync(recursive: true);
      final binary = File('${archiveRoot.path}/codewalk')
        ..writeAsStringSync('#!/usr/bin/env sh\nexit 0\n');
      final chmod = await Process.run('chmod', <String>['+x', binary.path]);
      expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
      final archiveData = Directory('${archiveRoot.path}/data')
        ..createSync(recursive: true);
      File(
        '${archiveData.path}/com.verseles.codewalk.png',
      ).writeAsStringSync('icon');
      File('${archiveData.path}/icudtl.dat').writeAsStringSync('icu');
      final rollbackAssets = Directory('${archiveData.path}/flutter_assets')
        ..createSync(recursive: true);
      File(
        '${rollbackAssets.path}/AssetManifest.bin',
      ).writeAsStringSync('assets');
      final archiveLib = Directory('${archiveRoot.path}/lib')
        ..createSync(recursive: true);
      File(
        '${archiveLib.path}/libflutter_linux_gtk.so',
      ).writeAsStringSync('runtime');
      File('${archiveLib.path}/libapp.so').writeAsStringSync('application');
      final archive = File('${root.path}/rollback-fixture.tar.gz');
      final tar = await Process.run('tar', <String>[
        '-czf',
        archive.path,
        '-C',
        archiveRoot.path,
        '.',
      ]);
      expect(tar.exitCode, 0, reason: '${tar.stderr}');

      final installed = Directory('${dataHome.path}/codewalk-app')
        ..createSync(recursive: true);
      File('${installed.path}/codewalk').writeAsStringSync('current binary');
      final legacy = Directory('${dataHome.path}/codewalk')
        ..createSync(recursive: true);
      File('${legacy.path}/codewalk').writeAsStringSync('legacy binary');
      File('${legacy.path}/shared_preferences.json').writeAsStringSync('{}');

      final result = await sourceScript(
        installScript,
        'fetch() { cat "\$CODEWALK_TEST_ASSET"; }; '
        'ln() { return 1; }; '
        'platform=linux; configure_install_paths; '
        'version=v2; asset=rollback-fixture.tar.gz; REPO=test/repo; '
        'download_and_install',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
        extraEnvironment: <String, String>{'CODEWALK_TEST_ASSET': archive.path},
      );

      expect(result.exitCode, isNot(0));
      expect(
        File('${installed.path}/codewalk').readAsStringSync(),
        'current binary',
      );
      expect(
        File('${legacy.path}/codewalk').readAsStringSync(),
        'legacy binary',
      );
      expect(
        File('${legacy.path}/shared_preferences.json').existsSync(),
        isTrue,
      );
      expect(
        dataHome.listSync().where(
          (entry) =>
              entry.path.contains('codewalk-app.staged-') ||
              entry.path.contains('codewalk-app.backup-'),
        ),
        isEmpty,
      );
    });

    test(
      'termination during activation restores the previous bundle',
      () async {
        final result = await sourceScript(
          installScript,
          'platform=linux; configure_install_paths; '
          'tmp="\$XDG_DATA_HOME/signal-tmp"; '
          'staged_install_dir="\${INSTALL_DIR}.staged-test"; '
          'backup_install_dir="\${INSTALL_DIR}.backup-test"; '
          'install_succeeded=0; '
          'mkdir -p "\$tmp" "\$staged_install_dir" "\$INSTALL_DIR"; '
          'printf current > "\$INSTALL_DIR/codewalk"; '
          'mv "\$INSTALL_DIR" "\$backup_install_dir"; '
          'trap cleanup_install_attempt EXIT; '
          'trap "exit 143" TERM; '
          'kill -TERM \$\$',
          home: home,
          dataHome: dataHome,
          sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
        );

        expect(result.exitCode, 143, reason: '${result.stderr}');
        expect(
          File('${dataHome.path}/codewalk-app/codewalk').readAsStringSync(),
          'current',
        );
        expect(
          dataHome.listSync().where(
            (entry) =>
                entry.path.contains('codewalk-app.staged-') ||
                entry.path.contains('codewalk-app.backup-'),
          ),
          isEmpty,
        );
      },
    );

    test('uninstaller preserves both supported Linux data roots', () async {
      expect(
        uninstallScript.readAsStringSync(),
        contains('CODEWALK_UNINSTALLER_SOURCE_ONLY'),
      );

      final legacy = Directory('${dataHome.path}/codewalk')
        ..createSync(recursive: true);
      File('${legacy.path}/codewalk').writeAsStringSync('binary');
      File('${legacy.path}/shared_preferences.json').writeAsStringSync('{}');
      final currentData = Directory('${dataHome.path}/com.verseles.codewalk')
        ..createSync(recursive: true);
      File(
        '${currentData.path}/shared_preferences.json',
      ).writeAsStringSync('{}');

      final result = await sourceScript(
        uninstallScript,
        'main',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_UNINSTALLER_SOURCE_ONLY',
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(File('${legacy.path}/codewalk').existsSync(), isFalse);
      expect(
        File('${legacy.path}/shared_preferences.json').existsSync(),
        isTrue,
      );
      expect(
        File('${currentData.path}/shared_preferences.json').existsSync(),
        isTrue,
      );
    });

    test('uninstaller succeeds when no artifacts exist', () async {
      final result = await sourceScript(
        uninstallScript,
        'main',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_UNINSTALLER_SOURCE_ONLY',
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        result.stdout,
        contains('No CodeWalk installation artifacts found.'),
      );
    });
  }, skip: !Platform.isLinux);
}
