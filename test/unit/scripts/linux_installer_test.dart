import 'dart:convert';
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

  group('Linux installer release selection', () {
    const apiBase = 'https://api.github.com/repos/test/repo';
    // Serves recorded API responses and the fixture archive; any other URL
    // fails, so no test reaches GitHub. Every request is logged.
    const fetchFixture =
        'fetch() { printf "%s\\n" "\$1" >> "\$CODEWALK_TEST_FETCH_LOG"; '
        'case "\$1" in */releases/download/*) '
        'cat "\$CODEWALK_TEST_ARCHIVE"; return;; esac; '
        'f="\$CODEWALK_TEST_FIXTURES/\$(printf "%s" "\$1" | '
        'tr -c "A-Za-z0-9._-" "_")"; [ -f "\$f" ] || return 22; cat "\$f"; }; ';
    late Directory root;
    late Directory home;
    late Directory dataHome;
    late Directory fixtures;
    late File archive;
    late File fetchLog;

    Map<String, Object?> release(
      String tag, {
      bool draft = false,
      bool prerelease = false,
    }) => <String, Object?>{
      'name': 'CodeWalk $tag "tag_name": "v9.9.9" {',
      'tag_name': tag,
      'body': 'Notes } ] "draft": false, "prerelease": false é',
      'draft': draft,
      'prerelease': prerelease,
      'assets': <Object?>[
        <String, Object?>{'name': 'codewalk-linux-x64.tar.gz', 'draft': true},
      ],
    };

    void serve(String path, Object? body) {
      final key = '$apiBase/$path'.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
      File(
        '${fixtures.path}/$key',
      ).writeAsStringSync(body is String ? body : jsonEncode(body));
    }

    void serveList(int page, List<Map<String, Object?>> releases) =>
        serve('releases?per_page=100&page=$page', releases);

    List<String> fetched() =>
        fetchLog.existsSync() ? fetchLog.readAsLinesSync() : <String>[];

    Iterable<String> downloads() =>
        fetched().where((url) => url.contains('/releases/download/'));

    Directory installed() => Directory('${dataHome.path}/codewalk-app');

    void installExisting(String? version, {String? channel}) {
      final bundle = installed()..createSync(recursive: true);
      File('${bundle.path}/codewalk').writeAsStringSync('old app');
      if (version != null) {
        File('${bundle.path}/.installed-version').writeAsStringSync(version);
      }
      if (channel != null) {
        File('${bundle.path}/.installed-channel').writeAsStringSync(channel);
      }
    }

    Future<ProcessResult> runInstaller({
      String channel = '',
      String version = '',
      String migration = '',
      String contract = '',
    }) {
      return sourceScript(
        installScript,
        '${fetchFixture}main',
        home: home,
        dataHome: dataHome,
        sourceOnlyVariable: 'CODEWALK_INSTALLER_SOURCE_ONLY',
        extraEnvironment: <String, String>{
          'CODEWALK_REPO': 'test/repo',
          'CODEWALK_UPDATE_CONTRACT': contract,
          'CODEWALK_CHANNEL': channel,
          'CODEWALK_VERSION': version,
          'CODEWALK_MIGRATION': migration,
          'CODEWALK_TEST_FIXTURES': fixtures.path,
          'CODEWALK_TEST_ARCHIVE': archive.path,
          'CODEWALK_TEST_FETCH_LOG': fetchLog.path,
        },
      );
    }

    void expectInstalled(ProcessResult result, String tag, String channel) {
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(downloads().single, contains('/releases/download/$tag/'));
      expect(
        File('${installed().path}/.installed-version').readAsStringSync(),
        '$tag\n',
      );
      expect(
        File('${installed().path}/.installed-channel').readAsStringSync(),
        '$channel\n',
      );
    }

    void expectUntouched(ProcessResult result, String message) {
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains(message));
      expect(downloads(), isEmpty);
      expect(
        File('${installed().path}/codewalk').readAsStringSync(),
        'old app',
      );
    }

    setUp(() async {
      root = Directory.systemTemp.createTempSync('codewalk_selection_test_');
      home = Directory('${root.path}/home')..createSync(recursive: true);
      dataHome = Directory('${root.path}/data')..createSync(recursive: true);
      fixtures = Directory('${root.path}/fixtures')..createSync();
      fetchLog = File('${root.path}/fetch.log');
      final bundle = Directory('${root.path}/bundle');
      for (final path in <String>[
        'codewalk',
        'data/com.verseles.codewalk.png',
        'data/icudtl.dat',
        'data/flutter_assets/AssetManifest.bin',
        'lib/libflutter_linux_gtk.so',
        'lib/libapp.so',
      ]) {
        File('${bundle.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync('#!/usr/bin/env sh\nexit 0\n');
      }
      final chmod = await Process.run('chmod', <String>[
        '+x',
        '${bundle.path}/codewalk',
      ]);
      expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
      archive = File('${root.path}/fixture.tar.gz');
      final tar = await Process.run('tar', <String>[
        '-czf',
        archive.path,
        '-C',
        bundle.path,
        '.',
      ]);
      expect(tar.exitCode, 0, reason: '${tar.stderr}');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test(
      'a fresh install takes the stable release and saves the channel',
      () async {
        serve('releases/latest', release('v1.265.1'));

        final result = await runInstaller();

        expectInstalled(result, 'v1.265.1', 'stable');
      },
    );

    test('the v1 channel pages through releases to the highest v1', () async {
      serveList(1, <Map<String, Object?>>[
        for (var minor = 0; minor < 97; minor++) release('v2.$minor.0'),
        release('v1.9.99'),
        release('v1.266.0-native.1', prerelease: true),
        release('v2.0.0-beta.3', prerelease: true),
      ]);
      serveList(2, <Map<String, Object?>>[
        release('v1.10.0'),
        release('v1.266.1'),
        release('v1.267.0', draft: true),
        release('v1.300.0-rc.1'),
        release('1.99.0'),
      ]);
      installExisting('v1.265.1');

      final result = await runInstaller(channel: 'v1');

      expectInstalled(result, 'v1.266.1', 'v1');
      expect(fetched(), contains('$apiBase/releases?per_page=100&page=2'));
    });

    test('a saved v1 choice survives updates and reinstalls', () async {
      serve('releases/latest', release('v2.0.0'));
      serveList(1, <Map<String, Object?>>[
        release('v2.0.0'),
        release('v1.266.1'),
      ]);
      installExisting('v1.266.1', channel: 'v1');

      final result = await runInstaller();

      expectInstalled(result, 'v1.266.1', 'v1');
      expect(fetched(), isNot(contains('$apiBase/releases/latest')));
    });

    test('a full last page fails instead of guessing the newest v1', () async {
      for (var page = 1; page <= 10; page++) {
        serveList(page, <Map<String, Object?>>[
          for (var patch = 0; patch < 100; patch++) release('v1.$page.$patch'),
        ]);
      }
      installExisting('v1.0.0');

      final result = await runInstaller(channel: 'v1');

      expectUntouched(result, 'More than 1000 releases');
    });

    test('a failed or malformed page stops before replacement', () async {
      serveList(1, <Map<String, Object?>>[
        for (var patch = 0; patch < 100; patch++) release('v1.0.$patch'),
      ]);
      installExisting('v1.0.0');

      final missing = await runInstaller(channel: 'v1');
      expectUntouched(missing, 'Could not fetch release metadata');

      serve(
        'releases?per_page=100&page=2',
        '[{"tag_name": "v1.1.0", "draft": false}]',
      );
      final malformed = await runInstaller(channel: 'v1');
      expectUntouched(malformed, 'Malformed release list on page 2');
    });

    test('version parts beyond number precision still order', () async {
      serveList(1, <Map<String, Object?>>[
        release('v1.9007199254740992.0'),
        release('v1.9007199254740993.0'),
      ]);
      installExisting('v1.0.0');

      final result = await runInstaller(channel: 'v1');

      expectInstalled(result, 'v1.9007199254740993.0', 'v1');
    });

    test('a raw control character in release text is malformed', () async {
      serve(
        'releases?per_page=100&page=1',
        '[{"tag_name": "v1.2.0", "draft": false, "prerelease": false, '
            '"body": "line one\nline two"}]',
      );
      installExisting('v1.0.0');

      final result = await runInstaller(channel: 'v1');

      expectUntouched(result, 'Malformed release list on page 1');
    });

    test(
      'beta takes the highest v2 beta and never the native cohort',
      () async {
        serveList(1, <Map<String, Object?>>[
          release('v2.0.0-beta.9', prerelease: true),
          release('v2.0.0-beta.10', prerelease: true),
          release('v2.0.0-beta.11', draft: true, prerelease: true),
          release('v1.266.0-native.4', prerelease: true),
          release('v2.0.0'),
        ]);

        final result = await runInstaller(channel: 'beta');

        expectInstalled(result, 'v2.0.0-beta.10', 'beta');
      },
    );

    test('CodeWalk 1 never crosses to CodeWalk 2 without consent', () async {
      serve('releases/latest', release('v2.0.0'));
      installExisting('v1.266.1');

      final refused = await runInstaller();
      expectUntouched(refused, 'CODEWALK_MIGRATION=accept-v2');
      expect(refused.stderr, contains('CODEWALK_CHANNEL=v1'));

      final accepted = await runInstaller(migration: 'accept-v2');
      expectInstalled(accepted, 'v2.0.0', 'stable');
    });

    test('an install without a readable version is not a fresh one', () async {
      serve('releases/latest', release('v2.0.0'));
      installExisting(null);

      final result = await runInstaller();

      expectUntouched(result, 'CODEWALK_MIGRATION=accept-v2');
      expect(result.stdout, contains('treating it as CodeWalk 1'));
    });

    test('the app handoff installs exactly the approved tag', () async {
      serve('releases/latest', release('v1.266.2'));
      serve('releases/tags/v1.266.1', release('v1.266.1'));
      serve('releases/tags/v2.0.0', release('v2.0.0'));
      serve(
        'releases/tags/v1.266.0-native.1',
        release('v1.266.0-native.1', prerelease: true),
      );
      installExisting('v1.265.0');

      final incomplete = await runInstaller(contract: '1', channel: 'v1');
      expectUntouched(incomplete, 'requires CODEWALK_CHANNEL');

      final crossing = await runInstaller(
        contract: '1',
        channel: 'v1',
        version: 'v2.0.0',
        migration: 'accept-v2',
      );
      expectUntouched(crossing, 'is not a v1 release');

      final native = await runInstaller(
        contract: '1',
        channel: 'stable',
        version: 'v1.266.0-native.1',
        migration: 'none',
      );
      expectUntouched(native, 'is not a stable release');

      final missing = await runInstaller(
        contract: '1',
        channel: 'v1',
        version: 'v1.266.9',
        migration: 'none',
      );
      expectUntouched(missing, 'Could not fetch release metadata');

      final exact = await runInstaller(
        contract: '1',
        channel: 'v1',
        version: 'v1.266.1',
        migration: 'none',
      );
      expectInstalled(exact, 'v1.266.1', 'v1');
      expect(fetched(), isNot(contains('$apiBase/releases/latest')));
    });

    test('an approved CodeWalk 2 tag needs the migration consent', () async {
      serve('releases/tags/v2.0.0', release('v2.0.0'));
      installExisting('v1.266.1', channel: 'v1');

      final refused = await runInstaller(
        contract: '1',
        channel: 'stable',
        version: 'v2.0.0',
        migration: 'none',
      );
      expectUntouched(refused, 'CODEWALK_MIGRATION=accept-v2');

      final accepted = await runInstaller(
        contract: '1',
        channel: 'stable',
        version: 'v2.0.0',
        migration: 'accept-v2',
      );
      expectInstalled(accepted, 'v2.0.0', 'stable');
    });

    test('an unreadable saved channel needs an explicit choice', () async {
      serve('releases/latest', release('v1.266.1'));
      installExisting('v1.266.0', channel: 'nightly');

      final refused = await runInstaller();
      expectUntouched(refused, 'Unreadable saved channel');

      final chosen = await runInstaller(channel: 'stable');
      expectInstalled(chosen, 'v1.266.1', 'stable');
    });
  }, skip: !Platform.isLinux);
}
