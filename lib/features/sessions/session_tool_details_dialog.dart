import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_surface_tokens.dart';
import 'session_timeline_projection.dart';

/// Material symbol matching the canonical kind of a tool or shell run.
IconData toolIcon(TimelineItem item) => switch (item) {
  ShellRun() => Symbols.terminal,
  Notice(shellReport: _?) => Symbols.terminal,
  ToolCall(:final kind) => switch (kind.known) {
    ToolKind.shell => Symbols.terminal,
    ToolKind.read => Symbols.description,
    ToolKind.edit => Symbols.edit,
    ToolKind.write => Symbols.edit_document,
    ToolKind.search => Symbols.search,
    ToolKind.fetch => Symbols.download,
    ToolKind.webSearch => Symbols.travel_explore,
    ToolKind.skill => Symbols.auto_stories,
    ToolKind.question => Symbols.help,
    ToolKind.subagent => Symbols.smart_toy,
    ToolKind.mcp || ToolKind.other || null => Symbols.build,
  },
  _ => Symbols.build,
};

/// Short localized kind label for a compact tool or shell row.
String toolKindLabel(TimelineItem item, V2Localizations l10n) => switch (item) {
  ShellRun() => l10n.toolKindShell,
  Notice(shellReport: _?) => l10n.toolKindShell,
  ToolCall(:final kind, :final rawName) => switch (kind.known) {
    ToolKind.shell => l10n.toolKindShell,
    ToolKind.read => l10n.toolKindRead,
    ToolKind.edit => l10n.toolKindEdit,
    ToolKind.write => l10n.toolKindWrite,
    ToolKind.search => l10n.toolKindSearch,
    ToolKind.fetch => l10n.toolKindFetch,
    ToolKind.webSearch => l10n.toolKindWebSearch,
    ToolKind.skill => l10n.toolKindSkill,
    ToolKind.question => l10n.toolKindQuestion,
    ToolKind.subagent => l10n.liveSubagentsTitle,
    ToolKind.mcp || ToolKind.other || null =>
      redactCredentialText(rawName).trim().isNotEmpty
          ? redactCredentialText(rawName).trim()
          : l10n.toolKindTool,
  },
  _ => '',
};

