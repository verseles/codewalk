import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/i18n/l10n_bridge.dart';
import 'local_opencode_server_runtime_types.dart';

LocalOpencodeServerRuntime createLocalOpencodeServerRuntime() {
  return _IoLocalOpencodeServerRuntime();
}

@visibleForTesting
String? selectLocalOpencodeReleaseAssetName({
  required Iterable<String> availableAssetNames,
  required TargetPlatform platform,
  required bool isArm64,
}) {
  final preferredNames = switch (platform) {
    TargetPlatform.windows =>
      isArm64
          ? const <String>[
              'opencode-windows-arm64.zip',
              'opencode-windows-x64.zip',
            ]
          : const <String>['opencode-windows-x64.zip'],
    TargetPlatform.macOS =>
      isArm64
          ? const <String>['opencode-darwin-arm64.zip']
          : const <String>[
              'opencode-darwin-x64.zip',
              'opencode-darwin-x64-baseline.zip',
            ],
    TargetPlatform.linux =>
      isArm64
          ? const <String>[
              'opencode-linux-arm64.tar.gz',
              'opencode-linux-arm64-musl.tar.gz',
            ]
          : const <String>[
              'opencode-linux-x64.tar.gz',
              'opencode-linux-x64-baseline.tar.gz',
              'opencode-linux-x64-musl.tar.gz',
              'opencode-linux-x64-baseline-musl.tar.gz',
            ],
    _ => const <String>[],
  };
  final available = availableAssetNames.toSet();
  for (final preferredName in preferredNames) {
    if (available.contains(preferredName)) {
      return preferredName;
    }
  }
  return null;
}

class _IoLocalOpencodeServerRuntime implements LocalOpencodeServerRuntime {
  static const String _githubLatestReleaseApi =
      'https://api.github.com/repos/anomalyco/opencode/releases/latest';

  Process? _process;
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> _stderrController =
      StreamController<String>.broadcast();
  final StreamController<int> _exitCodeController =
      StreamController<int>.broadcast();
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  @override
  bool get isSupported {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  @override
  bool get isRunning => _process != null;

  @override
  Stream<String> get stdoutLines => _stdoutController.stream;

  @override
  Stream<String> get stderrLines => _stderrController.stream;

  @override
  Stream<int> get exitCodes => _exitCodeController.stream;

  @override
  Future<LocalOpencodeServerStartResult> start({
    required String host,
    required int port,
    String? commandPath,
  }) async {
    if (!isSupported) {
      return LocalOpencodeServerStartResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderDesktopOnly ??
            'Managed local server is available only on desktop.',
      );
    }
    if (_process != null) {
      return const LocalOpencodeServerStartResult(ok: true);
    }

    final executable = commandPath?.trim().isNotEmpty == true
        ? commandPath!.trim()
        : defaultTargetPlatform == TargetPlatform.windows
        ? 'opencode.cmd'
        : 'opencode';
    final runInShell = _shouldRunInShell(executable);
    try {
      final process = await Process.start(executable, <String>[
        'serve',
        '--hostname',
        host,
        '--port',
        '$port',
      ], runInShell: runInShell);
      _process = process;

      await _stdoutSubscription?.cancel();
      await _stderrSubscription?.cancel();

      _stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_stdoutController.add);
      _stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_stderrController.add);

      unawaited(
        process.exitCode.then((code) {
          _process = null;
          _exitCodeController.add(code);
        }),
      );

