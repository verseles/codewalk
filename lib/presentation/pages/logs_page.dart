import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../providers/settings_provider.dart';

enum _LogTimeRange {
  oneMinute(Duration(minutes: 1), '1m'),
  fiveMinutes(Duration(minutes: 5), '5m'),
  fifteenMinutes(Duration(minutes: 15), '15m'),
  oneHour(Duration(hours: 1), '1h'),
  all(null, null);

  const _LogTimeRange(this.duration, this.label);

  final Duration? duration;
  final String? label;
}

const List<String> _commonLogTags = <String>[
  'task:select_session',
  'task:load_messages',
  'task:load_sessions',
  'task:hydrate_cache',
  'task:realtime_event',
  'network:http',
  'network:sse',
  'cache:read',
  'cache:write',
];

String _taskStatusLabel(BuildContext context, String? status) {
  return switch (status) {
    'error' => context.l10n.logsTaskStatusError,
    'canceled' || 'cancelled' => context.l10n.logsTaskStatusCanceled,
    _ => context.l10n.logsTaskStatusOk,
  };
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _searchController = TextEditingController();
  _LogTimeRange _timeRange = _LogTimeRange.fifteenMinutes;
  Set<LogLevel> _levels = LogLevel.values.toSet();
  Set<String> _tags = const <String>{};
  bool _searchEnabled = false;
  bool _performanceOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LogEntry> _filteredEntries({bool forcePerformance = false}) {
    final entries = AppLogger.filteredEntries(
      timeRange: _timeRange.duration,
      levels: _levels,
      tags: _tags.isEmpty ? null : _tags,
      query: _searchController.text,
    );
    if (!_performanceOnly && !forcePerformance) {
      return entries;
    }
    return entries
        .where((entry) => entry.isPerformance)
        .toList(growable: false);
  }

  bool get _hasSelectedTaskTag => _tags.any((tag) => tag.startsWith('task:'));

  List<LogEntry> _slowestPerformanceEntries() {
    final entries = _filteredEntries(
      forcePerformance: true,
    ).where((entry) => entry.elapsedMs != null).toList(growable: false);
    entries.sort((a, b) => b.elapsedMs!.compareTo(a.elapsedMs!));
    return entries;
  }

  bool _hasPerformanceEntries() {
    return _filteredEntries(
      forcePerformance: true,
    ).any((entry) => entry.elapsedMs != null);
  }

  List<LogEntry> _slowestTaskEntries() {
    final selectedTaskTags = _tags
        .where((tag) => tag.startsWith('task:'))
        .toSet();
    final entries = _filteredEntries()
        .where(
          (entry) =>
              entry.isTaskEnd &&
              !entry.isPerformance &&
              entry.elapsedMs != null &&
              (selectedTaskTags.isEmpty ||
                  entry.tags.intersection(selectedTaskTags).isNotEmpty),
        )
        .toList(growable: false);
    entries.sort((a, b) => b.elapsedMs!.compareTo(a.elapsedMs!));
    return entries;
  }

  bool _hasTaskEntries() {
    return _slowestTaskEntries().isNotEmpty;
  }

  void _showSlowestPerformance(BuildContext context) {
    final entries = _slowestPerformanceEntries();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.logsSlowestPerformance,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(context.l10n.logsNoPerformanceData),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final elapsedMs = entry.elapsedMs ?? 0;
                            final operation =
                                entry.performanceOperation ?? entry.message;
                            final status = entry.performanceStatus ?? 'ok';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(operation),
                              subtitle: Text(
                                '${entry.timestamp.toIso8601String()} • $status',
                              ),
                              trailing: Text(
                                context.l10n.logsPerformanceDuration(elapsedMs),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSlowestTasks(BuildContext context) {
    final entries = _slowestTaskEntries();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.logsSlowestTasks,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      Expanded(
                        child: Center(child: Text(context.l10n.logsNoTaskData)),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final elapsedMs = entry.elapsedMs ?? 0;
                            final operation =
                                entry.taskOperation ?? entry.message;
                            final status = _taskStatusLabel(
                              context,
                              entry.taskStatus,
                            );
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                context.l10n.logsTaskDuration(
                                  elapsedMs,
                                  operation,
                                ),
                              ),
                              subtitle: Text(
                                '${entry.timestamp.toIso8601String()} • $status',
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCustomTagDialog(BuildContext context) async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.logsFilterByTag),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.logsTagCustomHint,
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(context.l10n.commonSave),
            ),
          ],
        );
      },
    );
    if (context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    } else {
      controller.dispose();
    }
    final normalized = tag?.trim();
    if (normalized == null || normalized.isEmpty || !context.mounted) {
      return;
    }
    setState(() {
      _tags = Set<String>.from(_tags)..add(normalized);
    });
  }

  Future<void> _copyLogs(BuildContext context, List<LogEntry> entries) async {
    final text = AppLogger.exportEntries(entries: entries);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.msgFilteredLogsCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final loggingEnabled = settingsProvider.loggingEnabled;
    return Scaffold(
      appBar: AppBar(
        title: _searchEnabled
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: context.l10n.logsSearch,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(context.l10n.logsAppLogs),
        actions: [
          if (_searchEnabled)
            IconButton(
              icon: const Icon(Symbols.close),
              tooltip: context.l10n.logsCloseSearch,
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchEnabled = false;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Symbols.search),
              tooltip: context.l10n.logsSearch,
              onPressed: loggingEnabled
                  ? () {
                      setState(() {
                        _searchEnabled = true;
                      });
                    }
                  : null,
            ),
          ValueListenableBuilder<UnmodifiableListView<LogEntry>>(
            valueListenable: AppLogger.entries,
            builder: (context, _, _) {
              final showTasks = _hasSelectedTaskTag;
              final hasData = showTasks
                  ? _hasTaskEntries()
                  : _hasPerformanceEntries();
              return IconButton(
                icon: const Icon(Symbols.timer),
                tooltip: showTasks
                    ? context.l10n.logsSlowestTasks
                    : context.l10n.logsSlowestPerformance,
                onPressed: loggingEnabled && hasData
                    ? () => showTasks
                          ? _showSlowestTasks(context)
                          : _showSlowestPerformance(context)
                    : null,
              );
            },
          ),
          ValueListenableBuilder<UnmodifiableListView<LogEntry>>(
            valueListenable: AppLogger.entries,
            builder: (context, _, _) {
              final filtered = _filteredEntries();
              return IconButton(
                icon: const Icon(Symbols.copy_all),
                tooltip: context.l10n.logsCopyFiltered,
                onPressed: !loggingEnabled || filtered.isEmpty
                    ? null
                    : () => _copyLogs(context, filtered),
              );
            },
          ),
          IconButton(
            icon: const Icon(Symbols.delete_outline),
            tooltip: context.l10n.logsClear,
            onPressed: AppLogger.clearEntries,
          ),
        ],
      ),
      body: ValueListenableBuilder<UnmodifiableListView<LogEntry>>(
        valueListenable: AppLogger.entries,
        builder: (context, entries, child) {
          final filtered = loggingEnabled
              ? _filteredEntries()
              : const <LogEntry>[];
          final ordered = filtered.reversed.toList(growable: false);
          final totalEntries = loggingEnabled ? entries.length : 0;
          final toolbarMaxHeight = (MediaQuery.sizeOf(context).height * 0.55)
              .clamp(220.0, 360.0)
              .toDouble();

          return Column(
            children: [
              SizedBox(
                height: toolbarMaxHeight,
                child: SingleChildScrollView(
                  child: _LogsToolbar(
                    loggingEnabled: loggingEnabled,
                    selectedRange: _timeRange,
                    selectedLevels: _levels,
                    selectedTags: _tags,
                    performanceLoggingEnabled:
                        settingsProvider.performanceLoggingEnabled,
                    performanceFilterOnly: _performanceOnly,
                    onRangeChanged: (value) {
                      setState(() {
                        _timeRange = value;
                      });
                    },
                    onLevelToggled: (level) {
                      setState(() {
                        if (_levels.contains(level)) {
                          if (_levels.length > 1) {
                            _levels = Set<LogLevel>.from(_levels)
                              ..remove(level);
                          }
                        } else {
                          _levels = Set<LogLevel>.from(_levels)..add(level);
                        }
                      });
                    },
                    onTagToggled: (tag) {
                      setState(() {
                        final next = Set<String>.from(_tags);
                        if (next.contains(tag)) {
                          next.remove(tag);
                        } else {
                          next.add(tag);
                        }
                        _tags = next;
                      });
                    },
                    onCustomTagRequested: () => _showCustomTagDialog(context),
                    onLoggingChanged: (enabled) {
                      unawaited(
                        context.read<SettingsProvider>().setLoggingEnabled(
                          enabled,
                        ),
                      );
                    },
                    onPerformanceLoggingChanged: (enabled) {
                      unawaited(
                        context
                            .read<SettingsProvider>()
                            .setPerformanceLoggingEnabled(enabled),
                      );
                    },
                    onPerformanceFilterToggled: () {
                      setState(() {
                        _performanceOnly = !_performanceOnly;
                      });
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: !loggingEnabled
                    ? _LogsDisabledState(
                        onEnable: () {
                          unawaited(
                            context.read<SettingsProvider>().setLoggingEnabled(
                              true,
                            ),
                          );
                        },
                      )
                    : ordered.isEmpty
                    ? Center(
                        child: Text(
                          entries.isEmpty
                              ? context.l10n.logsNoLogsYet
                              : context.l10n.logsNoMatchingLogs,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: ordered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _LogTile(entry: ordered[index]);
                        },
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Text(
                  context.l10n.logsShowingOrderedLength(
                    ordered.length,
                    totalEntries,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogsToolbar extends StatelessWidget {
  const _LogsToolbar({
    required this.loggingEnabled,
    required this.selectedRange,
    required this.selectedLevels,
    required this.selectedTags,
    required this.performanceLoggingEnabled,
    required this.performanceFilterOnly,
    required this.onRangeChanged,
    required this.onLevelToggled,
    required this.onTagToggled,
    required this.onCustomTagRequested,
    required this.onLoggingChanged,
    required this.onPerformanceLoggingChanged,
    required this.onPerformanceFilterToggled,
  });

  final bool loggingEnabled;
  final _LogTimeRange selectedRange;
  final Set<LogLevel> selectedLevels;
  final Set<String> selectedTags;
  final bool performanceLoggingEnabled;
  final bool performanceFilterOnly;
  final ValueChanged<_LogTimeRange> onRangeChanged;
  final ValueChanged<LogLevel> onLevelToggled;
  final ValueChanged<String> onTagToggled;
  final VoidCallback onCustomTagRequested;
  final ValueChanged<bool> onLoggingChanged;
  final ValueChanged<bool> onPerformanceLoggingChanged;
  final VoidCallback onPerformanceFilterToggled;

  @override
  Widget build(BuildContext context) {
    final customTags =
        selectedTags
            .where((tag) => !_commonLogTags.contains(tag))
            .toList(growable: false)
          ..sort();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.logsEnableLogging),
            subtitle: Text(context.l10n.logsEnableLoggingDescription),
            value: loggingEnabled,
            onChanged: onLoggingChanged,
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.logsMeasurePerformance),
            subtitle: Text(context.l10n.logsMeasurePerformanceDescription),
            value: performanceLoggingEnabled,
            onChanged: loggingEnabled ? onPerformanceLoggingChanged : null,
          ),
          const Divider(height: 24),
          Text(
            context.l10n.logsTimeRange,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _LogTimeRange.values
                .map(
                  (range) => ChoiceChip(
                    label: Text(range.label ?? context.l10n.logsFilterAll),
                    selected: selectedRange == range,
                    onSelected: (_) => onRangeChanged(range),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.logsLevel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LogLevel.values
                .map(
                  (level) => FilterChip(
                    label: Text(level.name.toUpperCase()),
                    selected: selectedLevels.contains(level),
                    onSelected: (_) => onLevelToggled(level),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.logsFilterByTag,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _commonLogTags)
                FilterChip(
                  label: Text(tag),
                  selected: selectedTags.contains(tag),
                  onSelected: loggingEnabled ? (_) => onTagToggled(tag) : null,
                ),
              for (final tag in customTags)
                FilterChip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(tag, overflow: TextOverflow.ellipsis),
                  ),
                  selected: true,
                  onSelected: loggingEnabled ? (_) => onTagToggled(tag) : null,
                ),
              ActionChip(
                avatar: const Icon(Symbols.add, size: 18),
                label: Text(context.l10n.logsTagCustomAction),
                onPressed: loggingEnabled ? onCustomTagRequested : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(context.l10n.logsPerformanceFilter),
                selected: performanceFilterOnly,
                onSelected: loggingEnabled
                    ? (_) => onPerformanceFilterToggled()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogsDisabledState extends StatelessWidget {
  const _LogsDisabledState({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.visibility_off,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.logsLoggingDisabledTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.logsLoggingDisabledDescription,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onEnable,
                      icon: const Icon(Symbols.play_circle),
                      label: Text(context.l10n.logsEnableLoggingAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (entry.level) {
      LogLevel.debug => colorScheme.secondary,
      LogLevel.info => colorScheme.primary,
      LogLevel.warn => Colors.orange.shade300,
      LogLevel.error => colorScheme.error,
    };

    final elapsedMs = entry.elapsedMs;
    final taskOperation = entry.taskOperation;
    final taskStatus = entry.taskStatus;
    final isTaskEnd =
        entry.isTaskEnd &&
        !entry.isPerformance &&
        elapsedMs != null &&
        taskOperation != null;
    final operation = entry.performanceOperation;
    final status = entry.performanceStatus;
    final title = isTaskEnd
        ? 'TASK ${context.l10n.logsTaskDuration(elapsedMs, taskOperation)} | ${_taskStatusLabel(context, taskStatus)}'
        : entry.isPerformance
        ? context.l10n.logsPerformanceTileTitle(
            elapsedMs ?? 0,
            operation ?? entry.message,
            status ?? 'ok',
          )
        : entry.level.name.toUpperCase();

    final subtitle = StringBuffer(
      '${entry.timestamp.toIso8601String()}\n${entry.message}',
    );
    if (entry.tags.isNotEmpty) {
      final tags = entry.tags.toList(growable: false)..sort();
      subtitle.write('\n${context.l10n.logsEntryTags}: ${tags.join(', ')}');
    }
    final contextMetrics = entry.metrics?['context'];
    if (contextMetrics is Map && contextMetrics.isNotEmpty) {
      subtitle.write('\n${context.l10n.logsEntryContext}: $contextMetrics');
    }
    if (entry.error != null && entry.error!.isNotEmpty) {
      subtitle.write('\nError: ${entry.error}');
    }
    if (entry.stackTrace != null && entry.stackTrace!.isNotEmpty) {
      subtitle.write('\nStack: ${entry.stackTrace}');
    }

    return Container(
      decoration: BoxDecoration(
        color: isTaskEnd
            ? colorScheme.tertiaryContainer.withValues(alpha: 0.24)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTaskEnd
              ? colorScheme.tertiary.withValues(alpha: 0.55)
              : color.withValues(alpha: 0.45),
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isTaskEnd ? colorScheme.tertiary : color,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle.toString(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}
