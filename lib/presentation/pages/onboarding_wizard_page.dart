import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/l10n_context.dart';
import '../../core/tailscale/tailscale_service.dart';
import '../../domain/entities/server_profile.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../services/local_opencode_server_runtime_types.dart';
import '../theme/app_animations.dart';
import '../utils/app_page_route.dart';
import '../widgets/modal_primary_action_shortcuts.dart';
import 'opencode_setup_debug_page.dart';
import 'server_settings_page.dart';
import 'settings/sections/servers_settings_section.dart';

enum SetupWizardInitialFlow {
  choose,
  connectServer,
  guidedServerSetup,
  managedLocalServer,
}

/// First-run onboarding wizard that guides users through initial server setup.
/// Shown when no server profiles exist and skipOnboardingWizard is false.
class OnboardingWizardPage extends StatefulWidget {
  const OnboardingWizardPage({
    super.key,
    this.onComplete,
    this.showSkipAction = true,
    this.initialFlow = SetupWizardInitialFlow.choose,
    this.initialServerProfile,
  });

  /// Called when the wizard completes (server configured or skipped).
  /// When null, the gate in AppShellPage handles navigation automatically.
  final VoidCallback? onComplete;

  /// Whether the AppBar should expose the onboarding skip action.
  final bool showSkipAction;

  /// Entry flow for this wizard when launched from settings shortcuts.
  final SetupWizardInitialFlow initialFlow;

  /// Optional server profile to edit in-place instead of creating a new one.
  final ServerProfile? initialServerProfile;

  @override
  State<OnboardingWizardPage> createState() => _OnboardingWizardPageState();
}

