import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../app/workspace_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/modal_primary_action_shortcuts.dart';
import '../sessions/sessions_controller.dart';
import 'add_server_panel.dart';
import 'endpoint_health_controller.dart';
import 'endpoint_health_view.dart';
import 'endpoint_status_view.dart';
import 'hosts_controller.dart';
import 'profile_edit_dialog.dart';
import 'server_switcher.dart';

export 'endpoint_status_view.dart'
    show EndpointStatusView, LegacyEndpointPage, legacyDownloadUrl;

enum _ServerAction {
  check,
  remove,
  pair,
  renew,
  password,
  edit,
  setDefault,
  clearDefault,
}

class HostsPage extends StatefulWidget {
  const HostsPage({this.revealFilter = false, super.key});
  final bool revealFilter;
  @override
  State<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<HostsPage> with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _searchAnchor = GlobalKey();
  Timer? _highlightTimer;
  bool _highlight = false;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _highlightTimer?.cancel();
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HostsController>().load();
    });
    if (widget.revealFilter) _revealFilter();
  }

  @override
  void didUpdateWidget(HostsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealFilter && !oldWidget.revealFilter) _revealFilter();
  }

  void _revealFilter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _highlight = true);
      _searchFocus.requestFocus();
      _revealSearch();
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlight = false);
      });
    });
  }

  void _revealSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _searchAnchor.currentContext;
      if (mounted && _highlight && _searchFocus.hasFocus && target != null) {
        Scrollable.ensureVisible(target, alignment: 0.4);
      }
    });
  }

  @override
  void didChangeMetrics() {
    if (_highlight && _searchFocus.hasFocus) _revealSearch();
  }

  Widget _actions(HostsController hosts, EndpointProfile profile) {
    final l = context.v2L10n;
    final catalog = context.read<SessionsController?>();
    final workspace = context.read<WorkspaceController?>();
    final canEdit =
        !hosts.savingProfile && !hosts.loading && !hosts.storageError;
    return PopupMenuButton<_ServerAction>(
      key: ValueKey('endpoint-actions-${profile.id}'),
      tooltip: l.chatAppBarMoreActions,
      onSelected: (action) async {
        switch (action) {
          case _ServerAction.check:
            unawaited(hosts.check(profile));
          case _ServerAction.remove:
            unawaited(hosts.remove(profile));
          case _ServerAction.pair:
            unawaited(
              showAddServer(
                context,
                prepare: (pairing) => pairing.empty(profile: profile),
              ),
            );
          case _ServerAction.renew:
            unawaited(
              showAddServer(
                context,
                prepare: (pairing) => unawaited(pairing.renew(profile)),
              ),
            );
          case _ServerAction.password:
            unawaited(
              showDialog<void>(
                context: context,
                builder: (_) => _ProfileDialog(hosts: hosts, repair: profile),
              ),
            );
          case _ServerAction.edit:
            final saved = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => ProfileEditDialog(hosts: hosts, profile: profile),
            );
            if (!mounted || saved != true) return;
            final current = hosts.profiles
                .where((saved) => saved.id == profile.id)
                .firstOrNull;
            if (catalog?.selectedProfile?.id == profile.id &&
                current != null &&
                !current.sameBinding(profile)) {
              unawaited(catalog!.refresh());
            }
          case _ServerAction.setDefault || _ServerAction.clearDefault:
            final saved = await workspace?.setDefaultProfile(
              action == _ServerAction.clearDefault ? null : profile.id,
            );
            if (!mounted) return;
            if (saved != true) {
              showAppSnackBar(
                ScaffoldMessenger.of(context),
                l.hostsProfileStorageError,
              );
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _ServerAction.edit,
          enabled: canEdit,
          child: Text(l.serversEdit),
        ),
        if (workspace != null)
          PopupMenuItem(
            value: workspace.defaultProfile == profile.id
                ? _ServerAction.clearDefault
                : _ServerAction.setDefault,
            enabled: canEdit && !workspace.savingDefault,
            child: Text(
              workspace.defaultProfile == profile.id
                  ? l.serversClearDefault
                  : l.serversSetDefault,
            ),
          ),
        PopupMenuItem(
          value: _ServerAction.check,
          enabled: hosts.canCheck(profile),
          child: Text(l.hostsCheckConnection),
        ),
        PopupMenuItem(
          value: _ServerAction.password,
          enabled: canEdit,
          child: Text(l.onboardingPassword),
        ),
        PopupMenuItem(
          value: _ServerAction.pair,
          enabled: canEdit,
          child: Text(l.pairingAgain),
        ),
        if (hosts.credentialFor(profile)?.kind == EndpointAuthKind.paired &&
            hosts.assessments[profile.id]?.version == '2.0.22')
          PopupMenuItem(
            value: _ServerAction.renew,
            enabled: canEdit,
            child: Text(l.pairingRenew),
          ),
        PopupMenuItem(
          value: _ServerAction.remove,
          enabled: canEdit,
          child: Text(l.commonDelete),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    final hosts = context.watch<HostsController>();
    final health = context.watch<EndpointHealthController?>();
    final catalog = context.watch<SessionsController?>();
    final workspace = context.watch<WorkspaceController?>();
    final profiles = filterSavedServers(hosts.profiles, _search.text);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  l.settingsServersTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                FilledButton.icon(
                  key: const ValueKey('add-endpoint'),
                  onPressed: () => showAddServer(context),
                  icon: const Icon(Symbols.add),
                  label: Text(l.serversAddServer),
                ),
              ],
            ),
            if (hosts.loading) const AppIndeterminateBar(),
            Padding(
              key: _searchAnchor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Stack(
                children: [
                  TextField(
                    key: const ValueKey('hosts-search'),
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l.serversSearchActiveHint,
                      prefixIcon: const Icon(Symbols.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l.commonCancel,
                              icon: const Icon(Symbols.clear),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                  if (_highlight)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: const ValueKey('hosts-search-highlight'),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hosts.storageError)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.hostsProfileStorageError),
                      TextButton(
                        onPressed: hosts.load,
                        child: Text(l.chatRetry),
                      ),
                    ],
                  ),
                ),
              ),
            if (workspace?.hasPersistenceError == true)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.hostsProfileStorageError),
                      TextButton(
                        key: const ValueKey('workspace-preferences-retry'),
                        onPressed: workspace!.retryPreferences,
                        child: Text(l.chatRetry),
                      ),
                    ],
                  ),
                ),
              ),
            if (!hosts.loading && !hosts.storageError && hosts.profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.serversNoServersFound),
              ),
            if (profiles.isEmpty && hosts.profiles.isNotEmpty)
              Text(l.settingsNavigationNoResults),
            for (final profile in profiles)
              Card(
                key: ValueKey('saved-server-${profile.id}'),
                child: InkWell(
                  onTap: catalog == null || workspace?.switchingServer == true
                      ? null
                      : () => selectWorkspaceServer(context, profile),
                  child: Semantics(
                    selected: catalog?.selectedProfile?.id == profile.id,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              _actions(hosts, profile),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (catalog?.selectedProfile?.id == profile.id)
                                Chip(
                                  key: ValueKey('server-active-${profile.id}'),
                                  label: Text(l.serversActive),
                                ),
                              if (workspace?.defaultProfile == profile.id)
                                Chip(
                                  key: ValueKey('server-default-${profile.id}'),
                                  label: Text(l.serversDefault),
                                ),
                              if (!hosts.loading)
                                Chip(
                                  label: Text(
                                    hosts.credentialUnreadable(profile)
                                        ? l.healthCredentialUnreadable
                                        : switch (hosts
                                              .credentialFor(profile)
                                              ?.kind) {
                                            EndpointAuthKind.password =>
                                              l.onboardingPassword,
                                            EndpointAuthKind.paired =>
                                              l.pairingPaired,
                                            null => l.healthCredentialMissing,
                                          },
                                  ),
                                ),
                            ],
                          ),
                          EndpointHealthIndicator(
                            view:
                                health?.view(profile) ??
                                const EndpointHealthView(),
                          ),
                          SelectableText(profile.endpoint.toString()),
                          if (hosts.credentialUnreadable(profile))
                            Text(l.hostsProfileStorageError),
                          if (hosts.credentialFor(profile)?.kind ==
                              EndpointAuthKind.paired) ...[
                            if (hosts.credentialFor(profile)?.expiresAt
                                case final expiry?)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l.pairingExpires}: ${expiry.toLocal()}',
                                  ),
                                  if (!expiry.isAfter(DateTime.now().toUtc()))
                                    Text(l.hostsAuthRequired),
                                ],
                              ),
                          ],
                          if (hosts.assessments[profile.id]
                              case final assessment?)
                            EndpointStatusView(assessment: assessment),
                          if (hosts.isChecking(profile))
                            AppIndeterminateBar(
                              key: ValueKey('endpoint-check-${profile.id}'),
                              semanticsLabel: l.hostsCheckConnection,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Password repair of a saved server; adding one uses [AddServerPanel].
class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.hosts, required this.repair});
  final HostsController hosts;
  final EndpointProfile repair;
  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _label = TextEditingController();
  final _secret = TextEditingController();
  EndpointAssessment? _assessment;
  String? _testedUrl;
  String? _testedSecret;
  bool _checking = false;
  bool _saving = false;
  bool _saveFailed = false;
  Timer? _retryTimer;
  @override
  void initState() {
    super.initState();
    _url.text = widget.repair.endpoint.toString();
    _label.text = widget.repair.label;
  }

  void _invalidate() {
    _retryTimer?.cancel();
    widget.hosts.cancelProbe();
    setState(() {
      _assessment = null;
      _testedUrl = null;
      _testedSecret = null;
      _checking = false;
    });
  }

  Future<void> _check() async {
    if (!_form.currentState!.validate()) return;
    final url = widget.repair.endpoint.toString();
    final secret = _secret.text;
    setState(() {
      _checking = true;
      _assessment = null;
      _saveFailed = false;
    });
    final result = await widget.hosts.probe(Uri.parse(url), secret);
    if (!mounted || url != _url.text.trim() || secret != _secret.text) return;
    setState(() {
      _checking = false;
      _assessment = result;
      _testedUrl = url;
      _testedSecret = secret;
    });
    final retryAt = result?.retryAt;
    if (retryAt != null) {
      _retryTimer?.cancel();
      final delay = retryAt.difference(DateTime.now().toUtc());
      if (!delay.isNegative) {
        _retryTimer = Timer(delay, () {
          if (mounted) setState(() {});
        });
      }
    }
    if (result?.status == EndpointStatus.legacyServer && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const LegacyEndpointPage()),
      );
    }
  }

  Future<void> _save() async {
    final result = _assessment;
    if (result == null ||
        !result.canUse ||
        _testedUrl != _url.text.trim() ||
        _testedSecret != _secret.text ||
        _testedUrl != widget.repair.endpoint.toString() ||
        _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await widget.hosts.repair(
      widget.repair,
      EndpointCredential(kind: EndpointAuthKind.password, secret: _secret.text),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _saveFailed = true;
        _assessment = null;
        _testedUrl = null;
        _testedSecret = null;
      });
    }
  }

  @override
  void dispose() {
    widget.hosts.cancelProbe();
    _retryTimer?.cancel();
    _testedSecret = null;
    _secret.clear();
    for (final controller in [_url, _label, _secret]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    return ModalPrimaryActionShortcuts(
      enabled: !_saving && _assessment?.canUse == true,
      onPrimaryAction: _save,
      child: AlertDialog(
        title: Text(l.onboardingPassword),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const ValueKey('endpoint-url'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enabled: false,
                  decoration: InputDecoration(labelText: l.onboardingServerUrl),
                  onChanged: (_) => _invalidate(),
                  validator: (text) {
                    try {
                      EndpointProfile.validateEndpoint(Uri.parse(text!.trim()));
                      return null;
                    } on Object {
                      return l.onboardingInvalidUrl;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('endpoint-label'),
                  controller: _label,
                  enabled: false,
                  maxLength: 160,
                  decoration: InputDecoration(labelText: l.onboardingLabel),
                ),
                TextFormField(
                  key: const ValueKey('endpoint-secret'),
                  controller: _secret,
                  enabled: !_saving,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: l.onboardingPassword),
                  onChanged: (_) => _invalidate(),
                  validator: (text) => text?.isNotEmpty == true
                      ? null
                      : l.onboardingPasswordRequired,
                ),
                if (_checking || _saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: AppIndeterminateBar(),
                  ),
                if (_assessment case final assessment?)
                  EndpointStatusView(assessment: assessment),
                if (_saveFailed) Text(l.hostsProfileStorageError),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l.commonCancel),
          ),
          TextButton(
            key: const ValueKey('probe-endpoint'),
            onPressed:
                _checking ||
                    _saving ||
                    _assessment?.retryDeferred == true ||
                    (_assessment?.retryAt?.isAfter(DateTime.now().toUtc()) ??
                        false)
                ? null
                : _check,
            child: Text(l.hostsCheckConnection),
          ),
          FilledButton(
            key: const ValueKey('save-endpoint'),
            onPressed: !_saving && _assessment?.canUse == true ? _save : null,
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
  }
}