/// Redacted single-line primary argument for a compact tool or shell row.
///
/// Only reads bounded canonical keys (`command`, `path`, `pattern`, `url`,
/// `query`, `name`, `header`); never parses `patchText` or arbitrary blobs.
String? toolTarget(TimelineItem item) {
  String? clean(Object? value) {
    if (value is! String) return null;
    final single = redactCredentialText(
      value,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    return single.isEmpty ? null : single;
  }

  switch (item) {
    case ShellRun(:final command):
      return clean(command);
    case Notice(:final shellReport?):
      return clean(shellReport.command);
    case ToolCall(:final input):
      final value = input?.value;
      if (value is! Map<Object?, Object?>) return null;
      for (final key in const [
        'command',
        'path',
        'pattern',
        'url',
        'query',
        'name',
        'header',
      ]) {
        final found = clean(value[key]);
        if (found != null) return found;
      }
      if (value['questions'] case final List<Object?> questions
          when questions.isNotEmpty) {
        final first = questions.first;
        if (first is Map<Object?, Object?>) {
          return clean(first['header']);
        }
      }
      return null;
    default:
      return null;
  }
}

/// Concise single-line label (`Kind · target`) used in compact timeline rows
/// and the composer status bar.
String toolCompactSummary(TimelineItem item, V2Localizations l10n) {
  final label = toolKindLabel(item, l10n);
  final target = toolTarget(item);
  if (target == null || target.isEmpty) return label;
  return label.isEmpty ? target : '$label · $target';
}

/// Whether [facts] reports a shell tool that is still running (including a
/// backgrounded shell call whose tool part completed without an exit).
bool _factsRunning(ToolRunFacts facts) =>
    facts.shellStatus?.known == ShellStatus.running ||
    (facts.background &&
        facts.exitCode == null &&
        facts.exitToken == null &&
        facts.shellStatus?.known != ShellStatus.exited &&
        !facts.timedOut &&
        !facts.interrupted);

/// How a tool or shell run stands, for summaries and compact badges.
enum ToolProgress { queued, running, done, attention, unknown }

ToolProgress toolProgress(TimelineItem item) {
  if (item case Notice(shellReport: final report?)) {
    if (report.timedOut ||
        report.killed ||
        report.outcome == OutcomeKind.failed ||
        report.outcome == OutcomeKind.interrupted) {
      return ToolProgress.attention;
    }
    if (report.exitCode != null) {
      return report.exitCode == 0 ? ToolProgress.done : ToolProgress.attention;
    }
    if (report.outcome == OutcomeKind.succeeded) return ToolProgress.done;
    if (report.exitToken != null) return ToolProgress.unknown;
    return ToolProgress.done;
  }
  if (item case ShellRun(:final shellStatus?)) {
    return switch (shellStatus.known) {
      ShellStatus.running => ToolProgress.running,
      ShellStatus.exited when item.exitCode == 0 => ToolProgress.done,
      ShellStatus.exited when item.exitCode != null => ToolProgress.attention,
      ShellStatus.timeout || ShellStatus.killed => ToolProgress.attention,
      _ => ToolProgress.unknown,
    };
  }
  if (item case ToolCall(:final runFacts?)) {
    final itemStatus = item.status.known;
    if (itemStatus == ItemStatus.failed ||
        itemStatus == ItemStatus.interrupted) {
      return ToolProgress.attention;
    }
    if (runFacts.timedOut ||
        runFacts.interrupted ||
        runFacts.shellStatus?.known == ShellStatus.timeout ||
        runFacts.shellStatus?.known == ShellStatus.killed) {
      return ToolProgress.attention;
    }
    if (_factsRunning(runFacts)) return ToolProgress.running;
    if (runFacts.exitCode != null) {
      return runFacts.exitCode == 0
          ? ToolProgress.done
          : ToolProgress.attention;
    }
    if (runFacts.exitToken != null) return ToolProgress.unknown;
  }
  return switch (item.status.known) {
    ItemStatus.pending => ToolProgress.queued,
    ItemStatus.streaming => ToolProgress.running,
    ItemStatus.completed => ToolProgress.done,
    ItemStatus.failed || ItemStatus.interrupted => ToolProgress.attention,
    null => ToolProgress.unknown,
  };
}

/// Opens the details of a tool or shell run: its input, output and error, in
/// a bounded dialog that scrolls and closes with its button, the barrier or
/// Escape. Opened from the live timeline, it follows the item as it changes.
Future<void> showToolDetailsDialog(BuildContext context, TimelineItem item) {
  final live = SessionTimelineScope.maybeOf(context)?.items;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ToolDetailsDialog(item: item, live: live),
  );
}

class _ToolDetailsDialog extends StatelessWidget {
  const _ToolDetailsDialog({required this.item, required this.live});

