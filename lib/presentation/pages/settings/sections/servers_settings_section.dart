import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/tailscale/tailscale_service.dart';
import '../../../../domain/entities/server_profile.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/app_page_route.dart';
import '../../../widgets/searchable_dropdown_form_field.dart';
import '../../onboarding_wizard_page.dart';
import '../../opencode_setup_debug_page.dart';
import '../widgets/settings_section_layout.dart';

class ServersSettingsSection extends StatefulWidget {
  const ServersSettingsSection({super.key});

  @override
  State<ServersSettingsSection> createState() => _ServersSettingsSectionState();
}

enum _ServerAction {
  activate,
  setDefault,
  clearDefault,
  edit,
  delete,
  check,
  reauth,
  clearOAuth,
}

class _ServersSettingsSectionState extends State<ServersSettingsSection> {
  final _activeServerDropdownKey = GlobalKey<FormFieldState<String>>();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final appProvider = context.read<AppProvider>();
    await appProvider.initialize();
    if (!mounted) return;
    await appProvider.refreshServerHealth();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final profiles = appProvider.serverProfiles;
        if (_loading && profiles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        const padding = AppConstants.defaultPadding;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(padding, padding, padding, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SettingsSectionIntro(
                    title: context.l10n.settingsServersTitle,
                    description: context.l10n.settingsServersDescription,
                    hideTitleOnCompact: true,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _openSetupWizard,
                        icon: const Icon(Symbols.auto_fix_high_rounded),
                        label: Text(context.l10n.serversSetupWizard),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.read<AppProvider>().refreshServerHealth(),
                        icon: const Icon(Symbols.health_and_safety),
                        label: Text(context.l10n.serversRefreshHealth),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openSetupWizard(
                          initialFlow: SetupWizardInitialFlow.connectServer,
                        ),
                        icon: const Icon(Symbols.add),
                        label: Text(context.l10n.serversAddServer),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsGroupHeader(
                    title: context.l10n.settingsGroupCurrentConnection,
                  ),
                  const SizedBox(height: 8),
                  _buildActiveServerCard(appProvider),
                  const SizedBox(height: 20),
                  SettingsGroupHeader(
                    title: context.l10n.settingsGroupThisDevice,
                  ),
                  const SizedBox(height: 8),
                  _buildLocalServerCard(appProvider),
                  const SizedBox(height: 20),
                  SettingsGroupHeader(
                    title: context.l10n.settingsGroupSavedServers,
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(padding, 0, padding, padding),
              sliver: profiles.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _buildEmptyState(),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 8);
                        }
                        return _buildProfileTile(
                          appProvider: appProvider,
                          profile: profiles[index ~/ 2],
                        );
                      }, childCount: profiles.length * 2 - 1),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveServerCard(AppProvider appProvider) {
    final activeServer = appProvider.activeServer;
    final activeId = appProvider.activeServerId;
    final hasActiveInList = appProvider.serverProfiles.any(
      (profile) => profile.id == activeId,
    );
    final dropdownValue = hasActiveInList ? activeId : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.serversActiveServer,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SearchableDropdownFormField<String>(
              key: _activeServerDropdownKey,
              initialValue: dropdownValue,
              searchHintText: context.l10n.serversSearchActiveHint,
              emptyText: context.l10n.serversNoServersFound,
              searchTermsBuilder: (value) =>
                  _serverSearchTerms(appProvider, value),
              items: appProvider.serverProfiles
                  .map(
                    (profile) => DropdownMenuItem<String>(
                      value: profile.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HealthDot(status: appProvider.healthFor(profile.id)),
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              profile.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) async {
                final currentActiveId = appProvider.activeServerId;
                if (id == null || id == currentActiveId) return;
                final status = appProvider.healthFor(id);
                if (status == ServerHealthStatus.unhealthy) {
                  // Restore dropdown to the actual active value.
                  _activeServerDropdownKey.currentState?.didChange(
                    dropdownValue,
                  );
                  _showMessage(context.l10n.serversUnhealthyActivateError);
                  return;
                }

                final ok = await appProvider.setActiveServer(id);
                if (!ok && mounted) {
                  // Restore dropdown on API failure.
                  _activeServerDropdownKey.currentState?.didChange(
                    dropdownValue,
                  );
                  _showMessage(appProvider.errorMessage);
                }
              },
              decoration: InputDecoration(
                labelText: context.l10n.settingsServersChooseActive,
                border: const OutlineInputBorder(),
              ),
            ),
            if (activeServer != null) ...[
              const SizedBox(height: 10),
              Text(
                activeServer.url,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (activeServer.tailscaleEnabled) ...[
                const SizedBox(height: 10),
                _buildTailscaleStatusCard(appProvider),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTailscaleStatusCard(AppProvider appProvider) {
    final state = appProvider.tailscaleState;
    final authUrl = state.authUrl?.toString();
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, title, color) = switch (state.nodeState) {
      TailscaleNodeState.connected => (
        Symbols.check_circle_rounded,
        context.l10n.serversTailscaleConnected,
        Colors.green,
      ),
      TailscaleNodeState.connecting => (
        Symbols.sync_rounded,
        context.l10n.serversTailscaleConnecting,
        colorScheme.primary,
      ),
      TailscaleNodeState.needsLogin => (
        Symbols.login_rounded,
        context.l10n.serversTailscaleAuthRequired,
        colorScheme.tertiary,
      ),
      TailscaleNodeState.needsMachineAuth => (
        Symbols.admin_panel_settings_rounded,
        context.l10n.serversTailscaleAdminApprovalRequired,
        colorScheme.tertiary,
      ),
      TailscaleNodeState.error => (
        Symbols.error_rounded,
        context.l10n.serversTailscaleConnectionFailed,
        colorScheme.error,
      ),
      TailscaleNodeState.unsupported => (
        Symbols.block_rounded,
        context.l10n.serversTailscaleUnsupported,
        colorScheme.error,
      ),
      TailscaleNodeState.disconnected => (
        Symbols.link_off_rounded,
        context.l10n.serversTailscaleDisconnected,
        colorScheme.onSurfaceVariant,
      ),
    };
    final message =
        state.message ??
        (state.requiresUserLogin
            ? context.l10n.serversTailscaleLoginExplanation
            : state.nodeState == TailscaleNodeState.connected
            ? context.l10n.serversTailscaleTrafficExplanation
            : context.l10n.serversTailscaleConnectExplanation);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
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
          if (state.requiresUserLogin || authUrl != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await appProvider.authenticateTailscale();
                    if (!ok && mounted) {
                      _showMessage(context.l10n.onboardingOpenTailscaleLogin);
                    }
                  },
                  icon: const Icon(Symbols.open_in_browser_rounded),
                  label: Text(context.l10n.onboardingAuthenticate),
                ),
                if (authUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(authUrl),
                    icon: const Icon(Symbols.content_copy_rounded),
                    label: Text(context.l10n.onboardingCopyLoginURL),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _serverSearchTerms(AppProvider appProvider, String serverId) {
    for (final profile in appProvider.serverProfiles) {
      if (profile.id == serverId) {
        return <String>[profile.displayName, profile.url, profile.id];
      }
    }
    return <String>[serverId];
  }

  Widget _buildLocalServerCard(AppProvider appProvider) {
    final status = appProvider.localServerStatus;
    final supported = appProvider.localServerSupported;
    final isBusy =
        status == LocalServerRuntimeStatus.starting ||
        status == LocalServerRuntimeStatus.stopping;
    final isRunning = status == LocalServerRuntimeStatus.running;
    final setupBusy = appProvider.localSetupInProgress;

    final (statusColor, statusLabel) = switch (status) {
      LocalServerRuntimeStatus.running => (
        Colors.green,
        context.l10n.toolPresentationRunning,
      ),
      LocalServerRuntimeStatus.starting => (
        Colors.orange,
        context.l10n.statusStarting,
      ),
      LocalServerRuntimeStatus.stopping => (
        Colors.orange,
        context.l10n.statusStopping,
      ),
      LocalServerRuntimeStatus.failed => (
        Colors.red,
        context.l10n.statusFailed,
      ),
      LocalServerRuntimeStatus.stopped => (
        Colors.grey,
        context.l10n.statusStopped,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.serversLocalOpenCodeServer,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.serversDesktopModeExplanation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
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
                Text(statusLabel),
                const Spacer(),
                Text(
                  appProvider.localServerUrl,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              appProvider.localServerStatusMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (appProvider.localServerCommandPath.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                context.l10n.serversCommandAppProviderLocalServerCommandPath(
                  appProvider.localServerCommandPath,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (appProvider.localServerLastOutput.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                context.l10n.onboardingLatestOutputAppProvider(
                  appProvider.localServerLastOutput,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            if (!supported)
              Text(
                context.l10n.serversManagedModeAvailable,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: (isBusy || isRunning)
                        ? null
                        : () => _startLocalServer(appProvider),
                    icon: const Icon(Symbols.play_arrow_rounded),
                    label: Text(context.l10n.onboardingStart),
                  ),
                  OutlinedButton.icon(
                    onPressed: (isBusy || !isRunning)
                        ? null
                        : () => _stopLocalServer(appProvider),
                    icon: const Icon(Symbols.stop_rounded),
                    label: Text(context.l10n.onboardingStop),
                  ),
                  OutlinedButton.icon(
                    onPressed: setupBusy
                        ? null
                        : () => _openSetupWizard(
                            initialFlow:
                                SetupWizardInitialFlow.managedLocalServer,
                          ),
                    icon: const Icon(Symbols.auto_fix_high_rounded),
                    label: Text(context.l10n.serversSetupWizard),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'open_code_setup_debug_button_settings',
                    ),
                    onPressed: _openSetupDebugPage,
                    icon: const Icon(Symbols.bug_report_rounded),
                    label: Text(context.l10n.serversSetupDebug),
                  ),
                ],
              ),
            if (appProvider.localSetupInProgress) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (appProvider.localSetupMessage.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                appProvider.localSetupMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required AppProvider appProvider,
    required ServerProfile profile,
  }) {
    final isActive = profile.id == appProvider.activeServerId;
    final isDefault = profile.id == appProvider.defaultServerId;

    return Card(
      child: ListTile(
        leading: _HealthDot(status: appProvider.healthFor(profile.id)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                profile.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive) _MetaChip(label: context.l10n.serversActive),
            if (isDefault) _MetaChip(label: context.l10n.serversDefault),
            if (profile.oauthEnabled)
              _MetaChip(label: context.l10n.serverOAuthChip),
            if (profile.tailscaleEnabled)
              _MetaChip(label: context.l10n.serverTailscaleChip),
          ],
        ),
        subtitle: Text(
          profile.url,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_ServerAction>(
          icon: const Icon(Symbols.more_vert),
          onSelected: (action) => _handleServerAction(
            appProvider: appProvider,
            profile: profile,
            action: action,
          ),
          itemBuilder: (_) => [
            if (!isActive)
              PopupMenuItem(
                value: _ServerAction.activate,
                child: Text(context.l10n.serversSetActive),
              ),
            if (!isDefault)
              PopupMenuItem(
                value: _ServerAction.setDefault,
                child: Text(context.l10n.serversSetDefault),
              ),
            if (isDefault)
              PopupMenuItem(
                value: _ServerAction.clearDefault,
                child: Text(context.l10n.serversClearDefault),
              ),
            if (profile.oauthEnabled) ...[
              PopupMenuItem(
                value: _ServerAction.reauth,
                child: Text(context.l10n.serverReauthenticate),
              ),
              PopupMenuItem(
                value: _ServerAction.clearOAuth,
                child: Text(context.l10n.serverClearOAuth),
              ),
            ],
            PopupMenuItem(
              value: _ServerAction.check,
              child: Text(context.l10n.serversCheckHealth),
            ),
            PopupMenuItem(
              value: _ServerAction.edit,
              child: Text(context.l10n.serversEdit),
            ),
            PopupMenuItem(
              value: _ServerAction.delete,
              child: Text(context.l10n.serversDelete),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSetupWizard({
    SetupWizardInitialFlow initialFlow = SetupWizardInitialFlow.choose,
    ServerProfile? initialServerProfile,
  }) async {
    await Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => OnboardingWizardPage(
          onComplete: () => Navigator.of(context).pop(),
          showSkipAction: false,
          initialFlow: initialFlow,
          initialServerProfile: initialServerProfile,
        ),
      ),
    );
  }

  Future<void> _openSetupDebugPage() async {
    await Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => const OpenCodeSetupDebugPage()));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.dns, size: 48),
          const SizedBox(height: 12),
          Text(
            context.l10n.serversServersConfigured,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.serversAddLeastOpenCode,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleServerAction({
    required AppProvider appProvider,
    required ServerProfile profile,
    required _ServerAction action,
  }) async {
    switch (action) {
      case _ServerAction.activate:
        if (appProvider.healthFor(profile.id) == ServerHealthStatus.unhealthy) {
          _showMessage(context.l10n.serversCannotActivateUnhealthy);
          return;
        }
        final ok = await appProvider.setActiveServer(profile.id);
        if (!ok) {
          _showMessage(appProvider.errorMessage);
        }
        break;
      case _ServerAction.setDefault:
        final ok = await appProvider.setDefaultServer(profile.id);
        if (!ok) {
          _showMessage(appProvider.errorMessage);
        }
        break;
      case _ServerAction.clearDefault:
        await appProvider.clearDefaultServer();
        break;
      case _ServerAction.edit:
        await _openSetupWizard(
          initialFlow: SetupWizardInitialFlow.connectServer,
          initialServerProfile: profile,
        );
        break;
      case _ServerAction.delete:
        await _confirmDelete(profile);
        break;
      case _ServerAction.check:
        await appProvider.refreshServerHealth(serverId: profile.id);
        break;
      case _ServerAction.reauth:
        final ok = await appProvider.handleOAuthChallenge(
          serverUrl: profile.url,
          challengeHeaders: appProvider.getOAuthChallengeHeaders(profile.url),
        );
        if (!ok && mounted) {
          _showMessage(context.l10n.serverOAuthAuthFailed);
        }
        break;
      case _ServerAction.clearOAuth:
        await appProvider.clearOAuthCredential(profile.url);
        break;
    }
  }

  Future<void> _startLocalServer(AppProvider appProvider) async {
    final ok = await appProvider.startLocalServer();
    if (!ok) {
      _showMessage(appProvider.errorMessage);
    }
  }

  Future<void> _stopLocalServer(AppProvider appProvider) async {
    final ok = await appProvider.stopLocalServer();
    if (!ok) {
      _showMessage(appProvider.errorMessage);
    }
  }

  Future<void> _confirmDelete(ServerProfile profile) async {
    final appProvider = context.read<AppProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(context.l10n.serversDeleteServer),
          content: Text(
            context.l10n.serversRemoveProfileDisplayName(profile.displayName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.serversCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.serversDelete),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    final ok = await appProvider.removeServerProfile(profile.id);
    if (!ok) {
      _showMessage(appProvider.errorMessage);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage(context.l10n.commonCopiedToClipboard);
  }
}

class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.status});

  final ServerHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, tooltip) = switch (status) {
      ServerHealthStatus.healthy => (
        Colors.green,
        context.l10n.serverHealthHealthy,
      ),
      ServerHealthStatus.unhealthy => (
        Colors.red,
        context.l10n.serverHealthUnhealthy,
      ),
      ServerHealthStatus.unknown => (
        Colors.grey,
        context.l10n.serverHealthUnknown,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

/// Reusable quick-guide widget for OpenCode server setup instructions.
/// Used in both the Settings > Servers section and the onboarding wizard.
class ServerSetupQuickGuide extends StatefulWidget {
  const ServerSetupQuickGuide({super.key, required this.onCopy});

  final void Function(String text) onCopy;

  @override
  State<ServerSetupQuickGuide> createState() => _ServerSetupQuickGuideState();
}

class _ServerSetupQuickGuideState extends State<ServerSetupQuickGuide> {
  static const String _baseCommand =
      'opencode serve --hostname 0.0.0.0 --port 4096';

  final TextEditingController _passwordController = TextEditingController();
  bool _protectWithPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String _quotedEnvValue(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  String _quotedPowerShellValue(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  String _buildCommand() {
    final password = _passwordController.text.trim();
    if (!_protectWithPassword || password.isEmpty) {
      return _baseCommand;
    }

    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (isWindows) {
      return '\$env:OPENCODE_SERVER_PASSWORD=${_quotedPowerShellValue(password)}; $_baseCommand';
    }

    return 'OPENCODE_SERVER_PASSWORD=${_quotedEnvValue(password)} $_baseCommand';
  }

  @override
  Widget build(BuildContext context) {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final locale = Localizations.maybeLocaleOf(context);
    final isPortuguese =
        locale?.languageCode.toLowerCase().startsWith('pt') ?? false;

    final title = isPortuguese ? 'Configuracao rapida' : 'Quick setup';
    final intro = isPortuguese
        ? 'CodeWalk e o app. OpenCode e o motor que precisa estar rodando para a conexao funcionar.'
        : 'CodeWalk is the app. OpenCode is the engine that needs to be running before this connection can work.';
    final firstStep = isPortuguese
        ? '1. Instale o OpenCode CLI.'
        : '1. Install OpenCode CLI.';
    final commandLabel = isPortuguese
        ? isWindows
              ? '2. Execute no PowerShell:'
              : '2. Execute no terminal:'
        : isWindows
        ? '2. Run in PowerShell:'
        : '2. Run in your terminal:';
    final passwordToggleLabel = isPortuguese
        ? 'Proteger acesso com senha'
        : 'Protect access with password';
    final passwordHint = isPortuguese ? 'Senha do servidor' : 'Server password';
    final installOptions = isPortuguese
        ? 'Outras opcoes oficiais: script de instalacao, npm, bun, pnpm, Homebrew ou binario do GitHub Releases.'
        : 'Other official install options: install script, npm, bun, pnpm, Homebrew, or a binary from GitHub Releases.';
    final verifyHint = isPortuguese
        ? 'Depois de iniciar o servidor, confirme /global/health ou /doc antes de colar a URL no CodeWalk.'
        : 'After starting the server, confirm /global/health or /doc responds before pasting the URL into CodeWalk.';
    final command = _buildCommand();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.info,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(intro, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(firstStep, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  commandLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => widget.onCopy(command),
                icon: const Icon(Symbols.content_copy_rounded, size: 14),
                label: Text(context.l10n.serversCopy),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: _protectWithPassword,
            onChanged: (value) {
              setState(() {
                _protectWithPassword = value;
              });
            },
            contentPadding: EdgeInsets.zero,
            title: Text(passwordToggleLabel),
          ),
          if (_protectWithPassword) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: passwordHint),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: SelectableText(
              command,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 8),
          Text(installOptions, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(verifyHint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
