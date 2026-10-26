import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/workspace_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../sessions/sessions_controller.dart';
import 'endpoint_health_controller.dart';
import 'endpoint_health_view.dart';

List<EndpointProfile> filterSavedServers(
  List<EndpointProfile> profiles,
  String query,
) {
  final needle = query.trim().toLowerCase();
  return profiles
      .where(
        (profile) =>
            needle.isEmpty ||
            profile.label.toLowerCase().contains(needle) ||
            profile.endpoint.toString().toLowerCase().contains(needle) ||
            profile.id.toLowerCase().contains(needle),
      )
      .toList();
}

Future<bool> selectWorkspaceServer(
  BuildContext context,
  EndpointProfile profile,
) async {
  final catalog = context.read<SessionsController?>();
  if (catalog == null) return false;
  final workspace = context.read<WorkspaceController?>();
  final health = context.read<EndpointHealthController?>();
  final l = context.v2L10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = workspace != null
      ? await workspace.selectServer(profile.id)
      : catalog.selectedProfile?.id == profile.id
      ? ServerSwitchResult.unchanged
      : health?.view(profile).status == EndpointHealthStatus.offline
      ? ServerSwitchResult.unhealthy
      : catalog.loading
      ? ServerSwitchResult.busy
      : await _select(catalog, profile);
  if (result == ServerSwitchResult.selected ||
      result == ServerSwitchResult.unchanged) {
    return true;
  }
  if (result != ServerSwitchResult.busy) {
    final reason = result == ServerSwitchResult.unhealthy && health != null
        ? endpointHealthReason(l, health.view(profile))
        : l.hostsProfileStorageError;
    messenger?.showSnackBar(
      SnackBar(content: Text(reason ?? l.hostsTransportHelp)),
    );
  }
  return false;
}

Future<ServerSwitchResult> _select(
  SessionsController catalog,
  EndpointProfile profile,
) async {
  await catalog.selectProfile(profile.id);
  return catalog.selectedProfile?.id == profile.id
      ? ServerSwitchResult.selected
      : ServerSwitchResult.unavailable;
}

/// The header and its menu share the same observed endpoint status.
class ServerSwitcher extends StatelessWidget {
  const ServerSwitcher({
    super.key,
    this.controlKey = const ValueKey('sessions-profile'),
  });
  final Key controlKey;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<SessionsController?>();
    final health = context.watch<EndpointHealthController?>();
    final workspace = context.watch<WorkspaceController?>();
    final profile = catalog?.selectedProfile;
    return TextButton(
      key: controlKey,
      onPressed:
          catalog == null ||
              catalog.hosts.loading ||
              catalog.hosts.storageError ||
              workspace?.switchingServer == true
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => _ServerPicker(
                catalog: catalog,
                health: health,
                workspace: workspace,
              ),
            ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              profile?.label ?? context.v2L10n.sessionsSelectProfile,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (profile != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: EndpointHealthIndicator(
                view: health?.view(profile) ?? const EndpointHealthView(),
              ),
            ),
          ],
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _ServerPicker extends StatefulWidget {
  const _ServerPicker({
    required this.catalog,
    required this.health,
    required this.workspace,
  });
  final SessionsController catalog;
  final EndpointHealthController? health;
  final WorkspaceController? workspace;
  @override
  State<_ServerPicker> createState() => _ServerPickerState();
}

class _ServerPickerState extends State<_ServerPicker> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.catalog,
      widget.health,
      widget.workspace,
      _search,
    ]),
    builder: (context, _) {
      final l = context.v2L10n;
      final profiles = filterSavedServers(
        widget.catalog.hosts.profiles,
        _search.text,
      );
      final media = MediaQuery.of(context);
      return Dialog(
        child: SizedBox(
          width: 440,
          height: min(
            520,
            max(120, media.size.height - media.viewInsets.bottom - 80),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('server-switcher-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: l.serversSearchActiveHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                Expanded(
                  child: profiles.isEmpty
                      ? Center(child: Text(l.settingsNavigationNoResults))
                      : ListView(
                          children: [
                            for (final profile in profiles)
                              ListTile(
                                key: ValueKey('server-switch-${profile.id}'),
                                selected:
                                    widget.catalog.selectedProfile?.id ==
                                    profile.id,
                                enabled:
                                    widget.workspace?.switchingServer != true,
                                title: Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(profile.label),
                                    EndpointHealthIndicator(
                                      view:
                                          widget.health?.view(profile) ??
                                          const EndpointHealthView(),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  profile.endpoint.toString(),
                                  textDirection: TextDirection.ltr,
                                ),
                                onTap: () async {
                                  if (await selectWorkspaceServer(
                                        context,
                                        profile,
                                      ) &&
                                      context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                          ],
                        ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.commonCancel),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