  final TimelineItem item;
  final ValueListenable<List<TimelineItem>>? live;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final tokens = Theme.of(context).surfaceTokens;
    final live = this.live;
    Widget body(TimelineItem item) => _ToolDetailsBody(item: item);
    return Dialog(
      key: ValueKey('tool-details-${item.id.value}'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: tokens.dialogRadius),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(toolIcon(item), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      toolCompactSummary(item, l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('tool-details-close'),
                    icon: const Icon(Symbols.close),
                    tooltip: l10n.chatClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: live == null
                  ? body(item)
                  : ValueListenableBuilder(
                      valueListenable: live,
                      builder: (context, items, _) => body(
                        items.where((i) => i.id == item.id).firstOrNull ?? item,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolDetailsBody extends StatelessWidget {
  const _ToolDetailsBody({required this.item});

  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final sections = _sections(item, l10n);
    final key = item.id.value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (toolStatusLabel(item, l10n, includeDone: true) case final status?)
            Text(
              status,
              style: theme.textTheme.labelMedium?.copyWith(
                color: toolFailed(item)
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final (index, section) in sections.indexed)
            _ToolSection(
              key: ValueKey('tool-section-$key-$index'),
              label: section.label,
              text: section.text,
              notice: section.notice,
              error: section.error,
              style: mono,
            ),
        ],
      ),
    );
  }
}

/// Whether a tool or shell run ended in a failure the reader must see.
bool toolFailed(TimelineItem item) => switch (item) {
  Notice(shellReport: final report?) =>
    report.timedOut ||
        report.killed ||
        report.outcome == OutcomeKind.failed ||
        report.outcome == OutcomeKind.interrupted ||
        (report.exitCode != null && report.exitCode != 0),
  ShellRun(shellStatus: OpenValue(known: final status?)) => switch (status) {
    ShellStatus.timeout || ShellStatus.killed => true,
    ShellStatus.exited => item.exitCode != null && item.exitCode != 0,
    ShellStatus.running => false,
  },
  ToolCall(:final runFacts?) =>
    runFacts.timedOut ||
        runFacts.interrupted ||
        runFacts.shellStatus?.known == ShellStatus.timeout ||
        runFacts.shellStatus?.known == ShellStatus.killed ||
        (runFacts.exitCode != null && runFacts.exitCode != 0) ||
        item.status.known == ItemStatus.failed ||
        item.status.known == ItemStatus.interrupted,
  _ => switch (item.status.known) {
    ItemStatus.failed || ItemStatus.interrupted => true,
    _ => false,
  },
};

/// How a tool or shell run stands, in words; null on clean success unless
/// [includeDone] is true (used inside the details dialog).
String? toolStatusLabel(
  TimelineItem item,
  V2Localizations l10n, {
  bool includeDone = false,
}) {
  if (item case Notice(shellReport: final report?)) {
    final exit = report.exitCode?.toString() ?? report.exitToken;
    final code = exit == null ? '' : ' · ${l10n.liveShellExitCode} $exit';
    if (report.timedOut) return '${l10n.liveShellTimedOut}$code';
    if (report.killed) return '${l10n.liveShellKilled}$code';
    if (report.outcome == OutcomeKind.interrupted) {
      return '${l10n.liveToolInterrupted}$code';
    }
    if (report.outcome == OutcomeKind.failed ||
        (report.exitCode != null && report.exitCode != 0)) {
      return '${l10n.statusFailed}$code';
    }
    if (report.outcome == OutcomeKind.succeeded || report.exitCode == 0) {
      return includeDone ? l10n.liveToolDone : null;
    }
    if (report.exitToken != null) {
      return '${l10n.liveShellExitCode} ${report.exitToken}';
    }
    return includeDone ? l10n.liveToolDone : null;
  }
  if (item case ShellRun(:final shellStatus?)) {
    final exit = item.exitCode?.toString() ?? item.exitToken;
    final code = exit == null ? '' : ' · ${l10n.liveShellExitCode} $exit';
    return switch (shellStatus.known) {
      ShellStatus.running => l10n.toolRunning,
      ShellStatus.exited when item.exitCode == 0 =>
        includeDone ? l10n.liveToolDone : null,
      // Only a reported nonzero code is a failure; without one the outcome
      // is unknown and only the token, if any, is shown.
      ShellStatus.exited when item.exitCode != null =>
        '${l10n.statusFailed}$code',
      ShellStatus.exited when exit != null => '${l10n.liveShellExitCode} $exit',
      ShellStatus.exited => null,
      ShellStatus.timeout => '${l10n.liveShellTimedOut}$code',
      ShellStatus.killed => '${l10n.liveShellKilled}$code',
      null => null,
    };
  }
  if (item case ToolCall(:final runFacts?)) {
    final exit = runFacts.exitCode?.toString() ?? runFacts.exitToken;
    final code = exit == null ? '' : ' · ${l10n.liveShellExitCode} $exit';
    final itemStatus = item.status.known;
    if (runFacts.timedOut ||
        runFacts.shellStatus?.known == ShellStatus.timeout) {
      return '${l10n.liveShellTimedOut}$code';
    }
    if (runFacts.interrupted || itemStatus == ItemStatus.interrupted) {
      return '${l10n.liveToolInterrupted}$code';
    }
    if (runFacts.shellStatus?.known == ShellStatus.killed) {
      return '${l10n.liveShellKilled}$code';
    }
    if (itemStatus == ItemStatus.failed) {
      return '${l10n.statusFailed}$code';
    }
    if (_factsRunning(runFacts)) {
      return l10n.toolRunning;
    }
    if (runFacts.exitCode != null) {
      if (runFacts.exitCode == 0) {
        return includeDone ? l10n.liveToolDone : null;
      }
      return '${l10n.statusFailed}$code';
    }
    if (runFacts.exitToken != null) {
      return '${l10n.liveShellExitCode} ${runFacts.exitToken}';
    }
  }
  return switch (item.status.known) {
    ItemStatus.pending => l10n.composerQueued,
    ItemStatus.streaming => l10n.toolRunning,
    ItemStatus.completed => includeDone ? l10n.liveToolDone : null,
    ItemStatus.failed => l10n.statusFailed,
    ItemStatus.interrupted => l10n.liveToolInterrupted,
    null => null,
  };
}

/// Whether a tool or shell run has details to show.
bool toolHasDetails(TimelineItem item) => switch (item) {
  ToolCall(:final input, :final output, :final error) =>
    input != null || output != null || error != null,
  ShellRun() => true,
  Notice(shellReport: _?) => true,
  _ => false,
};

List<_Section> _sections(TimelineItem item, V2Localizations l10n) {
  switch (item) {
    case ToolCall(:final input, :final output, :final error):
      return [
        if (input != null)
          _Section(l10n.chatMessageToolInput, _json(input.value)),
        if (output != null)
          _Section(l10n.liveToolOutput, _toolOutput(output.value)),
        if (error != null)
          _Section(
            l10n.diagnosticsError,
            error.rawMessage.isEmpty ? error.rawType : error.rawMessage,
            error: true,
          ),
      ];
    case ShellRun(:final outputText, :final output):
      return [
        _Section(l10n.chatMessageToolCommand, item.command),
        if (outputText != null)
          _Section(
            l10n.liveToolOutput,
            outputText,
            notice: (output?.truncated ?? false)
                ? l10n.liveShellOutputPartial
                : null,
          ),
      ];
    case Notice(shellReport: final report?, :final text):
      final command = report.command?.trim();
      final body = text.trim().isEmpty ? l10n.liveShellOutputEmpty : text;
      return [
        if (command != null && command.isNotEmpty)
          _Section(l10n.chatMessageToolCommand, command),
        _Section(
          l10n.liveToolOutput,
          body,
          notice: report.truncated ? l10n.liveShellOutputPartial : null,
        ),
      ];
    default:
      return const [];
  }
}

String _json(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// The text parts of a tool's content in order; a file part names only its
/// type, because its content is never fetched here.
String _toolOutput(Object? value) {
  if (value is! List) return _json(value);
  return [
    for (final part in value)
      if (part is Map && part['type'] == 'text')
        '${part['text']}'
      else if (part is Map && part['type'] == 'file')
        '[${part['mime']}]'
      else
        _json(part),
  ].join('\n');
}

final class _Section {
  const _Section(this.label, this.text, {this.notice, this.error = false});
  final String label;
  final String text;
  final String? notice;
  final bool error;
}

/// One labelled value: its first part, and the rest on demand, inside a
/// bounded scroll area of its own.
///
/// The area opens at the top. While the value grows, it keeps the newest
/// part in view only when the reader is already at its end.
class _ToolSection extends StatefulWidget {
  const _ToolSection({
    super.key,
    required this.label,
    required this.text,
    required this.style,
    this.notice,
    this.error = false,
  });

  /// The part of a value shown before the reader asks for the rest.
  static const previewRunes = 4000;
  static const previewLines = 40;

  final String label;
  final String text;
  final String? notice;
  final bool error;
  final TextStyle? style;

  @override
  State<_ToolSection> createState() => _ToolSectionState();
}

class _ToolSectionState extends State<_ToolSection> {
  final _scroll = ScrollController();
  bool _all = false;

  @override
  void didUpdateWidget(covariant _ToolSection old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > 24) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final text = redactCredentialText(widget.text);
    final preview = _preview(text);
    final cut = preview.length < text.length;
    final shown = _all ? text : preview;
    final maxHeight = min(300.0, MediaQuery.sizeOf(context).height * 0.4);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(8),
                  child: SelectionArea(
                    child: Text(
                      shown,
                      style: widget.error
                          ? widget.style?.copyWith(
                              color: theme.colorScheme.error,
                            )
                          : widget.style,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (cut || widget.notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.notice ?? l10n.chatMessageToolOutputTruncated,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (cut)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                child: Text(
                  _all ? l10n.chatMessageShowLess : l10n.chatMessageShowMore,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The first [_ToolSection.previewRunes] characters and
  /// [_ToolSection.previewLines] lines.
  static String _preview(String text) {
    final runes = text.runes;
    var result = runes.length > _ToolSection.previewRunes
        ? String.fromCharCodes(runes.take(_ToolSection.previewRunes))
        : text;
    var lines = 0;
    for (var i = 0; i < result.length; i++) {
      if (result.codeUnitAt(i) == 10 && ++lines >= _ToolSection.previewLines) {
        result = result.substring(0, i);
        break;
      }
    }
    return result;
  }
}
