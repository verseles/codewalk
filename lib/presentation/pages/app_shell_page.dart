import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../../core/tailscale/tailscale_state.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../services/desktop_tray_service.dart';
import '../services/desktop_tray_service_types.dart';
import '../services/stt_model_download_tracker.dart';
import '../services/update_check_service.dart';
import '../utils/app_page_route.dart';
import '../widgets/app_indeterminate_progress.dart';
import 'chat_page.dart';
import 'onboarding_wizard_page.dart';
import 'settings_page.dart';

/// Cold-start loading hint for the Tailscale bring-up that gates provider
/// initialization. Pure mapping so it stays unit-testable without pumping.
enum ColdStartTailscaleHint {
  connecting,
  loginRequired,
  adminApproval,
}

ColdStartTailscaleHint? coldStartTailscaleHint({
  required bool tailscaleActive,
  required TailscaleNodeState nodeState,
}) {
  if (!tailscaleActive) return null;
  return switch (nodeState) {
    TailscaleNodeState.connecting => ColdStartTailscaleHint.connecting,
    TailscaleNodeState.needsLogin => ColdStartTailscaleHint.loginRequired,
    TailscaleNodeState.needsMachineAuth =>
      ColdStartTailscaleHint.adminApproval,
    TailscaleNodeState.disconnected ||
    TailscaleNodeState.connected ||
    TailscaleNodeState.error ||
    TailscaleNodeState.unsupported => null,
  };
}

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
  // Ensures the startup What's-new toast is shown at most once per session.
  String? _shownStartupNewsVersion;
  // Guards for install-state SnackBars so they are shown at most once each.
  bool _shownProgressSnackBar = false;
  bool _shownDoneSnackBar = false;
  bool _shownFailedSnackBar = false;
  UpdateInstallState _lastObservedInstallState = UpdateInstallState.idle;
  final SttModelDownloadTracker _modelDownloads =
      SttModelDownloadTracker.instance;
  int _lastObservedModelTransition = 0;
  SttModelDownload? _modelResultDuringInstall;

  @override
  void initState() {
    super.initState();
    _modelDownloads.addListener(_handleModelDownloadsChanged);
    if (_modelDownloads.active != null) _handleModelDownloadsChanged();
  }

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
    _modelDownloads.removeListener(_handleModelDownloadsChanged);
    unawaited(_desktopTrayService.dispose());
    super.dispose();
  }

  void _handleSettingsChanged() {
    // Runs on every SettingsProvider notification before the Settings page
    // consumers. _configureDesktopTray catches its own failures, so this
    // listener never throws synchronously and cannot stop later listeners.
    unawaited(_configureDesktopTray());
    final settingsProvider = _settingsProvider;
    if (settingsProvider != null) {
      _observeInstallState(settingsProvider);
    }
  }

  void _observeInstallState(SettingsProvider settingsProvider) {
    final installState = settingsProvider.installState;
    if (installState == _lastObservedInstallState) return;
    _lastObservedInstallState = installState;
    if (installState == UpdateInstallState.idle) {
      _shownProgressSnackBar = false;
      _shownDoneSnackBar = false;
      _shownFailedSnackBar = false;
      _modelResultDuringInstall = null;
    } else if (installState == UpdateInstallState.downloading &&
        !_shownProgressSnackBar) {
      _shownProgressSnackBar = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            settingsProvider.installState == UpdateInstallState.downloading) {
          _showActiveDownloadsSnackBar(context, settingsProvider);
        }
      });
    } else if (installState == UpdateInstallState.installing) {
      if (_isDesktopRuntime && !_shownProgressSnackBar) {
        _shownProgressSnackBar = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_modelDownloads.active != null) {
            _showActiveDownloadsSnackBar(context, settingsProvider);
          } else {
            _showInstallingSnackBar(context);
          }
        });
      } else if (!_isDesktopRuntime) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_modelDownloads.active != null) {
            _showActiveDownloadsSnackBar(context, settingsProvider);
          } else if (_modelResultDuringInstall case final result?) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.clearSnackBars();
            messenger.removeCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: Text(_modelResultText(context, result)),
                duration: const Duration(seconds: 5),
                showCloseIcon: true,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).clearSnackBars();
          }
        });
      }
    } else if (installState == UpdateInstallState.done && !_shownDoneSnackBar) {
      _shownDoneSnackBar = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_modelDownloads.active != null) {
          _showActiveDownloadsSnackBar(context, settingsProvider);
        } else {
          _showDoneSnackBar(context, settingsProvider);
        }
      });
    } else if (installState == UpdateInstallState.failed &&
        !_shownFailedSnackBar) {
      _shownFailedSnackBar = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_modelDownloads.active != null) {
          _showActiveDownloadsSnackBar(context, settingsProvider);
        } else {
          _showFailedSnackBar(context, settingsProvider);
        }
      });
    }
    WidgetsBinding.instance.scheduleFrame();
  }

  void _handleModelDownloadsChanged() {
    if (_modelDownloads.transition == _lastObservedModelTransition) return;
    _lastObservedModelTransition = _modelDownloads.transition;
    final active = _modelDownloads.active;
    final finished = _modelDownloads.lastFinished;
    final settingsProvider = _settingsProvider;
    if (active != null) {
      _modelResultDuringInstall = null;
    } else if (settingsProvider?.installState == UpdateInstallState.downloading ||
        _isDesktopRuntime &&
            settingsProvider?.installState == UpdateInstallState.installing) {
      _modelResultDuringInstall = finished;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentSettings = _settingsProvider;
      if (currentSettings != null &&
          (currentSettings.installState == UpdateInstallState.downloading ||
              _isDesktopRuntime &&
                  currentSettings.installState == UpdateInstallState.installing ||
              active != null &&
                  currentSettings.installState != UpdateInstallState.idle)) {
        _showActiveDownloadsSnackBar(context, currentSettings);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.removeCurrentSnackBar();
      if (active != null) {
        if (currentSettings != null) {
          _showActiveDownloadsSnackBar(context, currentSettings);
        }
      } else if (finished != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentSettings?.installState == UpdateInstallState.done)
                  Text(
                    _isDesktopRuntime
                        ? context.l10n.appShellUpdateInstalledRestartRequired
                        : context.l10n.appShellUpdateInstalledRestartApp,
                  ),
                if (currentSettings?.installState == UpdateInstallState.failed)
                  Text(context.l10n.appShellInstallFailed),
                Text(_modelResultText(context, finished)),
              ],
            ),
            duration: const Duration(seconds: 5),
            showCloseIcon: true,
            action: currentSettings?.installState == UpdateInstallState.done &&
                    _isDesktopRuntime
                ? SnackBarAction(
                    label: context.l10n.appShellRestart,
                    onPressed: () => unawaited(currentSettings!.restartDesktopApp()),
                  )
                : currentSettings?.installState == UpdateInstallState.failed
                ? SnackBarAction(
                    label: context.l10n.chatRetry2,
                    onPressed: () => unawaited(currentSettings!.startInstall()),
                  )
                : null,
          ),
        );
      }
    });
    // This listener also runs while AppShellPage is offstage behind Settings;
    // addPostFrameCallback alone does not schedule a frame in that case.
    WidgetsBinding.instance.scheduleFrame();
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
          final hint = coldStartTailscaleHint(
            tailscaleActive:
                appProvider.activeServer?.tailscaleEnabled ?? false,
            nodeState: appProvider.tailscaleNodeState,
          );
          final hintText = switch (hint) {
            ColdStartTailscaleHint.connecting =>
              context.l10n.serversTailscaleConnecting,
            ColdStartTailscaleHint.loginRequired =>
              context.l10n.onboardingTailscaleLoginRequired,
            ColdStartTailscaleHint.adminApproval =>
              context.l10n.onboardingTailscaleAdminApproval,
            null => null,
          };
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIndeterminateRing(),
                  if (hintText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      hintText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
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
        } else if (settingsProvider.pendingStartupNewsToast &&
            settingsProvider.hasUnseenNews) {
          // What's-new toast only when no update toast fired above. Ack here
          // so hourly re-checks cannot leave a stale flag behind.
          settingsProvider.acknowledgeStartupNewsToast();
          final newsResult = settingsProvider.latestRelease;
          if (newsResult != null &&
              newsResult.latestVersion != _shownStartupNewsVersion) {
            _shownStartupNewsVersion = newsResult.latestVersion;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNewsToast(context, newsResult);
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
    if (!mounted || settingsProvider.installState != UpdateInstallState.idle) {
      return;
    }
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

  /// Shows a one-time SnackBar with the latest release announcement.
  /// Visual only: dismissing it does not persist the news dismissal.
  /// The More action opens the Settings landing with the full text.
  void _showNewsToast(BuildContext context, UpdateCheckResult result) {
    if (!mounted) return;
    final announcement = result.announcement;
    if (announcement == null || announcement.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          announcement.length > 120
              ? '${announcement.substring(0, 120)}...'
              : announcement,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 6),
        showCloseIcon: true,
        action: SnackBarAction(
          label: context.l10n.appShellNewsMore,
          onPressed: () => unawaited(_openSettings(context)),
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => const SettingsPage()));
  }

  void _showInstallingSnackBar(BuildContext context) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        showCloseIcon: true,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: AppIndeterminateRing(size: 16, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(context.l10n.appShellInstallingUpdate),
          ],
        ),
      ),
    );
  }

  /// Keeps every active transfer visible in the root messenger across routes.
  void _showActiveDownloadsSnackBar(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1), // dismissed programmatically
        showCloseIcon: true,
        action: settingsProvider.installState == UpdateInstallState.done &&
                _isDesktopRuntime &&
                _modelDownloads.active == null
            ? SnackBarAction(
                label: context.l10n.appShellRestart,
                onPressed: () => unawaited(settingsProvider.restartDesktopApp()),
              )
            : settingsProvider.installState == UpdateInstallState.failed
            ? SnackBarAction(
                label: context.l10n.chatRetry2,
                onPressed: () => unawaited(settingsProvider.startInstall()),
              )
            : null,
        content: ListenableBuilder(
          listenable: Listenable.merge([settingsProvider, _modelDownloads]),
          builder: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settingsProvider.installState == UpdateInstallState.downloading) ...[
                Text(context.l10n.appShellDownloadingUpdate),
                const SizedBox(height: 4),
                settingsProvider.installProgress > 0
                    ? LinearProgressIndicator(value: settingsProvider.installProgress)
                    : const AppIndeterminateBar(),
              ],
              if (_modelDownloads.active case final model?) ...[
                if (settingsProvider.installState == UpdateInstallState.downloading)
                  const SizedBox(height: 8),
                Text('${context.l10n.speechDownload}: ${model.modelId}'),
                const SizedBox(height: 4),
                model.progress > 0
                    ? LinearProgressIndicator(value: model.progress)
                    : const AppIndeterminateBar(),
              ],
              if (_modelDownloads.active == null &&
                  _modelResultDuringInstall != null)
                Text(_modelResultText(context, _modelResultDuringInstall!)),
              if (_modelDownloads.active != null &&
                  settingsProvider.installState == UpdateInstallState.failed)
                Text(context.l10n.appShellInstallFailed),
              if (settingsProvider.installState == UpdateInstallState.installing &&
                  _isDesktopRuntime)
                Text(context.l10n.appShellInstallingUpdate),
              if (_modelDownloads.active != null &&
                  settingsProvider.installState == UpdateInstallState.done)
                Text(
                  _isDesktopRuntime
                      ? context.l10n.appShellUpdateInstalledRestartRequired
                      : context.l10n.appShellUpdateInstalledRestartApp,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _modelResultText(BuildContext context, SttModelDownload result) =>
      result.failed
          ? context.l10n.speechDownloadFailed(result.modelId)
          : context.l10n.speechModelInstalled(result.modelId);

  /// Shows a SnackBar confirming the desktop update was applied.
  void _showDoneSnackBar(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    final isDesktop = _isDesktopRuntime;
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDesktop
                  ? context.l10n.appShellUpdateInstalledRestartRequired
                  : context.l10n.appShellUpdateInstalledRestartApp,
            ),
            if (_modelResultDuringInstall case final result?)
              Text(_modelResultText(context, result)),
          ],
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.appShellInstallFailed),
            if (_modelResultDuringInstall case final result?)
              Text(_modelResultText(context, result)),
          ],
        ),
        duration: const Duration(seconds: 8),
        showCloseIcon: true,
        action: SnackBarAction(
          label: context.l10n.chatRetry2,
          onPressed: () {
            // Guards are cleared by the idle→downloading state transition.
            unawaited(settingsProvider.startInstall());
          },
        ),
      ),
    );
  }
}
