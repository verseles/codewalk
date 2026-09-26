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
import '../../../theme/app_visual_style_tokens.dart';
import '../../../utils/app_page_route.dart';
import '../../../widgets/app_indeterminate_progress.dart';
import '../../../widgets/direct_provider.dart';
import '../../onboarding_wizard_page.dart';
import '../../opencode_setup_debug_page.dart';
import '../widgets/settings_section_layout.dart';

class ServersSettingsSection extends StatefulWidget {
  const ServersSettingsSection({super.key});

  @override
  State<ServersSettingsSection> createState() => _ServersSettingsSectionState();
}

enum _ServerAction {
  setDefault,
  clearDefault,
  edit,
  delete,
  check,
  reauth,
  clearOAuth,
}

class _ServersSettingsSectionState extends State<ServersSettingsSection> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  int? _lastSearchSerial;
  String? _activatingServerId;
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
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DirectConsumer<AppProvider>(
      builder: (context, appProvider, _) {
        final request = SettingsSearchDestination.requestOf(context);
        if (request != null && request.serial != _lastSearchSerial) {
          _lastSearchSerial = request.serial;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_scrollController.hasClients) _scrollController.jumpTo(0);
            SettingsSearchDestination.contentReady(context);
          });
        } else {
          SettingsSearchDestination.contentReady(context);
        }
        final profiles = appProvider.serverProfiles;
        final query = _searchController.text.trim().toLowerCase();
        final filteredProfiles = profiles
            .where(
              (profile) => [
                profile.displayName,
                profile.url,
                profile.id,
              ].any((value) => value.toLowerCase().contains(query)),
            )
            .toList(growable: false);
        if (_loading && profiles.isEmpty) {
          return const Center(child: AppIndeterminateRing());
        }

        const padding = AppConstants.defaultPadding;
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(padding, padding, padding, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          key: const ValueKey('settings_servers_setup'),
                          onPressed: _openSetupWizard,
                          icon: const Icon(Symbols.auto_fix_high_rounded),
                          label: Text(context.l10n.serversSetupWizard),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('settings_servers_health'),
                          onPressed: () =>
                              context.read<AppProvider>().refreshServerHealth(),
                          icon: const Icon(Symbols.health_and_safety),
                          label: Text(context.l10n.serversRefreshHealth),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('settings_servers_add'),
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
                      title: context.l10n.settingsServersChooseActive,
                    ),
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: const ValueKey('settings_servers_active'),
                      child: TextField(
                        key: const ValueKey('settings_servers_filter'),
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: context.l10n.serversSearchActiveHint,
                          prefixIcon: const Icon(Symbols.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.l10n.onboardingClear,
                                  icon: const Icon(Symbols.close),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
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
                  : filteredProfiles.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(context.l10n.serversNoServersFound),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 8);
                        }
                        return _buildProfileTile(
                          appProvider: appProvider,
                          profile: filteredProfiles[index ~/ 2],
                        );
                      }, childCount: filteredProfiles.length * 2 - 1),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(padding, 0, padding, padding),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (appProvider.activeServer?.tailscaleEnabled == true) ...[
                      _buildTailscaleStatusCard(appProvider),
                      const SizedBox(height: 20),
                    ],
                    SettingsGroupHeader(
                      title: context.l10n.settingsGroupThisDevice,
                    ),
                    const SizedBox(height: 8),
                    _buildLocalServerCard(appProvider),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
        border: Theme.of(context).visualStyleTokens.isRefined
            ? null
            : Border.all(color: colorScheme.outlineVariant),
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
          if (state.requiresUserLogin ||
              authUrl != null ||
              state.nodeState == TailscaleNodeState.disconnected ||
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
                            final ok = await appProvider
                                .authenticateTailscale();
                            if (!ok && mounted) {
                              _showMessage(
                                context.l10n.onboardingOpenTailscaleLogin,
                              );
                            }
                          },
                    icon: appProvider.tailscaleAuthBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: AppIndeterminateRing(
                              size: 18,
                              strokeWidth: 2,
                            ),
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
                            child: AppIndeterminateRing(
                              size: 18,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Symbols.refresh_rounded),
                    label: Text(context.l10n.serversTailscaleReconnect),
                  ),
              ],
            ),
          ],
          if (state.nodeState != TailscaleNodeState.disconnected &&
              state.nodeState != TailscaleNodeState.unsupported) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: appProvider.tailscaleBusy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(
                                context.l10n.serversTailscaleLogoutConfirmTitle,
                              ),
                              content: Text(
                                context
                                    .l10n
                                    .serversTailscaleLogoutConfirmMessage,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: Text(context.l10n.commonCancel),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: Text(
                                    context.l10n.serversTailscaleLogout,
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !mounted) return;
                          await appProvider.logoutTailscale();
                        },
                  icon: const Icon(Symbols.logout_rounded),
                  label: Text(context.l10n.serversTailscaleLogout),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                    Flexible(child: Text(statusLabel)),
                  ],
                ),
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
              const AppIndeterminateBar(minHeight: 3),
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
      key: ValueKey('settings_server_${profile.id}'),
      child: ListTile(
        selected: isActive,
        onTap: isActive || _activatingServerId != null
            ? null
            : () => _activateServer(appProvider, profile.id),
        leading: _HealthDot(status: appProvider.healthFor(profile.id)),
        title: Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.url, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (isActive ||
                isDefault ||
                profile.oauthEnabled ||
                profile.tailscaleEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (isActive) _MetaChip(label: context.l10n.serversActive),
                    if (isDefault)
                      _MetaChip(label: context.l10n.serversDefault),
                    if (profile.oauthEnabled)
                      _MetaChip(label: context.l10n.serverOAuthChip),
                    if (profile.tailscaleEnabled)
                      _MetaChip(label: context.l10n.serverTailscaleChip),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_activatingServerId == profile.id)
              const AppIndeterminateRing(size: 18),
            PopupMenuButton<_ServerAction>(
              icon: const Icon(Symbols.more_vert),
              onSelected: (action) => _handleServerAction(
                appProvider: appProvider,
                profile: profile,
                action: action,
              ),
              itemBuilder: (_) => [
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

  Future<void> _activateServer(AppProvider appProvider, String id) async {
    if (_activatingServerId != null || id == appProvider.activeServerId) return;
    if (appProvider.healthFor(id) == ServerHealthStatus.unhealthy) {
      _showMessage(context.l10n.serversCannotActivateUnhealthy);
      return;
    }
    setState(() => _activatingServerId = id);
    try {
      final ok = await appProvider.setActiveServer(id);
      if (!ok) _showMessage(appProvider.errorMessage);
    } catch (_) {
      if (mounted) {
        _showMessage(
          appProvider.errorMessage.isEmpty
              ? context.l10n.errorAnErrorOccurred
              : appProvider.errorMessage,
        );
      }
    } finally {
      if (mounted) setState(() => _activatingServerId = null);
    }
  }

  Future<void> _handleServerAction({
    required AppProvider appProvider,
    required ServerProfile profile,
    required _ServerAction action,
  }) async {
    switch (action) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
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

    final title = context.l10n.serversQuickGuideTitle;
    final intro = context.l10n.serversQuickGuideIntro;
    final firstStep = context.l10n.serversQuickGuideStepInstallCli;
    final commandLabel = isWindows
        ? context.l10n.serversQuickGuideRunPowerShell
        : context.l10n.serversQuickGuideRunTerminal;
    final passwordToggleLabel = context.l10n.serversQuickGuideProtectPassword;
    final passwordHint = context.l10n.serversQuickGuideServerPassword;
    final installOptions = context.l10n.serversQuickGuideInstallOptions;
    final verifyHint = context.l10n.serversQuickGuideVerifyHint;
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
