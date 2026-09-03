part of 'settings_provider.dart';

String resolveDesktopRestartExecutable({
  required TargetPlatform targetPlatform,
  required String resolvedExecutable,
  required Map<String, String> environment,
  required bool Function(String path) fileExists,
}) {
  if (targetPlatform != TargetPlatform.linux ||
      fileExists(resolvedExecutable)) {
    return resolvedExecutable;
  }
  final home = environment['HOME']?.trim();
  if (home == null || home.isEmpty) {
    return resolvedExecutable;
  }
  final installerLink = '$home/.local/bin/codewalk';
  return fileExists(installerLink) ? installerLink : resolvedExecutable;
}

/// Decides whether an Android APK download progress update should notify
/// listeners. Dio emits `onReceiveProgress` per network chunk; notifying on
/// every chunk rebuilds the whole app shell at network speed, churning the
/// heap on memory-constrained Android release builds. Completion always
/// notifies; otherwise [minDelta] progress and [minInterval] since the last
/// notification are required.
bool shouldNotifyInstallProgress({
  required double previous,
  required double next,
  required DateTime? lastNotifiedAt,
  required DateTime now,
  double minDelta = 0.01,
  Duration minInterval = const Duration(milliseconds: 100),
}) {
  if (next >= 1.0) return true;
  if (next - previous < minDelta) return false;
  if (lastNotifiedAt == null) return true;
  return now.difference(lastNotifiedAt) >= minInterval;
}

extension SettingsProviderUpdateInstall on SettingsProvider {
  Future<void> checkForUpdate() async {
    _checkingForUpdate = true;
    _lastCheckFoundNoUpdate = false;
    try {
      notifyListeners();
      final info = await PackageInfo.fromPlatform();
      _updateCheckService.clearCache();
      final result = await _updateCheckService.check(info.version);
      if (result != null &&
          result.isNewer &&
          result.latestVersion != _dismissedUpdateVersion) {
        _updateCheckResult = result;
        _lastCheckFoundNoUpdate = false;
      } else {
        _updateCheckResult = null;
        _lastCheckFoundNoUpdate = result != null;
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Update check failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _checkingForUpdate = false;
      notifyListeners();
    }
  }

  Future<void> dismissUpdate(String version) async {
    _dismissedUpdateVersion = version;
    _updateCheckResult = null;
    _installState = UpdateInstallState.idle;
    _installProgress = 0.0;
    await _localDataSource.saveDismissedUpdateVersion(version);
    notifyListeners();
  }

  /// Resets in-memory state to defaults (used after clearAll during app reset).
  Future<void> resetToDefaults() async {
    _automaticUpdateCheckTimer?.cancel();
    _automaticUpdateCheckTimer = null;
    _settings = ExperienceSettings.defaults();
    _updateCheckResult = null;
    _dismissedUpdateVersion = null;
    _checkingForUpdate = false;
    _lastCheckFoundNoUpdate = false;
    _pendingStartupUpdateToast = false;
    _installState = UpdateInstallState.idle;
    _installProgress = 0.0;
    _initialized = false;
    _initFuture = null;
    await _syncAndroidBackgroundAlertRuntime();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      await DesktopWindowChromeService.apply(
        ExperienceSettings.defaults().desktopWindowChrome,
      );
    }
    notifyListeners();
  }