class _OnboardingWizardPageState extends State<OnboardingWizardPage> {
  int _step = 0;
  bool _showQuickGuide = false;
  bool _connectionSuccess = false;
  bool _readyFromManagedLocal = false;
  bool _completing = false;
  String? _connectionError;
  bool _testing = false;
  bool _completingWithSavedServer = false;
  // Generation guard for issue #177: every save/test run captures an ID and
  // stale completions (after Cancel/edit/dispose) must not touch UI state.
  int _testGeneration = 0;
  CancelToken? _testCancelToken;
  // Manual URL override while Tailscale gating is active (issue #177 1B).
  bool _tailscaleUrlManualOverride = false;
  // ID of the server profile added during this wizard session, so "Try again"
  // re-tests health instead of attempting a duplicate addServerProfile.
  String? _addedServerId;
  String? _editingServerId;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _basicAuthEnabled = false;
  bool _oauthEnabled = false;
  bool _tailscaleEnabled = false;
  bool _aiGeneratedTitlesEnabled = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _urlController.text = _suggestedServerUrl;
    _configureInitialFlow();
  }

  String get _suggestedServerUrl {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:4096' : 'http://127.0.0.1:4096';
  }

  bool get _oauthSupported => AppProvider.supportsCloudflareAccessOAuth;

  bool get _tailscaleSupported => AppProvider.supportsTailscale;

  bool get _isFirstRunFlow =>
      widget.showSkipAction &&
      widget.initialFlow == SetupWizardInitialFlow.choose &&
      widget.initialServerProfile == null;

  void _configureInitialFlow() {
    final initialProfile = widget.initialServerProfile;
    if (initialProfile != null) {
      _editingServerId = initialProfile.id;
      _urlController.text = initialProfile.url;
      _labelController.text = initialProfile.label ?? '';
      _usernameController.text = initialProfile.basicAuthUsername;
      _passwordController.text = initialProfile.basicAuthPassword;
      _basicAuthEnabled = initialProfile.basicAuthEnabled;
      _oauthEnabled = initialProfile.oauthEnabled;
      _tailscaleEnabled = initialProfile.tailscaleEnabled;
      _aiGeneratedTitlesEnabled = initialProfile.aiGeneratedTitlesEnabled;
      _step = 1;
      return;
    }

    switch (widget.initialFlow) {
      case SetupWizardInitialFlow.choose:
        _step = 0;
        break;
      case SetupWizardInitialFlow.connectServer:
        _step = 1;
        _showQuickGuide = false;
        break;
      case SetupWizardInitialFlow.guidedServerSetup:
        _step = 1;
        _showQuickGuide = true;
        break;
      case SetupWizardInitialFlow.managedLocalServer:
        _step = 3;
        _scheduleLocalDiagnostics();
        break;
    }
  }

  @override
  void dispose() {
    // Issue #177: invalidate any in-flight test so late completions stay inert.
    _testGeneration++;
    _testCancelToken?.cancel('Disposed');
    _testCancelToken = null;
    _urlController.dispose();
    _labelController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Whether the Server URL field is gated by pending Tailscale transport.
  /// Decision 1B: disabled while Tailscale is enabled but not connected,
  /// unless the user opted into manual override. Decision 3B keeps auth
  /// explicit: toggling never auto-starts the node.
  bool _isTailscaleUrlGated(AppProvider appProvider) {
    return _tailscaleEnabled &&
        _tailscaleSupported &&
        !appProvider.tailscaleState.isConnected &&
        !_tailscaleUrlManualOverride;
  }

  bool _isStaleTestRun(int generation) {
    return generation != _testGeneration;
  }

  /// Issue #177: Cancel button + abort-on-edit. Releases the form instantly;
  /// the in-flight health probe is aborted via CancelToken and its late
  /// result is ignored through the generation guard. Never logs out or
  /// disconnects the shared Tailscale identity.
  void _cancelRunningTest() {
    if (!_testing) {
      // Still bump so a just-finished future cannot apply stale state.
      _testGeneration++;
      _testCancelToken?.cancel('Cancelled by user');
      _testCancelToken = null;
      return;
    }
    _testGeneration++;
    _testCancelToken?.cancel('Cancelled by user');
    _testCancelToken = null;
    setState(() {
      _testing = false;
      _connectionError = null;
    });
  }

  void _onServerFormFieldChanged() {
    if (_testing) {
      _cancelRunningTest();
    } else {
      setState(() {});
    }
  }

  void _handleBack() {
    if (_completing) {
      return;
    }
    if (_testing) {
      _cancelRunningTest();
    }
    if (_step == 0) {
      if (widget.showSkipAction) {
        _handleSkip();
        return;
      }
      unawaited(_complete());
      return;
    }
    setState(() {
      if (_step == 2) {
        final previousStep = _readyFromManagedLocal ? 3 : 1;
        _connectionSuccess = false;
        _readyFromManagedLocal = false;
        _connectionError = null;
        _step = previousStep;
        return;
      }
      if (_step == 3) {
        _step = 0;
        return;
      }
      _step--;
    });
  }

  Future<void> _handleSkip() async {
    if (!widget.showSkipAction) {
      unawaited(_complete());
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var dontShowAgain = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitSkip() {
              if (dontShowAgain) {
                unawaited(
                  context.read<SettingsProvider>().setSkipOnboardingWizard(
                    true,
                  ),
                );
              }
              Navigator.of(dialogContext).pop(true);
            }

            return ModalPrimaryActionShortcuts(
              autofocus: true,
              onPrimaryAction: submitSkip,
              child: AlertDialog(
                title: Text(context.l10n.onboardingSkipSetup),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.onboardingAddServerLater),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: dontShowAgain,
                      onChanged: (value) {
                        setDialogState(() {
                          dontShowAgain = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(context.l10n.onboardingDonShowAgain),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(context.l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: submitSkip,
                    child: Text(context.l10n.tourSkip),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      unawaited(_complete());
    }
  }

  Future<void> _complete() async {
    if (!mounted || _completing) {
      return;
    }
    setState(() {
      _completing = true;
    });

    final completingManagedLocal = _readyFromManagedLocal;
    final appProvider = context.read<AppProvider>();
    if (completingManagedLocal &&
        appProvider.localServerStatus != LocalServerRuntimeStatus.running) {
      _returnToManagedLocalSetup();
      return;
    }

    if (_connectionSuccess &&
        widget.showSkipAction &&
        _editingServerId == null) {
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.setPendingPostOnboardingChatTour(true);
      if (!mounted) {
        return;
      }
      if (completingManagedLocal &&
          appProvider.localServerStatus != LocalServerRuntimeStatus.running) {
        await settingsProvider.setPendingPostOnboardingChatTour(false);
        if (mounted) {
          _returnToManagedLocalSetup();
        }
        return;
      }
    }
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (mounted) {
      setState(() {
        _completing = false;
      });
    }
    // When launched from AppShellPage gate, navigation happens automatically
    // via the Consumer2 rebuild when server profiles change.
  }

  void _goToConnectServer() {
    context.read<AppProvider>().recordSetupDebugEvent(
      source: context.l10n.setupDebugSourceOnboarding,
      message: context.l10n.setupDebugMessageOnboardingConnectExisting,
    );
    setState(() {
      _readyFromManagedLocal = false;
      _showQuickGuide = false;
      _step = 1;
    });
  }

  void _goToNeedHelp() {
    context.read<AppProvider>().recordSetupDebugEvent(
      source: context.l10n.setupDebugSourceOnboarding,
      message: context.l10n.setupDebugMessageOnboardingGuidedPath,
    );
    setState(() {
      _readyFromManagedLocal = false;
      _showQuickGuide = true;
      _step = 1;
    });
  }

  void _goToLocalManagedSetup() {
    context.read<AppProvider>().recordSetupDebugEvent(
      source: context.l10n.setupDebugSourceOnboarding,
      message: context.l10n.setupDebugMessageOnboardingManagedLocal,
    );
    setState(() {
      _readyFromManagedLocal = false;
      _step = 3;
      _connectionError = null;
    });
    _scheduleLocalDiagnostics();
  }

  void _scheduleLocalDiagnostics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_runLocalDiagnostics());
    });
  }

  void _goToReadyFromManagedLocal() {
    if (!mounted ||
        context.read<AppProvider>().localServerStatus !=
            LocalServerRuntimeStatus.running) {
      return;
    }
    setState(() {
      _connectionSuccess = true;
      _readyFromManagedLocal = true;
      _connectionError = null;
      _step = 2;
    });
  }

  Future<void> _startManagedLocalServer() async {
    final appProvider = context.read<AppProvider>();
    final ok = await appProvider.startLocalServer();
    if (!mounted) {
      return;
    }
    if (!ok) {
      _showMessage(appProvider.errorMessage);
      return;
    }
    if (_isFirstRunFlow && _step == 3) {
      _goToReadyFromManagedLocal();
    }
  }

  void _returnToManagedLocalSetup() {
    if (!mounted) {
      return;
    }
    setState(() {
      _completing = false;
      _connectionSuccess = false;
      _readyFromManagedLocal = false;
      _connectionError = null;
      _step = 3;
    });
  }

  Future<void> _runLocalDiagnostics() async {
    final appProvider = context.read<AppProvider>();
    await appProvider.runLocalServerDiagnostics();
  }

  Future<void> _openSetupDebugPage() async {
    await Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => const OpenCodeSetupDebugPage()));
  }

  Future<void> _openServerSettings() async {
    context.read<AppProvider>().recordSetupDebugEvent(
      source: context.l10n.setupDebugSourceOnboarding,
      message: context.l10n.setupDebugMessageOnboardingOpenedServerSettings,
    );
    await Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => const ServerSettingsPage()));
  }

  Future<void> _continueWithSavedServer() async {
    if (_completingWithSavedServer) {
      return;
    }
    setState(() {
      _completingWithSavedServer = true;
    });

    final appProvider = context.read<AppProvider>();
    final serverId = _resolveSavedServerId(appProvider);
    if (serverId != null) {
      final activated = await appProvider.setActiveServer(
        serverId,
        blockUnhealthy: false,
      );
      if (!mounted) {
        return;
      }
      if (!activated) {
        setState(() {
          _completingWithSavedServer = false;
        });
        _showMessage(appProvider.errorMessage);
        return;
      }
    }
    if (!mounted) {
      return;
    }
    await _complete();
  }

  String? _resolveSavedServerId(AppProvider appProvider) {
    final candidates = <String?>[
      appProvider.activeServerId,
      _editingServerId,
      _addedServerId,
    ];
    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final exists = appProvider.serverProfiles.any(
        (profile) => profile.id == candidate,
      );
      if (exists) {
        return candidate;
      }
    }
    return null;
  }

  void _addAnotherServerAfterFailure() {
    context.read<AppProvider>().recordSetupDebugEvent(
      source: context.l10n.setupDebugSourceOnboarding,
      message: context.l10n.setupDebugMessageOnboardingAddAnotherServer,
    );
    _testGeneration++;
    _testCancelToken?.cancel('Reset form');
    _testCancelToken = null;
    setState(() {
      _addedServerId = null;
      _editingServerId = null;
      _testing = false;
      _tailscaleUrlManualOverride = false;
      _urlController.text = _suggestedServerUrl;
      _labelController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _basicAuthEnabled = false;
      _oauthEnabled = false;
      _tailscaleEnabled = false;
      _aiGeneratedTitlesEnabled = true;
      _showQuickGuide = false;
      _connectionSuccess = false;
      _readyFromManagedLocal = false;
      _connectionError = null;
      _step = 1;
    });
  }

  Future<void> _testConnection() async {
    final gateProvider = context.read<AppProvider>();
    // Defensive: Test is disabled while Tailscale-gated, but never probe
    // a gated empty state even if triggered programmatically.
    if (_isTailscaleUrlGated(gateProvider)) return;
    if (_formKey.currentState?.validate() != true) return;

    final generation = ++_testGeneration;
    final cancelToken = CancelToken();
    // Cancel any previous token before adopting the new one.
    _testCancelToken?.cancel('Superseded by retry');
    _testCancelToken = cancelToken;

    setState(() {
      _testing = true;
      _connectionError = null;
    });

    final appProvider = context.read<AppProvider>();
    final adjustedUrl = _mapAndroidLoopback(_urlController.text.trim());
    final label = _labelController.text.trim();
    appProvider.recordSetupDebugEvent(
      source: context.l10n.setupDebugSourceManualConnection,
      message: context.l10n.setupDebugMessageTestingServerUrl(adjustedUrl),
    );
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final oauthEnabled = _oauthEnabled && _oauthSupported;
    final tailscaleEnabled = _tailscaleEnabled && _tailscaleSupported;

    void clearTokenIfCurrent() {
      if (identical(_testCancelToken, cancelToken)) {
        _testCancelToken = null;
      }
    }

    final trackedServerId = _editingServerId ?? _addedServerId;
    final hasTrackedServer =
        trackedServerId != null &&
        appProvider.serverProfiles.any(
          (profile) => profile.id == trackedServerId,
        );

    // If this wizard already created a server profile, update/re-check the same
    // profile instead of attempting to add a duplicate URL.
    if (hasTrackedServer) {
      final updated = await appProvider.updateServerProfile(
        id: trackedServerId,
        url: adjustedUrl,
        label: label,
        basicAuthEnabled: _basicAuthEnabled,
        basicAuthUsername: username,
        basicAuthPassword: password,
        oauthEnabled: oauthEnabled,
        tailscaleEnabled: tailscaleEnabled,
        aiGeneratedTitlesEnabled: _aiGeneratedTitlesEnabled,
        healthCancelToken: cancelToken,
      );
      if (!mounted || _isStaleTestRun(generation)) return;
      if (!updated) {
        appProvider.recordSetupDebugEvent(
          source: context.l10n.setupDebugSourceManualConnection,
          message: appProvider.errorMessage,
          severity: SetupDebugSeverity.error,
        );
        clearTokenIfCurrent();
        setState(() {
          _testing = false;
          _connectionError = appProvider.errorMessage;
        });
        return;
      }

      if (oauthEnabled) {
        final authenticated = await appProvider.handleOAuthChallenge(
          serverUrl: adjustedUrl,
        );
        if (!mounted || _isStaleTestRun(generation)) return;
        if (!authenticated) {
          final detail = appProvider.errorMessage.trim();
          clearTokenIfCurrent();
          setState(() {
            _testing = false;
            _connectionError = detail.isNotEmpty
                ? detail
                : context.l10n.onboardingCloudflareAuthFailed;
          });
          return;
        }
      }

      final health = appProvider.healthFor(trackedServerId);
      final healthMessage = health == ServerHealthStatus.unhealthy
          ? context.l10n.onboardingHealthCheckFailedMayBeStarting
          : context.l10n.onboardingConnectionUpdated;
      appProvider.recordSetupDebugEvent(
        source: context.l10n.setupDebugSourceManualConnection,
        message: healthMessage,
        severity: health == ServerHealthStatus.unhealthy
            ? SetupDebugSeverity.error
            : SetupDebugSeverity.info,
      );
      clearTokenIfCurrent();
      setState(() {
        _testing = false;
        _connectionSuccess = health != ServerHealthStatus.unhealthy;
        _readyFromManagedLocal = false;
        _connectionError = health == ServerHealthStatus.unhealthy
            ? context.l10n.onboardingHealthCheckFailedMayBeStarting
            : null;
        _step = 2;
      });
      return;
    }

    final existingServerIds = appProvider.serverProfiles
        .map((profile) => profile.id)
        .toSet();
    final success = await appProvider.addServerProfile(
      url: adjustedUrl,
      label: label,
      basicAuthEnabled: _basicAuthEnabled,
      basicAuthUsername: username,
      basicAuthPassword: password,
      oauthEnabled: oauthEnabled,
      tailscaleEnabled: tailscaleEnabled,
      aiGeneratedTitlesEnabled: _aiGeneratedTitlesEnabled,
      setAsActive: true,
      healthCancelToken: cancelToken,
    );

    String? serverId;
    for (final profile in appProvider.serverProfiles.reversed) {
      if (!existingServerIds.contains(profile.id)) {
        serverId = profile.id;
        break;
      }
    }
    serverId ??= appProvider.activeServerId;
    serverId ??= appProvider.serverProfiles.isNotEmpty
        ? appProvider.serverProfiles.last.id
        : null;

    // Record the new profile even on a stale run so a retry after Cancel
    // updates the same profile instead of creating a duplicate.
    if (_editingServerId == null && serverId != null) {
      _addedServerId = serverId;
    }
    if (!mounted || _isStaleTestRun(generation)) return;

    if (success) {
      if (oauthEnabled) {
        final authenticated = await appProvider.handleOAuthChallenge(
          serverUrl: adjustedUrl,
        );
        if (!mounted || _isStaleTestRun(generation)) return;
        if (!authenticated) {
          final detail = appProvider.errorMessage.trim();
          clearTokenIfCurrent();
          setState(() {
            _testing = false;
            _connectionError = detail.isNotEmpty
                ? detail
                : context.l10n.onboardingCloudflareAuthFailed;
          });
          return;
        }
      }

      final health = serverId == null
          ? ServerHealthStatus.unhealthy
          : appProvider.healthFor(serverId);
      final healthMessage = health == ServerHealthStatus.unhealthy
          ? context.l10n.onboardingAddedButHealthCheckFailed
          : context.l10n.onboardingConnectionSaved;
      appProvider.recordSetupDebugEvent(
        source: context.l10n.setupDebugSourceManualConnection,
        message: healthMessage,
        severity: health == ServerHealthStatus.unhealthy
            ? SetupDebugSeverity.error
            : SetupDebugSeverity.info,
      );
      clearTokenIfCurrent();
      setState(() {
        _testing = false;
        _connectionSuccess = health != ServerHealthStatus.unhealthy;
        _readyFromManagedLocal = false;
        _connectionError = health == ServerHealthStatus.unhealthy
            ? context.l10n.onboardingAddedButHealthCheckFailed
            : null;
        _step = 2;
      });
    } else {
      appProvider.recordSetupDebugEvent(
        source: context.l10n.setupDebugSourceManualConnection,
        message: appProvider.errorMessage,
        severity: SetupDebugSeverity.error,
      );
      clearTokenIfCurrent();
      setState(() {
        _testing = false;
        _connectionError = appProvider.errorMessage;
      });
    }
  }

  String _mapAndroidLoopback(String input) {
    var normalized = input.trim();
    try {
      normalized = AppProvider.normalizeServerUrl(normalized);
    } catch (_) {
      return input.trim();
    }

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return normalized;

    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;
    final isLoopback =
        uri.host == '127.0.0.1' || uri.host.toLowerCase() == 'localhost';
    if (!isLoopback) return normalized;

    return Uri(scheme: uri.scheme, host: '10.0.2.2', port: uri.port).toString();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.msgCommandCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final canNavigateBack = _step > 0 || !widget.showSkipAction;
    final maxWidth = _step == 3 ? 760.0 : 560.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titleForCurrentStep()),
          automaticallyImplyLeading: false,
          leading: canNavigateBack
              ? IconButton(
                  icon: const Icon(Symbols.arrow_back),
                  onPressed: _handleBack,
                )
              : null,
          actions: [
            if (widget.showSkipAction && (_step < 2 || !_connectionSuccess))
              TextButton(
                onPressed: _handleSkip,
                child: Text(context.l10n.tourSkip),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: AnimatedSwitcher(
                duration: AppAnimations.emphasized,
                switchInCurve: AppAnimations.emphasizedCurve,
                switchOutCurve: AppAnimations.accelerateCurve,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleForCurrentStep() {
    return switch (_step) {
      0 =>
        widget.showSkipAction
            ? context.l10n.onboardingSetup
            : context.l10n.onboardingSetupWizard,
      1 =>
        _editingServerId == null
            ? context.l10n.onboardingServerSetup
            : context.l10n.onboardingEditServer,
      2 =>
        _connectionSuccess
            ? context.l10n.onboardingReady
            : context.l10n.onboardingConnectionIssue,
      3 => context.l10n.onboardingLocalServerSetup,
      _ => context.l10n.onboardingSetup,
    };
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _buildWelcomeStep(),
      1 => _buildServerSetupStep(),
      2 => _buildReadyStep(),
      3 => _buildLocalSetupStep(),
      _ => _buildWelcomeStep(),
    };
  }

  // -- Step 0: Welcome --

  Widget _buildWelcomeStep() {
    final supportsLocalManaged = context.select<AppProvider, bool>(
      (provider) => provider.localServerSupported,
    );

    if (_isFirstRunFlow) {
      return _buildFirstRunWelcomeStep(supportsLocalManaged);
    }
    return _buildSetupChooserStep(supportsLocalManaged);
  }

  Widget _buildFirstRunWelcomeStep(bool supportsLocalManaged) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final primaryButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );
    final secondaryButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );
    final tertiaryButtonStyle = TextButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );

    return SingleChildScrollView(
      key: const ValueKey('step_welcome'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: Icon(
              Symbols.code_rounded,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.onboardingWelcomeTo(AppConstants.appName),
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.onboardingNeedsOpenCodeServer(AppConstants.appName),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.onboardingCodeWalkAppOpenCode,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (supportsLocalManaged) ...[
            FilledButton.icon(
              key: const ValueKey('first_run_primary_setup_action'),
              onPressed: _goToLocalManagedSetup,
              style: primaryButtonStyle,
              icon: const Icon(Symbols.computer),
              label: Text(context.l10n.onboardingLetCodeWalkSet),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('first_run_connect_server_action'),
              onPressed: _goToConnectServer,
              style: secondaryButtonStyle,
              icon: const Icon(Symbols.dns_rounded),
              label: Text(context.l10n.onboardingConnectRunningServer),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              key: const ValueKey('first_run_guided_setup_action'),
              onPressed: _goToNeedHelp,
              style: tertiaryButtonStyle,
              icon: const Icon(Symbols.help_outline_rounded),
              label: Text(context.l10n.onboardingShowSetupSteps),
            ),
          ] else ...[
            FilledButton.icon(
              key: const ValueKey('first_run_primary_setup_action'),
              onPressed: _goToNeedHelp,
              style: primaryButtonStyle,
              icon: const Icon(Symbols.help_outline_rounded),
              label: Text(context.l10n.onboardingShowSetupSteps),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('first_run_connect_server_action'),
              onPressed: _goToConnectServer,
              style: secondaryButtonStyle,
              icon: const Icon(Symbols.dns_rounded),
              label: Text(context.l10n.onboardingConnectRunningServer),
            ),
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            key: const ValueKey('what_is_opencode_tile'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            leading: Icon(Symbols.info_rounded, color: colorScheme.primary),
            title: Text(context.l10n.onboardingOpenCode),
            children: [
              Text(
                context.l10n.onboardingOpenCodeRunsLocally,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetupChooserStep(bool supportsLocalManaged) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.showSkipAction
        ? context.l10n.onboardingWelcomeTo(AppConstants.appName)
        : context.l10n.onboardingChooseHowToSetup;
    final subtitle = widget.showSkipAction
        ? context.l10n.onboardingNeedsOpenCodeServer(AppConstants.appName)
        : context.l10n.onboardingPickSetupPath;

    return SingleChildScrollView(
      key: const ValueKey('step_welcome'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.code_rounded, size: 72, color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Card(
            child: ExpansionTile(
              key: const ValueKey('what_is_opencode_tile'),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Icon(Symbols.info_rounded, color: colorScheme.primary),
              title: Text(context.l10n.onboardingOpenCode),
              subtitle: Text(context.l10n.onboardingCodeWalkAppOpenCode),
              children: [
                Text(
                  context.l10n.onboardingOpenCodeRunsLocally,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Card(
              color: colorScheme.primaryContainer,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                onTap: _goToConnectServer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.dns_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.onboardingConnectRunningServer,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.onboardingOpenCodeRunningDevice,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Symbols.arrow_forward_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              color: colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                onTap: _goToNeedHelp,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.help_outline_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.onboardingShowSetupSteps,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: colorScheme.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.onboardingExplainInstallOpenCode,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Symbols.arrow_forward_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              color: supportsLocalManaged
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                onTap: supportsLocalManaged ? _goToLocalManagedSetup : null,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.computer,
                        color: supportsLocalManaged
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.onboardingLetCodeWalkSet,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: colorScheme.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              supportsLocalManaged
                                  ? context.l10n.onboardingDesktopOnlyDiagnose(
                                      AppConstants.appName,
                                    )
                                  : context.l10n.onboardingAvailableOnlyDesktop,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (supportsLocalManaged) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  context.l10n.onboardingGoodOptionDesktop,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Symbols.arrow_forward_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Step 1: Server setup --

  Widget _buildServerSetupStep() {
    final hasTrackedServer = _editingServerId != null || _addedServerId != null;

    return SingleChildScrollView(
      key: const ValueKey('step_server_setup'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _step = 0;
                  _connectionError = null;
                });
              },
              icon: const Icon(Symbols.chevron_left_rounded),
              label: Text(context.l10n.onboardingChooseAnotherPath),
            ),
          ),
          const SizedBox(height: 4),
          if (_showQuickGuide) ...[
            Text(
              context.l10n.onboardingAlmostInstallOpenCode,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ServerSetupQuickGuide(onCopy: _copyToClipboard),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () {
                    setState(() {
                      _showQuickGuide = false;
                    });
                  },
                  child: Text(context.l10n.onboardingContinueServerURL),
                ),
                TextButton.icon(
                  key: const ValueKey(
                    'open_code_setup_debug_button_quick_guide',
                  ),
                  onPressed: _openSetupDebugPage,
                  icon: const Icon(Symbols.bug_report_rounded),
                  label: Text(context.l10n.onboardingViewSetupDebug),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          if (!_showQuickGuide) ...[
            Text(
              _editingServerId == null
                  ? context.l10n.onboardingServerConnection
                  : context.l10n.onboardingEditServerConnection,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                key: const ValueKey('server_connection_tips_tile'),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: const Icon(Symbols.info_rounded),
                title: Text(context.l10n.onboardingConnectionTips),
                subtitle: Text(context.l10n.onboardingDefaultURLEmulator),
                children: [
                  _buildSetupHintRow(
                    icon: Symbols.link,
                    text: context.l10n.onboardingSuggestedUrl(
                      _suggestedServerUrl,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSetupHintRow(
                    icon: Symbols.phone_android,
                    text: context.l10n.onboardingEmulatorRemap,
                  ),
                  const SizedBox(height: 8),
                  _buildSetupHintRow(
                    icon: Symbols.lock,
                    text: context.l10n.onboardingBasicAuthTip,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey(
                    'open_code_setup_debug_button_server_form',
                  ),
                  onPressed: _openSetupDebugPage,
                  icon: const Icon(Symbols.bug_report_rounded),
                  label: Text(context.l10n.onboardingViewSetupDebug),
                ),
                TextButton.icon(
                  key: const ValueKey('show_setup_steps_button_server_form'),
                  onPressed: () {
                    setState(() {
                      _showQuickGuide = true;
                    });
                  },
                  icon: const Icon(Symbols.menu_book_rounded),
                  label: Text(context.l10n.onboardingShowSetupSteps2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      value: _tailscaleEnabled,
                      onChanged: _tailscaleSupported
                          ? (value) {
                              if (_testing) {
                                _cancelRunningTest();
                              }
                              setState(() {
                                _tailscaleEnabled = value;
                                _tailscaleUrlManualOverride = false;
                              });
                            }
                          : null,
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.useTailscale),
                      subtitle: Text(
                        _tailscaleSupported
                            ? context.l10n.useTailscaleSubtitle
                            : context.l10n.useTailscaleUnsupported,
                      ),
                    ),
                    if (_tailscaleEnabled) ...[
                      const SizedBox(height: 8),
                      _buildTailscalePeerDropdown(),
                      const SizedBox(height: 12),
                      _buildTailscaleAuthPanel(),
                    ],
                    SwitchListTile(
                      value: _oauthEnabled,
                      onChanged: _oauthSupported
                          ? (value) {
                              if (_testing) {
                                _cancelRunningTest();
                              }
                              setState(() {
                                _oauthEnabled = value;
                                if (value) _basicAuthEnabled = false;
                              });
                            }
                          : null,
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.useOAuthCloudflareAccess),
                      subtitle: Text(
                        _oauthSupported
                            ? context.l10n.useOAuthCloudflareAccessSubtitle
                            : context.l10n.useOAuthCloudflareAccessUnsupported,
                      ),
                    ),
                    SwitchListTile(
                      value: _basicAuthEnabled,
                      onChanged: (value) {
                        if (_testing) {
                          _cancelRunningTest();
                        }
                        setState(() {
                          _basicAuthEnabled = value;
                          if (value) _oauthEnabled = false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.onboardingUseBasicAuth),
                    ),
                    if (_basicAuthEnabled) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: context.l10n.onboardingUsername,
                        ),
                        onChanged: (_) => _onServerFormFieldChanged(),
                        validator: (value) {
                          if (!_basicAuthEnabled) return null;
                          if ((value ?? '').trim().isEmpty) {
                            return context.l10n.onboardingUsernameRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: context.l10n.onboardingPassword,
                        ),
                        obscureText: true,
                        onChanged: (_) => _onServerFormFieldChanged(),
                        validator: (value) {
                          if (!_basicAuthEnabled) return null;
                          if ((value ?? '').trim().isEmpty) {
                            return context.l10n.onboardingPasswordRequired;
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Consumer<AppProvider>(
                      builder: (context, tailscaleProvider, _) {
                        final urlGated = _isTailscaleUrlGated(
                          tailscaleProvider,
                        );
                        final urlEnabled = !_testing && !urlGated;
                        Widget? suffixIcon;
                        if (!urlGated &&
                            _urlController.text.trim().isNotEmpty) {
                          suffixIcon = IconButton(
                            tooltip: context.l10n.onboardingClear,
                            icon: const Icon(Symbols.clear),
                            onPressed: () {
                              _urlController.clear();
                              _onServerFormFieldChanged();
                            },
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              key: const ValueKey('server_url_field'),
                              controller: _urlController,
                              enabled: urlEnabled,
                          decoration: InputDecoration(
                            labelText: context.l10n.onboardingServerUrl,
                            hintText: urlGated
                                ? context.l10n.tailscaleSelectPeer
                                : _suggestedServerUrl,
                            helperText: urlGated
                                ? context
                                      .l10n
                                      .onboardingTailscaleLoginRequired
                                : null,
                            suffixIcon: suffixIcon,
                          ),
                          onChanged: (_) => _onServerFormFieldChanged(),
                          validator: (value) {
                            // While gated, Test is disabled; skip required-URL
                            // validation so the login-first hint stands out.
                            if (_isTailscaleUrlGated(
                              context.read<AppProvider>(),
                            )) {
                              return null;
                            }
                            final raw = value?.trim() ?? '';
                            if (raw.isEmpty) {
                              return context.l10n.onboardingEnterServerUrl;
                            }
                            try {
                              AppProvider.normalizeServerUrl(raw);
                              return null;
                            } catch (_) {
                              return context.l10n.onboardingInvalidUrl;
                            }
                          },
                        ),
                        if (urlGated)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const ValueKey(
                                'server_url_manual_override_button',
                              ),
                              onPressed: () {
                                if (_testing) {
                                  _cancelRunningTest();
                                }
                                setState(() {
                                  _tailscaleUrlManualOverride = true;
                                });
                              },
                              icon: const Icon(Symbols.edit_rounded),
                              label: Text(context.l10n.serversEdit),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        labelText: context.l10n.onboardingLabel,
                        hintText: context.l10n.onboardingLabelHint,
                      ),
                      onChanged: (_) => _onServerFormFieldChanged(),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _aiGeneratedTitlesEnabled,
                      onChanged: (value) {
                        if (_testing) {
                          _cancelRunningTest();
                        }
                        setState(() {
                          _aiGeneratedTitlesEnabled = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.onboardingAIGeneratedTitles),
                      subtitle: Text(context.l10n.onboardingUsesServerTitle),
                    ),
                    const SizedBox(height: 16),
                    if (_connectionError != null) ...[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Symbols.error_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _connectionError!,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Consumer<AppProvider>(
                      builder: (context, testGateProvider, _) {
                        final urlGated = _isTailscaleUrlGated(
                          testGateProvider,
                        );
                        final canTest = !_testing && !urlGated;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('server_test_button'),
                              onPressed: canTest ? _testConnection : null,
                              icon: _testing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Symbols.link_rounded),
                              label: Text(
                                _testing
                                    ? context.l10n.onboardingTesting
                                    : hasTrackedServer
                                    ? context.l10n.onboardingSaveAndTest
                                    : context.l10n.onboardingTestConnection,
                              ),
                            ),
                            if (_testing)
                              OutlinedButton.icon(
                                key: const ValueKey('server_test_cancel_button'),
                                onPressed: _cancelRunningTest,
                                icon: const Icon(Symbols.stop_rounded),
                                label: Text(context.l10n.commonCancel),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTailscaleAuthPanel() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final state = appProvider.tailscaleState;
        final authUrl = state.authUrl?.toString();
        final colorScheme = Theme.of(context).colorScheme;
        final title = switch (state.nodeState) {
          TailscaleNodeState.needsLogin =>
            context.l10n.onboardingTailscaleLoginRequired,
          TailscaleNodeState.needsMachineAuth =>
            context.l10n.onboardingTailscaleAdminApproval,
          TailscaleNodeState.connected =>
            context.l10n.onboardingTailscaleConnected,
          TailscaleNodeState.connecting =>
            context.l10n.onboardingTailscaleConnecting,
          TailscaleNodeState.error =>
            context.l10n.onboardingTailscaleConnectionFailed,
          TailscaleNodeState.unsupported =>
            context.l10n.onboardingTailscaleUnsupported,
          TailscaleNodeState.disconnected =>
            context.l10n.onboardingTailscaleAuthAfterSave,
        };
        final message =
            state.message ??
            (state.requiresUserLogin
                ? context.l10n.onboardingTailscaleOpenLoginUrl
                : context.l10n.onboardingTailscaleAuthAfterSaveTest(
                    AppConstants.appName,
                  ));

        return Card(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                if (authUrl != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    authUrl,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
                if (state.requiresUserLogin ||
                    authUrl != null ||
                    state.nodeState == TailscaleNodeState.error) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (state.nodeState != TailscaleNodeState.connecting &&
                          state.nodeState != TailscaleNodeState.error)
                        FilledButton.icon(
                          onPressed: appProvider.tailscaleBusy
                              ? null
                              : () async {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final openLoginMessage = context
                                      .l10n.onboardingOpenTailscaleLogin;
                                  final ok = await appProvider
                                      .authenticateTailscale();
                                  if (!mounted) return;
                                  if (!ok) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: Text(openLoginMessage)),
                                    );
                                  }
                                },
                          icon: appProvider.tailscaleAuthBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Symbols.open_in_browser_rounded),
                          label: Text(context.l10n.onboardingAuthenticate),
                        ),
                      if (authUrl != null)
                        OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(authUrl),
                          icon: const Icon(Symbols.content_copy_rounded),
                          label: Text(context.l10n.onboardingCopyLoginURL),
                        ),
                      if (state.nodeState == TailscaleNodeState.error)
                        OutlinedButton.icon(
                          onPressed: appProvider.tailscaleBusy
                              ? null
                              : () async {
                                  await appProvider.retryTailscaleTransport();
                                },
                          icon: appProvider.tailscaleRetryBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Symbols.refresh_rounded),
                          label:
                              Text(context.l10n.serversTailscaleReconnect),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dropdown listing tailnet peers when Tailscale is connected.
  ///
  /// Selecting a peer auto-fills the URL field with the peer's first IPv4
  /// address on the default OpenCode port. The URL field remains editable
  /// so the user can adjust the port or switch to DNS name.
  Widget _buildTailscalePeerDropdown() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final peers = appProvider.tailscalePeers;
        final isConnected = appProvider.tailscaleState.isConnected;
        if (!isConnected || peers.isEmpty) {
          // Show placeholder when connected but no peers found.
          if (isConnected && _tailscaleEnabled) {
            return InputDecorator(
              decoration: InputDecoration(
                labelText: context.l10n.tailscaleSelectPeer,
                suffixIcon: const Icon(Symbols.search_off_rounded),
              ),
              child: Text(
                context.l10n.tailscaleNoPeers,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return DropdownMenu<TailscalePeer>(
          expandedInsets: EdgeInsets.zero,
          label: Text(context.l10n.tailscaleSelectPeer),
          leadingIcon: const Icon(Symbols.dns_rounded, size: 20),
          dropdownMenuEntries: peers.map((peer) {
            final label = peer.online
                ? peer.displayLabel
                : '${peer.displayLabel} (${context.l10n.tailscalePeerOffline})';
            return DropdownMenuEntry<TailscalePeer>(
              value: peer,
              label: label,
              leadingIcon: Icon(
                peer.online
                    ? Symbols.cloud_done_rounded
                    : Symbols.cloud_off_rounded,
                size: 18,
                color: peer.online
                    ? Colors.green
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }).toList(),
          onSelected: (peer) {
            if (peer != null) {
              if (_testing) {
                _cancelRunningTest();
              }
              _urlController.text = peer.defaultUrl;
              setState(() {});
            }
          },
        );
      },
    );
  }

  Widget _buildLocalSetupStep() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final report = appProvider.localEnvironmentReport;
        final supported = appProvider.localServerSupported;
        final setupBusy = appProvider.localSetupInProgress;
        final status = appProvider.localServerStatus;
        final isBusy =
            status == LocalServerRuntimeStatus.starting ||
            status == LocalServerRuntimeStatus.stopping;
        final isRunning = status == LocalServerRuntimeStatus.running;

        final (statusColor, statusLabel) = switch (status) {
          LocalServerRuntimeStatus.running => (
            Colors.green,
            context.l10n.toolPresentationRunning,
          ),
          LocalServerRuntimeStatus.starting => (
            Colors.orange,
            context.l10n.onboardingStarting,
          ),
          LocalServerRuntimeStatus.stopping => (
            Colors.orange,
            context.l10n.onboardingStopping,
          ),
          LocalServerRuntimeStatus.failed => (
            Colors.red,
            context.l10n.onboardingFailed,
          ),
          LocalServerRuntimeStatus.stopped => (
            Colors.grey,
            context.l10n.onboardingStopped,
          ),
        };

        return SingleChildScrollView(
          key: const ValueKey('step_local_setup'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _step = 0;
                    });
                  },
                  icon: const Icon(Symbols.chevron_left_rounded),
                  label: Text(context.l10n.onboardingChooseAnotherPath),
                ),
              ),
              Text(
                context.l10n.onboardingManagedLocalServer,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.onboardingInstallRunOpenCode,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(statusLabel)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          appProvider.localServerUrl,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appProvider.localServerStatusMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (appProvider.localServerLastOutput.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.onboardingLatestOutputAppProvider(
                    appProvider.localServerLastOutput,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              if (!supported)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(context.l10n.onboardingManagedLocalServer2),
                  ),
                )
              else ...[
                if (report == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  _buildDiagnosticRow(
                    context.l10n.setupDebugPlatform2,
                    report.platform,
                  ),
                  _buildToolStatusRow(
                    context.l10n.setupDebugOpenCode2,
                    report.opencode,
                  ),
                  _buildToolStatusRow(context.l10n.setupDebugNode, report.node),
                  _buildToolStatusRow(context.l10n.setupDebugNpm2, report.npm),
                  _buildToolStatusRow(context.l10n.setupDebugBun2, report.bun),
                  _buildToolStatusRow(context.l10n.setupDebugWSL, report.wsl),
                  _buildDiagnosticRow(
                    context.l10n.setupDebugNetwork2,
                    report.hasNetworkAccess
                        ? context.l10n.onboardingReachable
                        : context.l10n.onboardingUnreachable,
                  ),
                  _buildDiagnosticRow(
                    context.l10n.setupDebugInstallDirectory,
                    report.installDirectoryWritable
                        ? context.l10n.onboardingWritable
                        : context.l10n.onboardingNotWritable,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.recommendation,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.windows) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.onboardingWindowsTipInstalling,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Text(
                  context.l10n.onboardingRecommendedOrderTry,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: setupBusy ? null : _runLocalDiagnostics,
                      icon: const Icon(Symbols.refresh_rounded),
                      label: Text(context.l10n.onboardingRefreshChecks),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          setupBusy || !(report?.opencode.available ?? false)
                          ? null
                          : () async {
                              final detectedCommandMessage =
                                  context.l10n.onboardingUsingDetectedCommand;
                              final ok = await appProvider
                                  .useDetectedLocalServerCommand();
                              if (!ok) {
                                _showMessage(appProvider.errorMessage);
                                return;
                              }
                              _showMessage(detectedCommandMessage);
                            },
                      icon: const Icon(Symbols.check_circle_outline),
                      label: Text(context.l10n.onboardingExisting),
                    ),
                    FilledButton.icon(
                      onPressed: setupBusy
                          ? null
                          : () async {
                              final ok = await appProvider
                                  .installLocalServerRequirements(
                                    LocalOpencodeInstallMethod
                                        .bunBootstrapThenInstall,
                                  );
                              if (!ok) {
                                _showMessage(appProvider.errorMessage);
                              }
                            },
                      icon: const Icon(Symbols.rocket_launch),
                      label: Text(context.l10n.onboardingInstallBunOpenCode),
                    ),
                    OutlinedButton.icon(
                      onPressed: setupBusy
                          ? null
                          : () async {
                              final ok = await appProvider
                                  .installLocalServerRequirements(
                                    LocalOpencodeInstallMethod.bunGlobal,
                                  );
                              if (!ok) {
                                _showMessage(appProvider.errorMessage);
                              }
                            },
                      icon: const Icon(Symbols.bolt),
                      label: Text(context.l10n.onboardingInstallBun),
                    ),
                    OutlinedButton.icon(
                      onPressed: setupBusy
                          ? null
                          : () async {
                              final ok = await appProvider
                                  .installLocalServerRequirements(
                                    LocalOpencodeInstallMethod.npmGlobal,
                                  );
                              if (!ok) {
                                _showMessage(appProvider.errorMessage);
                              }
                            },
                      icon: const Icon(Symbols.inventory_2),
                      label: Text(context.l10n.onboardingInstallNpm),
                    ),
                    OutlinedButton.icon(
                      onPressed: setupBusy
                          ? null
                          : () async {
                              final ok = await appProvider
                                  .installLocalServerRequirements(
                                    LocalOpencodeInstallMethod.downloadBinary,
                                  );
                              if (!ok) {
                                _showMessage(appProvider.errorMessage);
                              }
                            },
                      icon: const Icon(Symbols.download_for_offline),
                      label: Text(context.l10n.onboardingInstallBinary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: (isBusy || isRunning)
                          ? null
                          : () => unawaited(_startManagedLocalServer()),
                      icon: const Icon(Symbols.play_arrow_rounded),
                      label: Text(context.l10n.onboardingStart),
                    ),
                    OutlinedButton.icon(
                      onPressed: (isBusy || !isRunning)
                          ? null
                          : () async {
                              final ok = await appProvider.stopLocalServer();
                              if (!ok) {
                                _showMessage(appProvider.errorMessage);
                              }
                            },
                      icon: const Icon(Symbols.stop_rounded),
                      label: Text(context.l10n.onboardingStop),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('open_code_setup_debug_button_local'),
                    onPressed: _openSetupDebugPage,
                    icon: const Icon(Symbols.bug_report_rounded),
                    label: Text(context.l10n.onboardingViewSetupDebug),
                  ),
                ),
              ],
              if (appProvider.localSetupInProgress) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (appProvider.localSetupMessage.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  appProvider.localSetupMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (appProvider.localSetupLogs.isNotEmpty ||
                  appProvider.setupDebugEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.onboardingDetailedSetupEvents,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n
                              .onboardingAppProviderLocalSetupLogsLength(
                                appProvider.localSetupLogs.length,
                                appProvider.setupDebugEntries.length,
                              ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!_isFirstRunFlow || isRunning) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: _isFirstRunFlow
                      ? const ValueKey('first_run_managed_continue_to_ready')
                      : null,
                  onPressed: _isFirstRunFlow
                      ? _goToReadyFromManagedLocal
                      : () => unawaited(_complete()),
                  icon: Icon(
                    _isFirstRunFlow
                        ? Symbols.arrow_forward_rounded
                        : Symbols.check_circle_rounded,
                  ),
                  label: Text(
                    _isFirstRunFlow
                        ? context.l10n.onboardingContinue
                        : context.l10n.onboardingDone,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildToolStatusRow(String label, LocalToolStatus status) {
    final icon = status.available
        ? const Icon(Symbols.check_circle, color: Colors.green, size: 16)
        : const Icon(Symbols.cancel, color: Colors.red, size: 16);

    final details = <String>[];
    if (status.version.trim().isNotEmpty) {
      details.add(status.version.trim());
    }
    if (status.path.trim().isNotEmpty) {
      details.add(status.path.trim());
    }
    if (status.note.trim().isNotEmpty) {
      details.add(status.note.trim());
    }

    final value = details.isEmpty
        ? (status.available
              ? context.l10n.onboardingAvailable
              : context.l10n.onboardingNotAvailable)
        : details.join(' | ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Row(
              children: [
                icon,
                const SizedBox(width: 6),
                Expanded(child: Text(label)),
              ],
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // -- Step 2: Ready --

  Widget _buildReadyStep() {
    final colorScheme = Theme.of(context).colorScheme;
    final successTitle = _editingServerId == null
        ? context.l10n.onboardingYoureAllSet
        : context.l10n.onboardingServerUpdated;
    final successDescription = _editingServerId == null
        ? context.l10n.onboardingServerConnectedReady
        : context.l10n.onboardingServerSettingsSaved;
    final actionLabel = widget.showSkipAction
        ? context.l10n.onboardingStartUsing(AppConstants.appName)
        : context.l10n.onboardingDone;

    if (_connectionSuccess) {
      return Column(
        key: const ValueKey('step_ready_success'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Symbols.check_circle_rounded,
            size: 72,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            successTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            successDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: _completing ? null : () => unawaited(_complete()),
            icon: const Icon(Symbols.arrow_forward_rounded),
            label: Text(actionLabel),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _completing
                ? null
                : () {
                    setState(() {
                      _step = 0;
                      _connectionSuccess = false;
                      _readyFromManagedLocal = false;
                      _connectionError = null;
                    });
                  },
            icon: const Icon(Symbols.swap_horiz_rounded),
            label: Text(context.l10n.onboardingChooseAnotherPath),
          ),
        ],
      );
    }

    // Connection failed but the profile is saved, so keep the user unblocked.
    final continueLabel = widget.showSkipAction
        ? context.l10n.onboardingStartUsing(AppConstants.appName)
        : context.l10n.onboardingDone;
    return SingleChildScrollView(
      key: const ValueKey('step_ready_failed'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.warning_amber_rounded,
            size: 72,
            color: colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.onboardingConnectionIssue,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _connectionError ?? context.l10n.onboardingCouldNotVerify,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.onboardingAddServerLater,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            key: const ValueKey('continue_with_unhealthy_server_button'),
            onPressed: _completingWithSavedServer
                ? null
                : () => unawaited(_continueWithSavedServer()),
            icon: const Icon(Symbols.arrow_forward_rounded),
            label: Text(continueLabel),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey(
              'add_another_server_after_health_failure_button',
            ),
            onPressed: _addAnotherServerAfterFailure,
            icon: const Icon(Symbols.add_rounded),
            label: Text(context.l10n.serversAddServer),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey(
              'open_server_settings_after_health_failure_button',
            ),
            onPressed: () => unawaited(_openServerSettings()),
            icon: const Icon(Symbols.settings_rounded),
            label: Text(context.l10n.chatDescriptionOpenSettings),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _step = 1;
                _connectionSuccess = false;
                _readyFromManagedLocal = false;
                _connectionError = null;
              });
            },
            icon: const Icon(Symbols.refresh_rounded),
            label: Text(context.l10n.terminalTryAgain),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _step = 0;
                _connectionSuccess = false;
                _readyFromManagedLocal = false;
                _connectionError = null;
              });
            },
            icon: const Icon(Symbols.swap_horiz_rounded),
            label: Text(context.l10n.onboardingChooseAnotherPath),
          ),
          TextButton.icon(
            key: const ValueKey('open_code_setup_debug_button_failed'),
            onPressed: _openSetupDebugPage,
            icon: const Icon(Symbols.bug_report_rounded),
            label: Text(context.l10n.onboardingViewSetupDebug),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupHintRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
