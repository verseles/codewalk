import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';

/// The body of a tool or shell row: what ran and how it ended, collapsed by
/// default like the retained reference, and its input, output and error on
/// demand.
///
/// Every value shown was bounded and redacted by the adapter; the row redacts
/// again before showing it, so a value that reached it some other way is
/// never shown with a credential. A long value shows its first part and a
/// control for the rest, which stays inside a bounded scroll area.
class SessionToolResult extends StatefulWidget {
  SessionToolResult({required this.item})
    : assert(item is ToolCall || item is ShellRun),
      super(key: ValueKey('tool-result-${item.id.value}'));

  final TimelineItem item;

  /// The part of a value shown before the reader asks for the rest.
  static const previewRunes = 4000;
  static const previewLines = 40;

  @override
  State<SessionToolResult> createState() => _SessionToolResultState();
}

class _SessionToolResultState extends State<SessionToolResult> {
  bool _expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The choice survives the row leaving the lazily built list and coming
    // back, and a rebuild of the page.
    _expanded =
        PageStorage.maybeOf(
              context,
            )?.readState(context, identifier: _storageId)
            as bool? ??
        false;
  }

  /// An explicit identifier, so the scroll areas inside the row never read
  /// this flag as their own offset.
  String get _storageId => 'tool-result-expanded-${widget.item.id.value}';

  void _toggle() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _expanded, identifier: _storageId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final item = widget.item;
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final sections = _sections(item, l10n);
    final key = item.id.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (item) {
          ShellRun(:final command) => Text(
            '\$ ${redactCredentialText(command)}',
            key: ValueKey('tool-title-$key'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: mono,
          ),
          ToolCall(:final rawName) => Text(
            redactCredentialText(rawName),
            key: ValueKey('tool-title-$key'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _ => const SizedBox.shrink(),
        },
        if (_status(item, l10n) case final status?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              status,
              key: ValueKey('tool-status-$key'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: _failed(item)
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (sections.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: ValueKey('tool-toggle-$key'),
              onPressed: _toggle,
              child: Text(
                _expanded ? l10n.chatMessageShowLess : l10n.chatMessageDetails,
              ),
            ),
          ),
        if (_expanded)
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
    );
  }

  bool _failed(TimelineItem item) => switch (item) {
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

  String? _status(TimelineItem item, V2Localizations l10n) {
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
        ShellStatus.exited when exit != null =>
          '${l10n.liveShellExitCode} $exit',
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

  static String _json(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  /// The text parts of a tool's content in order; a file part names only its
  /// type, because its content is never fetched here.
  static String _toolOutput(Object? value) {
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
}

final class _Section {
  const _Section(this.label, this.text, {this.notice, this.error = false});
  final String label;
  final String text;
  final String? notice;
  final bool error;
}

/// One labelled value: its first part, and the rest on demand inside a
/// bounded scroll area.
class _ToolSection extends StatefulWidget {
  const _ToolSection({
    super.key,
    required this.label,
    required this.text,
    required this.style,
    this.notice,
    this.error = false,
  });

  final String label;
  final String text;
  final String? notice;
  final bool error;
  final TextStyle? style;

  @override
  State<_ToolSection> createState() => _ToolSectionState();
}

class _ToolSectionState extends State<_ToolSection> {
  bool _all = false;

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: SelectionArea(
                  child: Text(
                    shown,
                    style: widget.error
                        ? widget.style?.copyWith(color: theme.colorScheme.error)
                        : widget.style,
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

  /// The first [SessionToolResult.previewRunes] characters and
  /// [SessionToolResult.previewLines] lines.
  static String _preview(String text) {
    final runes = text.runes;
    var result = runes.length > SessionToolResult.previewRunes
        ? String.fromCharCodes(runes.take(SessionToolResult.previewRunes))
        : text;
    var lines = 0;
    for (var i = 0; i < result.length; i++) {
      if (result.codeUnitAt(i) == 10 &&
          ++lines >= SessionToolResult.previewLines) {
        result = result.substring(0, i);
        break;
      }
    }
    return result;
  }
}