      return const LocalOpencodeServerStartResult(ok: true);
    } on ProcessException catch (error) {
      final details = error.message.trim();
      if (details.isNotEmpty) {
        return LocalOpencodeServerStartResult(ok: false, errorMessage: details);
      }
      return LocalOpencodeServerStartResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorFailedToStartProcess(
              'opencode',
            ) ??
            'Failed to start opencode process.',
      );
    } catch (error) {
      return LocalOpencodeServerStartResult(
        ok: false,
        errorMessage: error.toString(),
      );
    }
  }

  @override
  Future<LocalOpencodeEnvironmentReport> diagnose({String? commandPath}) async {
    if (!isSupported) {
      return LocalOpencodeEnvironmentReport(
        supported: false,
        platform: 'unsupported',
        opencode: LocalToolStatus(
          available: false,
          note:
              L10nBridge.current?.appProviderDesktopOnly ??
              'Managed local server is available only on desktop.',
        ),
        node: const LocalToolStatus(available: false),
        npm: const LocalToolStatus(available: false),
        bun: const LocalToolStatus(available: false),
        wsl: const LocalToolStatus(available: false),
        hasNetworkAccess: false,
        installDirectoryWritable: false,
        recommendation:
            L10nBridge.current?.appProviderDesktopBuildRequired ??
            'Use a desktop build to configure a managed local server.',
      );
    }

    final configuredPath = commandPath?.trim();
    LocalToolStatus opencodeStatus;
    if (configuredPath != null && configuredPath.isNotEmpty) {
      opencodeStatus = await _probeExplicitCommand(configuredPath);
      if (!opencodeStatus.available) {
        final fallback = await _probeOpencodeFromPathOrKnownLocations();
        opencodeStatus = fallback.available
            ? fallback
            : LocalToolStatus(
                available: false,
                note:
                    L10nBridge.current
                        ?.appProviderErrorConfiguredCommandNotFound(
                          'opencode',
                        ) ??
                    'Configured command was not found and opencode is not in PATH.',
              );
      }
    } else {
      opencodeStatus = await _probeOpencodeFromPathOrKnownLocations();
    }

    final nodeStatus = await _probeCommand('node');
    final npmStatus = await _probeCommand('npm');
    final bunStatus = await _probeCommand('bun');

    LocalToolStatus wslStatus;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      wslStatus = await _probeCommand('wsl');
    } else {
      wslStatus = LocalToolStatus(
        available: false,
        note:
            L10nBridge.current?.appProviderWslCheckWindowsOnly ??
            'WSL check only applies to Windows.',
      );
    }

    final networkOk = await _hasNetworkAccess();
    final writable = await _isInstallDirectoryWritable();

    final recommendation = _buildRecommendation(
      opencode: opencodeStatus,
      bun: bunStatus,
      node: nodeStatus,
      npm: npmStatus,
      wsl: wslStatus,
      networkOk: networkOk,
      writable: writable,
    );

    return LocalOpencodeEnvironmentReport(
      supported: true,
      platform: _platformLabel(),
      opencode: opencodeStatus,
      node: nodeStatus,
      npm: npmStatus,
      bun: bunStatus,
      wsl: wslStatus,
      hasNetworkAccess: networkOk,
      installDirectoryWritable: writable,
      recommendation: recommendation,
    );
  }

  @override
  Future<LocalOpencodeInstallResult> install({
    required LocalOpencodeInstallMethod method,
    void Function(String line)? onLog,
  }) async {
    if (!isSupported) {
      onLog?.call('Managed local server is available only on desktop.');
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderDesktopOnly ??
            'Managed local server is available only on desktop.',
      );
    }

    switch (method) {
      case LocalOpencodeInstallMethod.downloadBinary:
        return _installFromRelease(onLog: onLog);
      case LocalOpencodeInstallMethod.npmGlobal:
        return _installWithNpm(onLog: onLog);
      case LocalOpencodeInstallMethod.bunGlobal:
        return _installWithBun(onLog: onLog);
      case LocalOpencodeInstallMethod.bunBootstrapThenInstall:
        return _bootstrapBunAndInstall(onLog: onLog);
    }
  }

  @override
  Future<void> stop() async {
    final process = _process;
    if (process == null) {
      return;
    }
    process.kill(ProcessSignal.sigterm);

    final exited = await Future.any(<Future<bool>>[
      process.exitCode.then((_) => true),
      Future<bool>.delayed(const Duration(seconds: 3), () => false),
    ]);
    if (exited) {
      return;
    }

    process.kill(ProcessSignal.sigkill);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _process = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    await _stdoutController.close();
    await _stderrController.close();
    await _exitCodeController.close();
  }

  Future<LocalOpencodeInstallResult> _installWithNpm({
    void Function(String line)? onLog,
  }) async {
    final npm = await _probeCommand('npm');
    if (!npm.available) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorToolNotAvailable(
              'Node.js',
              'npm',
            ) ??
            'npm is not available. Install Node.js first.',
      );
    }

    onLog?.call('Installing opencode-ai globally with npm...');
    final exitCode = await _runProcessStreaming(
      npm.path.isEmpty ? 'npm' : npm.path,
      const <String>['install', '-g', 'opencode-ai'],
      runInShell: _shouldRunInShell(npm.path.isEmpty ? 'npm' : npm.path),
      onLog: onLog,
    );
    if (exitCode != 0) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorToolInstallFailed(
              exitCode,
              'npm',
            ) ??
            'npm install failed with exit code $exitCode.',
      );
    }

    final resolved = await _resolveInstalledOpencodePath();
    if (resolved == null) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorInstalledButNotFoundInPath ??
            'OpenCode installation finished but command was not found in PATH.',
      );
    }
    onLog?.call('OpenCode installed at $resolved');
    return LocalOpencodeInstallResult(ok: true, commandPath: resolved);
  }

  Future<LocalOpencodeInstallResult> _installWithBun({
    void Function(String line)? onLog,
  }) async {
    final bun = await _probeCommand('bun');
    final bunPath = bun.path.isNotEmpty ? bun.path : _defaultBunBinaryPath();
    if (!bun.available && (bunPath == null || !File(bunPath).existsSync())) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorToolNotAvailable(
              'Bun',
              'Bun',
            ) ??
            'Bun is not available. Install Bun first.',
      );
    }

    final executable = bun.path.isNotEmpty ? bun.path : bunPath!;
    onLog?.call('Installing opencode-ai globally with Bun...');
    final exitCode = await _runProcessStreaming(
      executable,
      const <String>['install', '-g', 'opencode-ai'],
      runInShell: _shouldRunInShell(executable),
      onLog: onLog,
    );
    if (exitCode != 0) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorToolInstallFailed(
              exitCode,
              'bun',
            ) ??
            'bun install failed with exit code $exitCode.',
      );
    }

    final resolved = await _resolveInstalledOpencodePath(
      preferredBun: executable,
    );
    if (resolved == null) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorInstalledButPathNotResolved ??
            'OpenCode installation finished but command path could not be resolved.',
      );
    }
    onLog?.call('OpenCode installed at $resolved');
    return LocalOpencodeInstallResult(ok: true, commandPath: resolved);
  }

  Future<LocalOpencodeInstallResult> _bootstrapBunAndInstall({
    void Function(String line)? onLog,
  }) async {
    final existingBun = await _probeCommand('bun');
    if (existingBun.available) {
      return _installWithBun(onLog: onLog);
    }

    onLog?.call('Installing Bun runtime...');
    int exitCode;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      exitCode = await _runProcessStreaming(
        'powershell',
        const <String>[
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          'irm bun.sh/install.ps1 | iex',
        ],
        runInShell: true,
        onLog: onLog,
      );
    } else {
      exitCode = await _runProcessStreaming(
        'bash',
        const <String>['-lc', 'curl -fsSL https://bun.sh/install | bash'],
        runInShell: false,
        onLog: onLog,
      );
    }

    if (exitCode != 0) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorBunBootstrapFailed(exitCode) ??
            'Bun bootstrap failed with exit code $exitCode.',
      );
    }

    return _installWithBun(onLog: onLog);
  }

  Future<LocalOpencodeInstallResult> _installFromRelease({
    void Function(String line)? onLog,
  }) async {
    onLog?.call('Fetching OpenCode latest release metadata...');
    final release = await _fetchLatestRelease();
    if (release == null) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorReleaseMetadataFetchFailed ??
            'Failed to fetch latest release metadata from GitHub.',
      );
    }

    final versionTag = (release['tag_name'] as String? ?? '').trim();
    final assetsDynamic = release['assets'];
    if (assetsDynamic is! List) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorReleaseAssetListMissing ??
            'Latest release metadata did not include asset list.',
      );
    }

    final asset = _selectAssetForCurrentPlatform(assetsDynamic);
    if (asset == null) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorNoCompatibleAsset ??
            'No compatible OpenCode binary asset was found.',
      );
    }

    final installRoot = _installRootDirectory();
    await installRoot.create(recursive: true);

    final version = _normalizeVersion(versionTag, fallback: 'latest');
    final versionDir = Directory(_joinPath(installRoot.path, version));
    await versionDir.create(recursive: true);

    final archivePath = _joinPath(versionDir.path, asset.name);
    onLog?.call('Downloading ${asset.name}...');
    final downloadOk = await _downloadFile(
      url: asset.downloadUrl,
      outputPath: archivePath,
      onLog: onLog,
    );
    if (!downloadOk) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorDownloadAssetFailed ??
            'Failed to download selected OpenCode asset.',
      );
    }

    if (asset.sha256Digest.isNotEmpty) {
      onLog?.call('Verifying SHA256 checksum...');
      final actualDigest = await _computeSha256(File(archivePath));
      if (actualDigest.toLowerCase() != asset.sha256Digest.toLowerCase()) {
        return LocalOpencodeInstallResult(
          ok: false,
          errorMessage:
              L10nBridge.current?.appProviderErrorChecksumVerificationFailed ??
              'Checksum verification failed for downloaded asset.',
        );
      }
      onLog?.call('Checksum verified.');
    }

    final extractedDir = Directory(_joinPath(versionDir.path, 'extracted'));
    if (extractedDir.existsSync()) {
      await extractedDir.delete(recursive: true);
    }
    await extractedDir.create(recursive: true);

    onLog?.call('Extracting archive...');
    final extracted = await _extractArchive(
      archivePath: archivePath,
      destinationPath: extractedDir.path,
      isZip: asset.name.toLowerCase().endsWith('.zip'),
      onLog: onLog,
    );
    if (!extracted) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorExtractArchiveFailed ??
            'Failed to extract OpenCode binary archive.',
      );
    }

    final executableName = defaultTargetPlatform == TargetPlatform.windows
        ? 'opencode.exe'
        : 'opencode';
    var discoveredPath = await _findExecutableInDirectory(
      extractedDir,
      executableName,
    );
    if (discoveredPath == null &&
        defaultTargetPlatform == TargetPlatform.windows) {
      discoveredPath = await _findExecutableInDirectory(
        extractedDir,
        'opencode.cmd',
      );
    }

    if (discoveredPath == null) {
      return LocalOpencodeInstallResult(
        ok: false,
        errorMessage:
            L10nBridge.current?.appProviderErrorExecutableNotFound(
              'opencode',
            ) ??
            'Could not find opencode executable in extracted files.',
      );
    }

    final binDir = Directory(_joinPath(installRoot.path, 'bin'));
    await binDir.create(recursive: true);
    final targetName = defaultTargetPlatform == TargetPlatform.windows
        ? discoveredPath.toLowerCase().endsWith('.cmd')
              ? 'opencode.cmd'
              : 'opencode.exe'
        : 'opencode';
    final targetPath = _joinPath(binDir.path, targetName);
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      await targetFile.delete();
    }
    await File(discoveredPath).copy(targetPath);

    if (defaultTargetPlatform != TargetPlatform.windows) {
      await Process.run('chmod', <String>['+x', targetPath]);
    }

    onLog?.call('OpenCode binary installed at $targetPath');
    return LocalOpencodeInstallResult(ok: true, commandPath: targetPath);
  }

  Future<LocalToolStatus> _probeCommand(String command) async {
    final whereCommand = defaultTargetPlatform == TargetPlatform.windows
        ? 'where'
        : 'which';
    try {
      final whereResult = await _runProcessCollect(whereCommand, <String>[
        command,
      ], runInShell: defaultTargetPlatform == TargetPlatform.windows);
      if (whereResult.exitCode != 0) {
        return const LocalToolStatus(available: false);
      }

      final path = _firstNonEmptyLine(
        '${whereResult.stdout}\n${whereResult.stderr}',
      );
      if (path == null) {
        return const LocalToolStatus(available: false);
      }

      final versionResult = await _runProcessCollect(path, const <String>[
        '--version',
      ], runInShell: _shouldRunInShell(path));
      final version =
          _firstNonEmptyLine(
            '${versionResult.stdout}\n${versionResult.stderr}',
          ) ??
          '';

      return LocalToolStatus(available: true, path: path, version: version);
    } catch (_) {
      return const LocalToolStatus(available: false);
    }
  }

  Future<LocalToolStatus> _probeOpencodeFromPathOrKnownLocations() async {
    final fromPath = await _probeCommand('opencode');
    if (fromPath.available) {
      return fromPath;
    }

    final fromKnownLocation = await _probeKnownOpencodeLocation();
    if (fromKnownLocation != null) {
      return fromKnownLocation;
    }

    return const LocalToolStatus(available: false);
  }

  Future<LocalToolStatus?> _probeKnownOpencodeLocation() async {
    for (final candidate in _knownOpencodeCandidates()) {
      final status = await _probeExplicitCommand(candidate);
      if (!status.available) {
        continue;
      }
      return LocalToolStatus(
        available: true,
        path: status.path,
        version: status.version,
        note: _knownLocationNote(candidate),
      );
    }
    return null;
  }

  List<String> _knownOpencodeCandidates() {
    final candidates = <String>[];
    final localBin = _joinPath(_installRootDirectory().path, 'bin');
    if (defaultTargetPlatform == TargetPlatform.windows) {
      candidates.add(_joinPath(localBin, 'opencode.cmd'));
      candidates.add(_joinPath(localBin, 'opencode.exe'));

      final appData = Platform.environment['APPDATA']?.trim() ?? '';
      if (appData.isNotEmpty) {
        final npmBin = _joinPath(appData, 'npm');
        candidates.add(_joinPath(npmBin, 'opencode.cmd'));
        candidates.add(_joinPath(npmBin, 'opencode.exe'));
      }

      final home = _userHomeDirectory();
      if (home != null && home.isNotEmpty) {
        final bunBin = _joinPath(_joinPath(home, '.bun'), 'bin');
        candidates.add(_joinPath(bunBin, 'opencode.cmd'));
        candidates.add(_joinPath(bunBin, 'opencode.exe'));
      }
    } else {
      candidates.add(_joinPath(localBin, 'opencode'));
      final home = _userHomeDirectory();
      if (home != null && home.isNotEmpty) {
        final bunBin = _joinPath(_joinPath(home, '.bun'), 'bin');
        candidates.add(_joinPath(bunBin, 'opencode'));
      }
    }

    return candidates.toSet().toList(growable: false);
  }

  String _knownLocationNote(String commandPath) {
    final base =
        L10nBridge.current?.appProviderKnownInstallationDirectoryDetected ??
        'Detected from a known installation directory.';
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return base;
    }

    final directory = _directoryName(commandPath);
    if (directory == null ||
        directory.isEmpty ||
        _pathContainsDirectory(directory)) {
      return base;
    }

    return L10nBridge.current?.appProviderKnownInstallationPathRefreshHint(
          'CodeWalk',
        ) ??
        '$base PATH may need refresh; reopen CodeWalk if a recent install is not detected yet.';
  }

  bool _pathContainsDirectory(String pathToFind) {
    final envPath = Platform.environment['PATH'];
    if (envPath == null || envPath.trim().isEmpty) {
      return false;
    }

    final separator = defaultTargetPlatform == TargetPlatform.windows
        ? ';'
        : ':';
    final target = _normalizePathSegment(pathToFind);
    if (target.isEmpty) {
      return false;
    }

    for (final segment in envPath.split(separator)) {
      if (_normalizePathSegment(segment) == target) {
        return true;
      }
    }
    return false;
  }

  String _normalizePathSegment(String raw) {
    var value = raw.trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      value = value.replaceAll('/', '\\').toLowerCase();
      while (value.endsWith('\\')) {
        value = value.substring(0, value.length - 1);
      }
      return value;
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Future<LocalToolStatus> _probeExplicitCommand(String commandPath) async {
    final file = File(commandPath);
    if (!file.existsSync()) {
      return LocalToolStatus(
        available: false,
        note:
            L10nBridge.current?.appProviderErrorConfiguredCommandPathMissing ??
            'Configured command path does not exist.',
      );
    }

    try {
      final result = await _runProcessCollect(commandPath, const <String>[
        '--version',
      ], runInShell: _shouldRunInShell(commandPath));
      if (result.exitCode != 0) {
        return LocalToolStatus(
          available: false,
          note:
              L10nBridge
                  .current
                  ?.appProviderErrorConfiguredCommandVersionCheckFailed ??
              'Configured command exists but version check failed.',
        );
      }
      final version =
          _firstNonEmptyLine('${result.stdout}\n${result.stderr}') ?? '';
      return LocalToolStatus(
        available: true,
        path: commandPath,
        version: version,
      );
    } catch (_) {
      return LocalToolStatus(
        available: false,
        note:
            L10nBridge
                .current
                ?.appProviderErrorConfiguredCommandExecutionFailed ??
            'Configured command could not be executed.',
      );
    }
  }

  Future<bool> _hasNetworkAccess() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.getUrl(Uri.parse('https://api.github.com'));
      request.headers.set(HttpHeaders.userAgentHeader, 'codewalk');
      final response = await request.close();
      await response.drain();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _isInstallDirectoryWritable() async {
    try {
      final directory = _installRootDirectory();
      await directory.create(recursive: true);
      final probe = File(_joinPath(directory.path, '.write_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  String _buildRecommendation({
    required LocalToolStatus opencode,
    required LocalToolStatus bun,
    required LocalToolStatus node,
    required LocalToolStatus npm,
    required LocalToolStatus wsl,
    required bool networkOk,
    required bool writable,
  }) {
    if (!networkOk) {
      return L10nBridge.current?.onboardingPreconditionNetworkFailed ??
          'Network access failed. Check connectivity before installing OpenCode.';
    }
    if (!writable) {
      return L10nBridge.current?.onboardingPreconditionDirectoryNotWritable ??
          'Install directory is not writable. Check user permissions.';
    }
    if (opencode.available) {
      return L10nBridge
              .current
              ?.onboardingPreconditionOpenCodeAlreadyAvailable ??
          'OpenCode is already available. You can use the detected command immediately.';
    }
    if (defaultTargetPlatform == TargetPlatform.windows && !wsl.available) {
      // Fallback only: localized builds use the ARB value until the next safe
      // localization sync updates `arb_strings.dart` and regenerated files.
      return L10nBridge
              .current
              ?.onboardingPreconditionWindowsWslRecommendation ??
          'Windows build detected. WSL is recommended by OpenCode docs, but npm install can be used as fallback.';
    }
    if (bun.available) {
      return L10nBridge
              .current
              ?.onboardingPreconditionInstallViaBunRecommendation ??
          'Install via Bun is recommended by OpenCode maintainers.';
    }
    if (node.available && npm.available) {
      final windowsHint = defaultTargetPlatform == TargetPlatform.windows
          ? (L10nBridge.current?.onboardingPreconditionWindowsPathLagHint ??
                ' On Windows, refresh checks after install because PATH updates may lag in already-open apps.')
          : '';
      final mainText =
          L10nBridge.current?.onboardingPreconditionNodeNpmAvailable ??
          'Node + npm are available. Install OpenCode via npm or install Bun for the recommended flow.';
      return '$mainText$windowsHint';
    }
    return L10nBridge.current?.onboardingPreconditionNoRuntimeDetected ??
        'No runtime detected. Install OpenCode binary directly or bootstrap Bun first.';
  }

  Future<_ProcessRunResult> _runProcessCollect(
    String executable,
    List<String> arguments, {
    required bool runInShell,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        runInShell: runInShell,
      );
      return _ProcessRunResult(
        exitCode: result.exitCode,
        stdout: (result.stdout ?? '').toString(),
        stderr: (result.stderr ?? '').toString(),
      );
    } on ProcessException catch (error) {
      return _ProcessRunResult(exitCode: -1, stdout: '', stderr: error.message);
    }
  }

  Future<int> _runProcessStreaming(
    String executable,
    List<String> arguments, {
    required bool runInShell,
    void Function(String line)? onLog,
  }) async {
    try {
      final process = await Process.start(
        executable,
        arguments,
        runInShell: runInShell,
      );

      final stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            onLog?.call(line);
          });
      final stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            onLog?.call(line);
          });

      final exitCode = await process.exitCode;
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      return exitCode;
    } on ProcessException catch (error) {
      onLog?.call(error.message);
      return -1;
    }
  }

  Future<String?> _resolveInstalledOpencodePath({String? preferredBun}) async {
    final inPath = await _probeCommand('opencode');
    if (inPath.available && inPath.path.isNotEmpty) {
      return inPath.path;
    }

    if (preferredBun != null && preferredBun.trim().isNotEmpty) {
      final bunDir = _directoryName(preferredBun.trim());
      if (bunDir != null && bunDir.isNotEmpty) {
        final windowsCandidates = <String>['opencode.cmd', 'opencode.exe'];
        final unixCandidates = <String>['opencode'];
        final candidates = defaultTargetPlatform == TargetPlatform.windows
            ? windowsCandidates
            : unixCandidates;
        for (final candidate in candidates) {
          final path = _joinPath(bunDir, candidate);
          if (File(path).existsSync()) {
            return path;
          }
        }
      }
    }

    final knownLocation = await _probeKnownOpencodeLocation();
    if (knownLocation != null && knownLocation.path.trim().isNotEmpty) {
      return knownLocation.path;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(_githubLatestReleaseApi));
      request.headers.set(HttpHeaders.userAgentHeader, 'codewalk');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain();
        return null;
      }
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  _ReleaseAsset? _selectAssetForCurrentPlatform(List<dynamic> assets) {
    final mapped = <_ReleaseAsset>[];
    for (final dynamic item in assets) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] as String? ?? '').trim();
      final downloadUrl = (map['browser_download_url'] as String? ?? '').trim();
      if (name.isEmpty || downloadUrl.isEmpty) {
        continue;
      }
      final digestValue = (map['digest'] as String? ?? '').trim();
      var sha256Digest = '';
      if (digestValue.toLowerCase().startsWith('sha256:')) {
        sha256Digest = digestValue.substring('sha256:'.length).trim();
      }
      mapped.add(
        _ReleaseAsset(
          name: name,
          downloadUrl: downloadUrl,
          sha256Digest: sha256Digest,
        ),
      );
    }

    final abi = Abi.current();
    final isArm64 =
        abi == Abi.linuxArm64 ||
        abi == Abi.macosArm64 ||
        abi == Abi.windowsArm64;

    final selectedName = selectLocalOpencodeReleaseAssetName(
      availableAssetNames: mapped.map((asset) => asset.name),
      platform: defaultTargetPlatform,
      isArm64: isArm64,
    );
    if (selectedName == null) {
      return null;
    }
    for (final asset in mapped) {
      if (asset.name == selectedName) {
        return asset;
      }
    }
    return null;
  }

  Future<bool> _downloadFile({
    required String url,
    required String outputPath,
    void Function(String line)? onLog,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'codewalk');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain();
        return false;
      }

      final file = File(outputPath);
      if (file.existsSync()) {
        await file.delete();
      }
      final sink = file.openWrite();
      var downloadedBytes = 0;
      var nextReportBytes = 5 * 1024 * 1024;

      await for (final chunk in response) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        if (downloadedBytes >= nextReportBytes) {
          final downloadedMb = downloadedBytes / (1024 * 1024);
          onLog?.call('Downloaded ${downloadedMb.toStringAsFixed(1)} MB...');
          nextReportBytes += 5 * 1024 * 1024;
        }
      }
      await sink.close();
      return true;
    } catch (error) {
      onLog?.call(error.toString());
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _computeSha256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> _extractArchive({
    required String archivePath,
    required String destinationPath,
    required bool isZip,
    void Function(String line)? onLog,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (isZip) {
        final exitCode = await _runProcessStreaming(
          'powershell',
          <String>[
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'Expand-Archive -Path "${_escapeForDoubleQuotes(archivePath)}" -DestinationPath "${_escapeForDoubleQuotes(destinationPath)}" -Force',
          ],
          runInShell: true,
          onLog: onLog,
        );
        return exitCode == 0;
      }

      final exitCode = await _runProcessStreaming(
        'tar',
        <String>['-xzf', archivePath, '-C', destinationPath],
        runInShell: true,
        onLog: onLog,
      );
      return exitCode == 0;
    }

    final exitCode = isZip
        ? await _runProcessStreaming(
            'unzip',
            <String>['-o', archivePath, '-d', destinationPath],
            runInShell: false,
            onLog: onLog,
          )
        : await _runProcessStreaming(
            'tar',
            <String>['-xzf', archivePath, '-C', destinationPath],
            runInShell: false,
            onLog: onLog,
          );
    return exitCode == 0;
  }

  Future<String?> _findExecutableInDirectory(
    Directory root,
    String expectedFileName,
  ) async {
    final target = expectedFileName.toLowerCase();
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final fileName = _basename(entity.path).toLowerCase();
      if (fileName == target) {
        return entity.path;
      }
    }
    return null;
  }

  Directory _installRootDirectory() {
    final home = _userHomeDirectory() ?? Directory.systemTemp.path;
    return Directory(
      _joinPath(home, '.codewalk${Platform.pathSeparator}local-opencode'),
    );
  }

  String? _userHomeDirectory() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return Platform.environment['USERPROFILE'];
    }
    return Platform.environment['HOME'];
  }

  String? _defaultBunBinaryPath() {
    final home = _userHomeDirectory();
    if (home == null || home.isEmpty) {
      return null;
    }
    final binName = defaultTargetPlatform == TargetPlatform.windows
        ? 'bun.exe'
        : 'bun';
    return _joinPath(
      home,
      '.bun${Platform.pathSeparator}bin${Platform.pathSeparator}$binName',
    );
  }

  String _platformLabel() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux => 'linux',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'windows',
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  bool _shouldRunInShell(String executable) {
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return false;
    }
    final lower = executable.toLowerCase();
    return lower.endsWith('.cmd') || lower.endsWith('.bat');
  }

  String _normalizeVersion(String tag, {required String fallback}) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    return trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
  }

  String? _firstNonEmptyLine(String value) {
    for (final raw in value.split('\n')) {
      final line = raw.trim();
      if (line.isNotEmpty) {
        return line;
      }
    }
    return null;
  }

  String _basename(String input) {
    final segments = input.split(Platform.pathSeparator);
    return segments.isEmpty ? input : segments.last;
  }

  String? _directoryName(String input) {
    final index = input.lastIndexOf(Platform.pathSeparator);
    if (index <= 0) {
      return null;
    }
    return input.substring(0, index);
  }

  String _joinPath(String base, String child) {
    if (base.endsWith(Platform.pathSeparator)) {
      return '$base$child';
    }
    return '$base${Platform.pathSeparator}$child';
  }

  String _escapeForDoubleQuotes(String input) {
    return input.replaceAll('"', '\\"');
  }
}

class _ProcessRunResult {
  const _ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class _ReleaseAsset {
  const _ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sha256Digest,
  });

  final String name;
  final String downloadUrl;
  final String sha256Digest;
}