  /// Begins the in-app update installation flow for the current platform.
  /// Android: downloads the APK then opens the system installer.
  /// Desktop: runs the install.cat shell script and signals "Restart to apply".
  /// Resetting to idle first lets AppShellPage clear its SnackBar guards on retry.
  Future<void> startInstall() async {
    if (_installState == UpdateInstallState.downloading ||
        _installState == UpdateInstallState.installing) {
      return;
    }
    final result = _updateCheckResult;
    if (result == null || !canInstallUpdateDirectly(result)) {
      return;
    }

    // Reset to idle so AppShellPage observers can clear their snackbar guards.
    _installState = UpdateInstallState.idle;
    _installProgress = 0.0;
    notifyListeners();

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      await _installAndroid(result);
    } else {
      await _installDesktop();
    }
  }

  bool canInstallUpdateDirectly([UpdateCheckResult? result]) {
    final updateResult = result ?? _updateCheckResult;
    if (updateResult == null || kIsWeb) {
      return false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return updateResult.apkUrl != null;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return false;
    }
  }

  Future<void> _installAndroid(UpdateCheckResult result) async {
    final apkUrl = result.apkUrl;
    if (apkUrl == null) return;

    _installState = UpdateInstallState.downloading;
    _installProgress = 0.0;
    _lastInstallProgressNotify = null;
    notifyListeners();

    String? destPath;
    try {
      final tmpDir = await getTemporaryDirectory();
      destPath = '${tmpDir.path}/codewalk-update.apk';
      // Use explicit timeouts; APK downloads can be large but should not hang forever.
      final downloadZone = Zone.current;
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 10),
        ),
      ).download(
        apkUrl,
        destPath,
        onReceiveProgress: (received, total) {
          final progress = total > 0
              ? (received / total).clamp(0.0, 1.0)
              : 0.0;
          final now = DateTime.now();
          if (!shouldNotifyInstallProgress(
            previous: _installProgress,
            next: progress,
            lastNotifiedAt: _lastInstallProgressNotify,
            now: now,
          )) {
            return;
          }
          _installProgress = progress;
          _lastInstallProgressNotify = now;
          downloadZone.run(notifyListeners);
        },
      );
      _installState = UpdateInstallState.installing;
      notifyListeners();
      await OpenFilex.open(destPath);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'APK download failed',
        error: error,
        stackTrace: stackTrace,
      );
      // Clean up partial file so a retry does not open a corrupt APK.
      if (destPath != null) {
        try {
          final file = File(destPath);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
      _installState = UpdateInstallState.failed;
      notifyListeners();
    }
  }

  Future<void> _installDesktop() async {
    _installState = UpdateInstallState.installing;
    notifyListeners();

    try {
      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      // Wrap in a timeout so a stalled network does not hang indefinitely.
      ProcessResult processResult;
      if (isWindows) {
        processResult = await Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-c',
          r"$env:CODEWALK_INSTALL_MODE='stage'; irm install.cat/verseles/codewalk | iex",
        ]).timeout(const Duration(minutes: 5));
      } else {
        processResult = await Process.run('sh', [
          '-c',
          'curl -fsSL install.cat/verseles/codewalk | sh',
        ]).timeout(const Duration(minutes: 5));
      }
      _installState = processResult.exitCode == 0
          ? UpdateInstallState.done
          : UpdateInstallState.failed;
      if (processResult.exitCode != 0) {
        AppLogger.warn('Desktop install failed: ${processResult.stderr}');
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Desktop install failed',
        error: error,
        stackTrace: stackTrace,
      );
      _installState = UpdateInstallState.failed;
    }
    notifyListeners();
  }

  Future<void> restartDesktopApp() async {
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    if (!isDesktop) {
      return;
    }
    try {
      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      if (isWindows) {
        final command =
            r"$env:CODEWALK_INSTALL_MODE='apply'; "
            "\$env:CODEWALK_PARENT_PID='$pid'; "
            r"$env:CODEWALK_RELAUNCH='1'; "
            'irm install.cat/verseles/codewalk | iex';
        await Process.start('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-Command',
          command,
        ], mode: ProcessStartMode.detached);
        exit(0);
      }

      final executable = resolveDesktopRestartExecutable(
        targetPlatform: defaultTargetPlatform,
        resolvedExecutable: Platform.resolvedExecutable,
        environment: Platform.environment,
        fileExists: (path) => File(path).existsSync(),
      );
      final args = List<String>.from(Platform.executableArguments);
      await Process.start(executable, args, mode: ProcessStartMode.detached);
      exit(0);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Desktop restart relaunch failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
