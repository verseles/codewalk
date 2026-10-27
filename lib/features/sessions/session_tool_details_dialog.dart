import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/app_shapes.dart';
import '../../shared/theme/app_visual_style_tokens.dart';
import 'session_timeline_projection.dart';

/// The title a tool or shell row shows: the tool's name, or the command.
String toolTitle(TimelineItem item) => switch (item) {
  ShellRun(:final command) => '\$ ${redactCredentialText(command)}',
  ToolCall(:final rawName) => redactCredentialText(rawName),
  _ => '',
};

/// How a tool or shell run stands, for the counts of a run of calls.
enum ToolProgress { queued, running, done, attention, unknown }

ToolProgress toolProgress(TimelineItem item) {
  if (item case ShellRun(:final shellStatus?)) {
    return switch (shellStatus.known) {
      ShellStatus.running => ToolProgress.running,
      ShellStatus.exited when item.exitCode == 0 => ToolProgress.done,
      ShellStatus.exited when item.exitCode != null => ToolProgress.attention,
      ShellStatus.timeout || ShellStatus.killed => ToolProgress.attention,
      _ => ToolProgress.unknown,
    };
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
    final tokens = Theme.of(context).visualStyleTokens;
    final live = this.live;
    Widget body(TimelineItem item) => _ToolDetailsBody(item: item);
    return Dialog(
      key: ValueKey('tool-details-${item.id.value}'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: tokens.isRefined
            ? tokens.dialogRadius
            : AppShapes.borderLarge,
      ),
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
                  Icon(
                    item is ShellRun ? Symbols.terminal : Symbols.build,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      toolTitle(item),
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
          if (toolStatusLabel(item, l10n) case final status?)
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
  ShellRun(shellStatus: OpenValue(known: final status?)) => switch (status) {
    ShellStatus.timeout || ShellStatus.killed => true,
    ShellStatus.exited => item.exitCode != null && item.exitCode != 0,
    ShellStatus.running => false,
  },
  _ => switch (item.status.known) {
    ItemStatus.failed || ItemStatus.interrupted => true,
    _ => false,
  },
};

/// How a tool or shell run stands, in words; null when nothing is known.
String? toolStatusLabel(TimelineItem item, V2Localizations l10n) {
  if (item case ShellRun(:final shellStatus?)) {
    final exit = item.exitCode?.toString() ?? item.exitToken;
    final code = exit == null ? '' : ' · ${l10n.liveShellExitCode} $exit';
    return switch (shellStatus.known) {
      ShellStatus.running => l10n.toolRunning,
      ShellStatus.exited when item.exitCode == 0 => l10n.liveToolDone,
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
  return switch (item.status.known) {
    ItemStatus.streaming => l10n.toolRunning,
    ItemStatus.completed => l10n.liveToolDone,
    ItemStatus.failed => l10n.statusFailed,
    ItemStatus.interrupted => l10n.liveToolInterrupted,
    ItemStatus.pending || null => null,
  };
}

/// Whether a tool or shell run has details to show.
bool toolHasDetails(TimelineItem item) => switch (item) {
  ToolCall(:final input, :final output, :final error) =>
    input != null || output != null || error != null,
  ShellRun() => true,
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
