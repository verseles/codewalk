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
  /// Manual "Check for updates". Returns true when it found a CodeWalk major
  /// update, which the caller presents through the gate dialog. An explicit
  /// check bypasses an active "Remind me later" reminder.
  Future<bool> checkForUpdate() async {
    _checkingForUpdate = true;
    _lastCheckFoundNoUpdate = false;
    final generation = _updatePolicyGeneration;
    try {
      notifyListeners();
      final info = await PackageInfo.fromPlatform();
      _updateCheckService.clearCache();
      final routed = await _routeUpdateQuery(
        info.version,
        ignoreCooldown: false,
        bypassReminder: true,
      );
      if (routed == null || generation != _updatePolicyGeneration) {
        // Failed check: keep the last known update/news state instead of
        // flashing an empty surface (matches the silent-check behavior).
        return false;
      }
      if (routed.isMajorGate) {
        _presentMajorUpdateGate(routed.result!, startup: false);
        return true;
      }
      _hideMajorUpdateGate();
      final result = routed.result;
      if (result == null) {
        return false;
      }
      _latestRelease = result;
      if (result.isNewer && result.latestVersion != _dismissedUpdateVersion) {
        _updateCheckResult = result;
        _updateCheckResultIsLatest = routed.isLatest;
        _lastCheckFoundNoUpdate = false;
      } else {
        _updateCheckResult = null;
        _lastCheckFoundNoUpdate = true;
      }
      return false;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Update check failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
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

  /// Dismisses only the What's-new announcement for [version].
  /// Leaves the update/install state untouched.
  Future<void> dismissNews(String version) async {
    _dismissedNewsVersion = version;
    _pendingStartupNewsToast = false;
    await _localDataSource.saveDismissedNewsVersion(version);
    notifyListeners();
  }

  /// Resets in-memory state to defaults (used after clearAll during app reset).
  Future<void> resetToDefaults() async {
    await resetReleaseHistory();
    _automaticUpdateCheckTimer?.cancel();
    _automaticUpdateCheckTimer = null;
    _lastSettingsOpenUpdateCheckAt = null;
    _silentUpdateCheckInFlight = null;
    _silentUpdateCheckInFlightForced = false;
    _settings = ExperienceSettings.defaults();
    _updateCheckResult = null;
    _dismissedUpdateVersion = null;
    _latestRelease = null;
    _dismissedNewsVersion = null;
    _pendingStartupNewsToast = false;
    _bumpUpdatePolicyGeneration();
    _updateChannel = UpdateChannel.stable;
    _majorUpdateRemindUntil = null;
    _majorUpdateRemindMajor = null;
    _hideMajorUpdateGate();
    _updateCheckService.clearCache();
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
  /// Linux hands it the exact release; Windows and macOS, whose installers do
  /// not take one yet, open the release page for CodeWalk 2, CodeWalk-1-only
  /// and not-latest updates.
  /// Resetting to idle first lets AppShellPage clear its SnackBar guards on retry.
  Future<void> startInstall() async {
    if (_installState == UpdateInstallState.downloading ||
        _installState == UpdateInstallState.installing) {
      return;
    }
    final result = _installTarget();
    if (result == null) {
      return;
    }
    if (_requiresManualDesktopUpdate(result)) {
      await _openReleasePageForManualUpdate(result);
      return;
    }
    if (!canInstallUpdateDirectly(result)) {
      // An approved CodeWalk 2 release on a platform without an installer
      // (Web, iOS) opens its release page, so the gate's Update is never a
      // no-op there.
      final hasNoInstaller =
          kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;
      if (result.isMajorUpgrade && hasNoInstaller) {
        await _openReleasePageForManualUpdate(result);
      }
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
      await _installDesktop(result);
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
        return !_requiresManualDesktopUpdate(updateResult);
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return false;
    }
  }

  /// The release startInstall may act on. A major release qualifies only
  /// after the gate's Update action approved that exact tag, so no retry,
  /// shortcut or snackbar can bypass the gate.
  UpdateCheckResult? _installTarget() {
    final candidate = _majorUpdateCandidate;
    if (candidate != null) {
      final approved = _approvedMajorUpdate;
      if (approved == null ||
          approved.releaseTag == null ||
          approved.releaseTag != candidate.releaseTag) {
        return null;
      }
      return approved;
    }
    final result = _updateCheckResult;
    if (result == null || result.isMajorUpgrade) {
      return null;
    }
    return result;
  }

  /// The Linux installer takes the exact release, so only a release without
  /// a tag needs its page there. The Windows and macOS installers resolve
  /// /releases/latest and ignore any tag, so they run only for a same-major
  /// release that /releases/latest returned; a CodeWalk 2 target,
  /// CodeWalk-1-only mode and a 1.x fix offered during a Later reminder
  /// (latest is CodeWalk 2 then) open the release page.
  bool _requiresManualDesktopUpdate(UpdateCheckResult result) {
    if (kIsWeb) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return result.releaseTag == null;
    }
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
    return isDesktop &&
        (result.isMajorUpgrade ||
            _updateChannel == UpdateChannel.v1 ||
            !identical(result, _updateCheckResult) ||
            !_updateCheckResultIsLatest);
  }

  Future<bool> _openReleasePageForManualUpdate(UpdateCheckResult result) async {
    final url = result.releaseUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) {
      AppLogger.warn('Manual update has no release page to open');
      return false;
    }
    try {
      return await _externalUrlLauncher(uri);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Opening the release page failed',
        error: error,
        stackTrace: stackTrace,
      );
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
    // Give the shell a frame to present progress before a fast/cached APK
    // transfer can advance straight to the system installer.
    await WidgetsBinding.instance.endOfFrame;

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
          final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
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

  // Desktop handoff contract (V1-01, implemented by install.sh in V1-05A):
  // the receiving `sh` — not only `curl` — gets CODEWALK_UPDATE_CONTRACT=1,
  // CODEWALK_CHANNEL=stable|v1, CODEWALK_VERSION=<exact approved tag> and
  // CODEWALK_MIGRATION=none|accept-v2 in its environment. The Windows
  // installer does not take them yet (V1-05B), so it runs only for a
  // same-major release that /releases/latest returned.
  Future<void> _installDesktop(UpdateCheckResult result) async {
    final releaseTag = result.releaseTag;
    final handoff =
        defaultTargetPlatform == TargetPlatform.linux && releaseTag != null
        ? <String, String>{
            'CODEWALK_UPDATE_CONTRACT': '1',
            'CODEWALK_CHANNEL':
                !result.isMajorUpgrade && _updateChannel == UpdateChannel.v1
                ? 'v1'
                : 'stable',
            'CODEWALK_VERSION': releaseTag,
            // Reached only for the release the gate approved.
            'CODEWALK_MIGRATION': result.isMajorUpgrade ? 'accept-v2' : 'none',
          }
        : null;
    _installState = UpdateInstallState.installing;
    notifyListeners();

    try {
      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      // Wrap in a timeout so a stalled network does not hang indefinitely.
      ProcessResult processResult;
      if (isWindows) {
        processResult = await _updateProcessRunner('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-c',
          r"$env:CODEWALK_INSTALL_MODE='stage'; irm install.cat/verseles/codewalk | iex",
        ]).timeout(const Duration(minutes: 5));
      } else {
        processResult = await _updateProcessRunner('sh', [
          '-c',
          'curl -fsSL install.cat/verseles/codewalk | sh',
        ], environment: handoff).timeout(const Duration(minutes: 5));
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
