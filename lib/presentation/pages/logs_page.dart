import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy logs',
            onPressed: () => _copyLogs(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () => AppLogger.clearEntries(),
          ),
        ],
      ),
      body: ValueListenableBuilder<UnmodifiableListView<LogEntry>>(
        valueListenable: AppLogger.entries,
        builder: (context, entries, child) {
          if (entries.isEmpty) {
            return const Center(child: Text('No logs captured yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[entries.length - 1 - index];
              return _LogTile(entry: entry);
            },
          );
        },
      ),
    );
  }

  Future<void> _copyLogs(BuildContext context) async {
    final entries = AppLogger.entries.value;
    final text = entries.map(_formatEntry).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard')));
  }

  String _formatEntry(LogEntry entry) {
    final base =
        '[${entry.timestamp.toIso8601String()}] ${entry.level.name.toUpperCase()} ${entry.message}';
    if (entry.error == null || entry.error!.isEmpty) {
      return base;
    }
    return '$base | error=${entry.error}';
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;

  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (entry.level) {
      LogLevel.debug => colorScheme.secondary,
      LogLevel.info => colorScheme.primary,
      LogLevel.warn => Colors.orange.shade300,
      LogLevel.error => colorScheme.error,
    };

    final subtitle = StringBuffer(
      '${entry.timestamp.toIso8601String()}\n${entry.message}',
    );
    if (entry.error != null && entry.error!.isNotEmpty) {
      subtitle.write('\nError: ${entry.error}');
    }
    if (entry.stackTrace != null && entry.stackTrace!.isNotEmpty) {
      subtitle.write('\nStack: ${entry.stackTrace}');
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: ListTile(
        title: Text(
          entry.level.name.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
