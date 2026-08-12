import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/l10n_context.dart';
import '../providers/app_provider.dart';
import '../services/local_opencode_server_runtime_types.dart';

class OpenCodeSetupDebugPage extends StatelessWidget {
  const OpenCodeSetupDebugPage({super.key});

  Future<void> _copyReport(BuildContext context) async {
    final report = context.read<AppProvider>().exportSetupDebugReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.msgSetupDebugCopied)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        final entries = appProvider.setupDebugEntries.reversed.toList(
          growable: false,
        );
        final setupLogs = appProvider.localSetupLogs.reversed.toList(
          growable: false,
        );
        final hasDebugContent =
            entries.isNotEmpty ||
            setupLogs.isNotEmpty ||
            appProvider.localServerLastOutput.trim().isNotEmpty ||
            appProvider.localEnvironmentReport != null;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.setupDebugOpenCodeSetupDebug),
            actions: [
              IconButton(
                icon: const Icon(Symbols.copy_all),
                tooltip: context.l10n.setupDebugCopySetupDebug,
                onPressed: hasDebugContent ? () => _copyReport(context) : null,
              ),
              IconButton(
                icon: const Icon(Symbols.delete_outline),
                tooltip: context.l10n.setupDebugClearSetupDebug,
                onPressed: hasDebugContent
                    ? appProvider.clearSetupDebugData
                    : null,
              ),
            ],
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SetupDebugCard(
                        title: context.l10n.setupDebugFocusedOpenCodeSetup,
                        icon: Symbols.terminal_rounded,
                        child: Text(
                          context.l10n.setupDebugScreenCoversOpenCode,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SetupDebugCard(
                        title: context.l10n.setupDebugCurrentStatus,
                        icon: Symbols.info_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appProvider.localServerStatusMessage),
                            if (appProvider.localSetupMessage
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                appProvider.localSetupMessage,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (appProvider.localSetupInProgress) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(minHeight: 3),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SetupDebugCard(
                        title: context.l10n.setupDebugEnvironmentDiagnostics,
                        icon: Symbols.health_and_safety_rounded,
                        child: _EnvironmentDetails(
                          report: appProvider.localEnvironmentReport,
                          commandPath: appProvider.localServerCommandPath,
                        ),
                      ),
                      if (entries.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SetupDebugCard(
                          title: context.l10n.setupDebugTimeline2,
                          icon: Symbols.history_rounded,
                          child: Column(
                            children: [
                              for (var i = 0; i < entries.length; i++) ...[
                                _SetupDebugEntryTile(entry: entries[i]),
                                if (i < entries.length - 1)
                                  const Divider(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (appProvider.localServerLastOutput
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SetupDebugCard(
                          title: context.l10n.setupDebugLatestLocalServer,
                          icon: Symbols.speaker_notes_rounded,
                          child: _MonospaceBlock(
                            text: appProvider.localServerLastOutput,
                          ),
                        ),
                      ],
                      if (setupLogs.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SetupDebugCard(
                          title: context.l10n.setupDebugCapturedSetupLogs,
                          icon: Symbols.article_rounded,
                          child: _MonospaceBlock(text: setupLogs.join('\n')),
                        ),
                      ],
                      if (!hasDebugContent) ...[
                        const SizedBox(height: 12),
                        _SetupDebugCard(
                          title: context.l10n.setupDebugCapturedSetupDetails,
                          icon: Symbols.inbox_rounded,
                          child: Text(context.l10n.setupDebugRunDiagnosticsTry),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SetupDebugCard(
                        title: context.l10n.setupDebugManualTroubleshooting,
                        icon: Symbols.build_circle_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.setupDebugCodeWalkCaptureEnough),
                            const SizedBox(height: 8),
                            Text(
                              '• ${context.l10n.setupDebugLinuxLogsPath('~/.local/share/opencode/log/')}',
                            ),
                            Text(
                              '• ${context.l10n.setupDebugRunOpenCodeCommand('opencode --log-level DEBUG')}',
                            ),
                            Text(
                              '• ${context.l10n.setupDebugServerHealthEndpoint('GET /global/health')}',
                            ),
                            Text(
                              '• ${context.l10n.setupDebugServerDocsEndpoint('GET /doc')}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SetupDebugCard extends StatelessWidget {
  const _SetupDebugCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EnvironmentDetails extends StatelessWidget {
  const _EnvironmentDetails({required this.report, required this.commandPath});

  final LocalOpencodeEnvironmentReport? report;
  final String commandPath;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return Text(context.l10n.setupDebugDiagnosticsLoading);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: context.l10n.setupDebugPlatform2,
          value: report!.platform,
        ),
        if (commandPath.trim().isNotEmpty)
          _InfoRow(
            label: context.l10n.setupDebugCommandPath2,
            value: commandPath.trim(),
          ),
        _ToolStatusRow(
          label: context.l10n.setupDebugOpenCode2,
          status: report!.opencode,
        ),
        _ToolStatusRow(
          label: context.l10n.setupDebugNode,
          status: report!.node,
        ),
        _ToolStatusRow(label: context.l10n.setupDebugNpm2, status: report!.npm),
        _ToolStatusRow(label: context.l10n.setupDebugBun2, status: report!.bun),
        _ToolStatusRow(label: context.l10n.setupDebugWSL, status: report!.wsl),
        _InfoRow(
          label: context.l10n.setupDebugNetwork2,
          value: report!.hasNetworkAccess
              ? context.l10n.onboardingReachable
              : context.l10n.onboardingUnreachable,
        ),
        _InfoRow(
          label: context.l10n.setupDebugInstallDirectory,
          value: report!.installDirectoryWritable
              ? context.l10n.onboardingWritable
              : context.l10n.onboardingNotWritable,
        ),
        const SizedBox(height: 8),
        Text(
          report!.recommendation,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 124, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ToolStatusRow extends StatelessWidget {
  const _ToolStatusRow({required this.label, required this.status});

  final String label;
  final LocalToolStatus status;

  @override
  Widget build(BuildContext context) {
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

    return _InfoRow(
      label: label,
      value: details.isEmpty
          ? (status.available
                ? context.l10n.onboardingAvailable
                : context.l10n.onboardingNotAvailable)
          : details.join(' | '),
    );
  }
}

class _SetupDebugEntryTile extends StatelessWidget {
  const _SetupDebugEntryTile({required this.entry});

  final SetupDebugEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = entry.severity == SetupDebugSeverity.error
        ? colorScheme.error
        : colorScheme.primary;
    final time = TimeOfDay.fromDateTime(entry.timestamp).format(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Symbols.circle, size: 10, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.setupDebugTimeEntrySource(entry.source, time),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(entry.message),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonospaceBlock extends StatelessWidget {
  const _MonospaceBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
