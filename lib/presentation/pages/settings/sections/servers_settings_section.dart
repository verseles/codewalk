import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/server_profile.dart';
import '../../../providers/app_provider.dart';

class ServersSettingsSection extends StatefulWidget {
  const ServersSettingsSection({super.key});

  @override
  State<ServersSettingsSection> createState() => _ServersSettingsSectionState();
}

enum _ServerAction { activate, setDefault, clearDefault, edit, delete, check }

class _ServersSettingsSectionState extends State<ServersSettingsSection> {
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

        return Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.read<AppProvider>().refreshServerHealth(),
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: const Text('Refresh Health'),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Server'),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              _buildActiveServerCard(appProvider),
              const SizedBox(height: AppConstants.defaultPadding),
              Expanded(
                child: profiles.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: profiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) => _buildProfileTile(
                          appProvider: appProvider,
                          profile: profiles[index],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveServerCard(AppProvider appProvider) {
    final activeServer = appProvider.activeServer;
    final activeId = appProvider.activeServerId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Server',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: activeId,
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
                if (id == null || id == activeId) return;
                final status = appProvider.healthFor(id);
                if (status == ServerHealthStatus.unhealthy) {
                  _showMessage(
                    'This server is unhealthy. Use check health or edit settings before activating.',
                  );
                  return;
                }

                final ok = await appProvider.setActiveServer(id);
                if (!ok && mounted) {
                  _showMessage(appProvider.errorMessage);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Choose active server',
                border: OutlineInputBorder(),
              ),
            ),
            if (activeServer != null) ...[
              const SizedBox(height: 10),
              Text(
                activeServer.url,
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
            if (isActive) const _MetaChip(label: 'Active'),
            if (isDefault) const _MetaChip(label: 'Default'),
          ],
        ),
        subtitle: Text(
          profile.url,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_ServerAction>(
          onSelected: (action) => _handleServerAction(
            appProvider: appProvider,
            profile: profile,
            action: action,
          ),
          itemBuilder: (_) => [
            if (!isActive)
              const PopupMenuItem(
                value: _ServerAction.activate,
                child: Text('Set Active'),
              ),
            if (!isDefault)
              const PopupMenuItem(
                value: _ServerAction.setDefault,
                child: Text('Set Default'),
              ),
            if (isDefault)
              const PopupMenuItem(
                value: _ServerAction.clearDefault,
                child: Text('Clear Default'),
              ),
            const PopupMenuItem(
              value: _ServerAction.check,
              child: Text('Check Health'),
            ),
            const PopupMenuItem(value: _ServerAction.edit, child: Text('Edit')),
            const PopupMenuItem(
              value: _ServerAction.delete,
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            'No servers configured',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add at least one OpenCode server to start using the app.',
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
          _showMessage('Cannot activate an unhealthy server');
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
        await _openEditDialog(profile);
        break;
      case _ServerAction.delete:
        await _confirmDelete(profile);
        break;
      case _ServerAction.check:
        await appProvider.refreshServerHealth(serverId: profile.id);
        break;
    }
  }

  Future<void> _openCreateDialog() async {
    await _openProfileDialog(initial: null);
  }

  Future<void> _openEditDialog(ServerProfile profile) async {
    await _openProfileDialog(initial: profile);
  }

  Future<void> _openProfileDialog({ServerProfile? initial}) async {
    final urlController = TextEditingController(text: initial?.url ?? '');
    final labelController = TextEditingController(text: initial?.label ?? '');
    final usernameController = TextEditingController(
      text: initial?.basicAuthUsername ?? '',
    );
    final passwordController = TextEditingController(
      text: initial?.basicAuthPassword ?? '',
    );
    var basicAuthEnabled = initial?.basicAuthEnabled ?? false;
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(initial == null ? 'Add Server' : 'Edit Server'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'Server URL',
                          hintText: 'http://127.0.0.1:4096',
                        ),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) return 'Enter a server URL';
                          try {
                            AppProvider.normalizeServerUrl(raw);
                            return null;
                          } catch (_) {
                            return 'Invalid URL';
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: labelController,
                        decoration: const InputDecoration(
                          labelText: 'Label (optional)',
                          hintText: 'Office server',
                        ),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: basicAuthEnabled,
                        onChanged: (value) {
                          setState(() {
                            basicAuthEnabled = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use Basic Auth'),
                      ),
                      if (basicAuthEnabled) ...[
                        TextFormField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          validator: (value) {
                            if (!basicAuthEnabled) return null;
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (!basicAuthEnabled) return null;
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter password';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true || !mounted) {
      urlController.dispose();
      labelController.dispose();
      usernameController.dispose();
      passwordController.dispose();
      return;
    }

    final appProvider = context.read<AppProvider>();
    final adjustedUrl = _mapAndroidLoopback(urlController.text.trim());
    final success = initial == null
        ? await appProvider.addServerProfile(
            url: adjustedUrl,
            label: labelController.text.trim(),
            basicAuthEnabled: basicAuthEnabled,
            basicAuthUsername: usernameController.text.trim(),
            basicAuthPassword: passwordController.text.trim(),
            setAsActive: appProvider.serverProfiles.isEmpty,
          )
        : await appProvider.updateServerProfile(
            id: initial.id,
            url: adjustedUrl,
            label: labelController.text.trim(),
            basicAuthEnabled: basicAuthEnabled,
            basicAuthUsername: usernameController.text.trim(),
            basicAuthPassword: passwordController.text.trim(),
          );

    if (!success) {
      _showMessage(appProvider.errorMessage);
    } else if (kIsWeb == false &&
        defaultTargetPlatform == TargetPlatform.android &&
        adjustedUrl.contains('10.0.2.2') &&
        urlController.text.contains('localhost')) {
      _showMessage('Android emulator detected: localhost mapped to 10.0.2.2');
    }

    urlController.dispose();
    labelController.dispose();
    usernameController.dispose();
    passwordController.dispose();
  }

  Future<void> _confirmDelete(ServerProfile profile) async {
    final appProvider = context.read<AppProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete server'),
          content: Text('Remove "${profile.displayName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.status});

  final ServerHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, tooltip) = switch (status) {
      ServerHealthStatus.healthy => (Colors.green, 'Healthy'),
      ServerHealthStatus.unhealthy => (Colors.red, 'Unhealthy'),
      ServerHealthStatus.unknown => (Colors.grey, 'Unknown'),
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
