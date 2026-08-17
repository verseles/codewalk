import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../services/desktop_tray_service.dart';
import '../services/desktop_tray_service_types.dart';
import '../services/update_check_service.dart';
import 'chat_page.dart';
import 'onboarding_wizard_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final DesktopTrayService _desktopTrayService = createDesktopTrayService();
  SettingsProvider? _settingsProvider;
  bool _onboardingActive = false;
  // Tracks whether the wizard was dismissed this session (without persisting
  // the preference). Resets on app restart, unlike skipOnboardingWizard.
  bool _wizardDismissedThisSession = false;
  // Ensures the startup update toast is shown at most once per session.
  String? _shownStartupUpdateVersion;
  // Guards for install-state SnackBars so they are shown at most once each.
  bool _shownProgressSnackBar = false;
  bool _shownDoneSnackBar = false;
  bool _shownFailedSnackBar = false;
  UpdateInstallState _lastObservedInstallState = UpdateInstallState.idle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextSettingsProvider = context.read<SettingsProvider>();
    if (identical(_settingsProvider, nextSettingsProvider)) {
      return;
    }
    _settingsProvider?.removeListener(_handleSettingsChanged);
    _settingsProvider = nextSettingsProvider;
    _settingsProvider?.addListener(_handleSettingsChanged);
    unawaited(_configureDesktopTray());
  }

  @override
  void dispose() {
    _settingsProvider?.removeListener(_handleSettingsChanged);
    unawaited(_desktopTrayService.dispose());
    super.dispose();
  }

  void _handleSettingsChanged() {
    // Runs on every SettingsProvider notification before the Settings page
    // consumers. _configureDesktopTray catches its own failures, so this
    // listener never throws synchronously and cannot stop later listeners.
    unawaited(_configureDesktopTray());
  }

  Future<void> _configureDesktopTray() async {
    final settingsProvider = _settingsProvider;
    if (settingsProvider == null) {
      return;
    }
    try {
      await _desktopTrayService.initialize(
        closeBehavior: settingsProvider.desktopCloseBehavior,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Desktop tray configuration failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppProvider, SettingsProvider>(
      builder: (context, appProvider, settingsProvider, _) {
        // Wait until both providers have loaded persisted state.
        if (!appProvider.initialized || !settingsProvider.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Show onboarding wizard when no server is configured, unless user
        // opted out permanently or dismissed it this session.
        final shouldShowOnboarding =
            appProvider.serverProfiles.isEmpty &&
            !settingsProvider.skipOnboardingWizard &&
            !_wizardDismissedThisSession;
        if (shouldShowOnboarding && !_onboardingActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _onboardingActive) {
              return;
            }
            setState(() {
              _onboardingActive = true;
            });
          });
        }
        if (shouldShowOnboarding || _onboardingActive) {
          return OnboardingWizardPage(
            onComplete: () {
              setState(() {
                _onboardingActive = false;
                _wizardDismissedThisSession = true;
              });
            },
          );
        }
        // Schedule startup update toast once the main shell is rendered.
        // Only fires for startup-origin checks (pendingStartupUpdateToast),
        // not for manual "Check for updates" presses.
        // Flag is set here (not in the callback) to prevent multiple
        // addPostFrameCallback registrations across rebuilds.
        final updateResult = settingsProvider.updateCheckResult;
        if (settingsProvider.pendingStartupUpdateToast &&
            updateResult != null &&
            updateResult.isNewer &&
            updateResult.latestVersion != _shownStartupUpdateVersion) {
          _shownStartupUpdateVersion = updateResult.latestVersion;
          settingsProvider.acknowledgeStartupUpdateToast();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUpdateToast(context, settingsProvider, updateResult);
          });
        }

        // React to install state transitions with SnackBars.
        final installState = settingsProvider.installState;
        if (installState != _lastObservedInstallState) {
          _lastObservedInstallState = installState;
          if (installState == UpdateInstallState.idle) {
            // startInstall() briefly resets to idle before starting; clear guards
            // so subsequent state transitions trigger fresh SnackBars.
            _shownProgressSnackBar = false;
            _shownDoneSnackBar = false;
            _shownFailedSnackBar = false;
          } else if (installState == UpdateInstallState.downloading &&
              !_shownProgressSnackBar) {
            _shownProgressSnackBar = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showDownloadingSnackBar(context, settingsProvider);
            });
          } else if (installState == UpdateInstallState.installing &&
              !_shownProgressSnackBar &&
              _isDesktopRuntime) {
            _shownProgressSnackBar = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showInstallingSnackBar(context);
            });
          } else if (installState == UpdateInstallState.done &&
              !_shownDoneSnackBar) {
            _shownDoneSnackBar = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showDoneSnackBar(context, settingsProvider);
            });
          } else if (installState == UpdateInstallState.failed &&
              !_shownFailedSnackBar) {
            _shownFailedSnackBar = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showFailedSnackBar(context, settingsProvider);
            });
          }
        }

        return const ChatPage();
      },
    );
  }

  bool get _isDesktopRuntime =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Shows a one-time SnackBar when a startup update check finds a newer version.
  /// The action installs directly when supported, otherwise opens the release.
  void _showUpdateToast(
    BuildContext context,
    SettingsProvider settingsProvider,
    UpdateCheckResult result,
  ) {
    if (!mounted) return;
    final canInstallDirectly = settingsProvider.canInstallUpdateDirectly(
      result,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.appShellUpdateAvailableResult(result.latestVersion),
        ),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        action: canInstallDirectly
            ? SnackBarAction(
                label: context.l10n.appShellInstall,
                onPressed: () => unawaited(settingsProvider.startInstall()),
              )
            : result.releaseUrl == null
            ? null
            : SnackBarAction(
                label: context.l10n.aboutGitHub,
                onPressed: () => unawaited(_openReleaseUrl(result.releaseUrl!)),
              ),
      ),
    );
  }

  Future<void> _openReleaseUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showInstallingSnackBar(BuildContext context) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        showCloseIcon: true,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(context.l10n.appShellInstallingUpdate),
          ],
        ),
      ),
    );
  }

  /// Shows a persistent SnackBar while the APK is being downloaded.
  void _showDownloadingSnackBar(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 1), // dismissed programmatically
        showCloseIcon: true,
        content: ListenableBuilder(
          listenable: settingsProvider,
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.appShellDownloadingUpdate),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: settingsProvider.installProgress > 0
                    ? settingsProvider.installProgress
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a SnackBar confirming the desktop update was applied.
  void _showDoneSnackBar(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final isDesktop = _isDesktopRuntime;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isDesktop
              ? context.l10n.appShellUpdateInstalledRestartRequired
              : context.l10n.appShellUpdateInstalledRestartApp,
        ),
        duration: const Duration(seconds: 10),
        showCloseIcon: true,
        action: isDesktop
            ? SnackBarAction(
                label: context.l10n.appShellRestart,
                onPressed: () =>
                    unawaited(settingsProvider.restartDesktopApp()),
              )
            : null,
      ),
    );
  }

  /// Shows a SnackBar when the install failed, with a retry action.
  void _showFailedSnackBar(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.appShellInstallFailed),
        duration: const Duration(seconds: 8),
        showCloseIcon: true,
        action: SnackBarAction(
          label: context.l10n.chatRetry2,
          onPressed: () {
            // Guards are cleared by the idle→downloading state transition in the builder.
            unawaited(settingsProvider.startInstall());
          },
        ),
      ),
    );
  }
}
