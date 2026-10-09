import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_preferences_controller.dart';
import '../../shared/diagnostics/diagnostics_controller.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';

class DiagnosticsSettingsPage extends StatefulWidget {
  const DiagnosticsSettingsPage({super.key});

  @override
  State<DiagnosticsSettingsPage> createState() =>
      _DiagnosticsSettingsPageState();
}

class _DiagnosticsSettingsPageState extends State<DiagnosticsSettingsPage> {
  DiagnosticOperation? _operation;
  DiagnosticSeverity? _severity;
  DiagnosticOutcome? _outcome;
  bool _copying = false;

  Future<void> _copy(DiagnosticsController diagnostics) async {
    if (_copying) return;
    setState(() => _copying = true);
    final result = await diagnostics.copyFiltered(
      operation: _operation,
      severity: _severity,
      outcome: _outcome,
      write: (text) => Clipboard.setData(ClipboardData(text: text)),
    );
    if (!mounted) return;
    setState(() => _copying = false);
    final l = context.v2L10n;
    final message = switch (result) {
      DiagnosticCopyResult.copied => l.commonCopiedToClipboard,
      DiagnosticCopyResult.truncated => l.diagnosticsCopyTruncated,
      DiagnosticCopyResult.failed => l.diagnosticsCopyFailed,
      DiagnosticCopyResult.invalidated => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferencesController>();
    final diagnostics = context.watch<DiagnosticsController?>();
    final l = context.v2L10n;
    final enabled = diagnostics?.enabled == true && preferences.loggingEnabled;
    final events = enabled
        ? diagnostics!.events
              .where(
                (event) =>
                    (_operation == null || event.operation == _operation) &&
                    (_severity == null || event.severity == _severity) &&
                    (_outcome == null || event.outcome == _outcome),
              )
              .toList()
              .reversed
              .toList()
        : <DiagnosticEvent>[];
    return ListView(
      key: const ValueKey('settings_logs_page'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(l.logsAppLogs, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(l.diagnosticsPrivacy),
        SwitchListTile(
          key: const ValueKey('settings_logging_enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.logsEnableLogging),
          subtitle: Text(l.logsEnableLoggingDescription),
          value: preferences.loggingEnabled,
          onChanged: diagnostics == null ? null : preferences.setLoggingEnabled,
        ),
        if (preferences.hasPersistenceError) ...[
          Text(l.settingsStorageError),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: preferences.retryPersistence,
              child: Text(l.chatRetry),
            ),
          ),
        ],
        if (!enabled) ...[
          Text(
            l.logsLoggingDisabledTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(l.logsLoggingDisabledDescription),
        ] else ...[
          DropdownButtonFormField<DiagnosticOperation>(
            key: const ValueKey('logs_operation_filter'),
            isExpanded: true,
            itemHeight: null,
            hint: Text(l.logsFilterAll),
            initialValue: _operation,
            decoration: InputDecoration(labelText: l.logsAppLogs),
            items: [
              DropdownMenuItem(value: null, child: Text(l.logsFilterAll)),
              for (final operation in DiagnosticOperation.values)
                DropdownMenuItem(
                  value: operation,
                  child: Text(diagnosticOperationLabel(l, operation)),
                ),
            ],
            onChanged: (value) => setState(() => _operation = value),
          ),
          const SizedBox(height: 12),
          Text(l.logsLevel),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(l.logsFilterAll),
                selected: _severity == null,
                onSelected: (_) => setState(() => _severity = null),
              ),
              for (final severity in DiagnosticSeverity.values)
                ChoiceChip(
                  label: Text(diagnosticSeverityLabel(l, severity)),
                  selected: severity == _severity,
                  onSelected: (_) => setState(() => _severity = severity),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(l.logsFilterAll),
                selected: _outcome == null,
                onSelected: (_) => setState(() => _outcome = null),
              ),
              for (final outcome in DiagnosticOutcome.values)
                ChoiceChip(
                  label: Text(diagnosticOutcomeLabel(l, outcome)),
                  selected: outcome == _outcome,
                  onSelected: (_) => setState(() => _outcome = outcome),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('logs_copy_filtered'),
                onPressed: _copying || events.isEmpty
                    ? null
                    : () => _copy(diagnostics!),
                icon: const Icon(Icons.copy_outlined),
                label: Text(l.logsCopyFiltered),
              ),
              TextButton.icon(
                onPressed: diagnostics!.events.isEmpty
                    ? null
                    : diagnostics.clear,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.logsClear),
              ),
            ],
          ),
          if (events.isEmpty)
            Text(
              diagnostics.events.isEmpty
                  ? l.logsNoLogsYet
                  : l.logsNoMatchingLogs,
            ),
          for (final event in events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diagnosticOperationLabel(l, event.operation),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${diagnosticOutcomeLabel(l, event.outcome)} · ${diagnosticSeverityLabel(l, event.severity)}',
                  ),
                  Text(
                    event.timestamp.toIso8601String(),
                    textDirection: TextDirection.ltr,
                  ),
                  if (event.elapsedMs != null)
                    Text(
                      l.logsPerformanceDuration(event.elapsedMs!),
                      textDirection: TextDirection.ltr,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

String diagnosticOperationLabel(
  V2Localizations l,
  DiagnosticOperation operation,
) => switch (operation) {
  DiagnosticOperation.hostCatalogLoad => l.diagnosticsHostCatalog,
  DiagnosticOperation.hostProbe => l.diagnosticsHostProbe,
  DiagnosticOperation.profileSave => l.diagnosticsProfileSave,
  DiagnosticOperation.profileRemove => l.diagnosticsProfileRemove,
  DiagnosticOperation.preferencesLoad => l.diagnosticsPreferencesLoad,
  DiagnosticOperation.preferencesSave => l.diagnosticsPreferencesSave,
  DiagnosticOperation.archiveLoad => l.diagnosticsArchiveLoad,
  DiagnosticOperation.archiveSave => l.diagnosticsArchiveSave,
};

String diagnosticOutcomeLabel(V2Localizations l, DiagnosticOutcome outcome) =>
    switch (outcome) {
      DiagnosticOutcome.success => l.logsTaskStatusOk,
      DiagnosticOutcome.failure => l.logsTaskStatusError,
      DiagnosticOutcome.cancelled => l.logsTaskStatusCanceled,
    };

String diagnosticSeverityLabel(
  V2Localizations l,
  DiagnosticSeverity severity,
) => switch (severity) {
  DiagnosticSeverity.info => l.diagnosticsInfo,
  DiagnosticSeverity.warning => l.diagnosticsWarning,
  DiagnosticSeverity.error => l.diagnosticsError,
};
