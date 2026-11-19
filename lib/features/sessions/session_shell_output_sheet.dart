import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_shells.dart';
import 'session_live_controller.dart';

const _outputPageBytes = 16 * 1024;
const _outputMaxDisplayBytes = 64 * 1024;

/// Clips [text] to at most [limit] UTF-8 bytes on a valid Unicode scalar
/// boundary (never splitting a surrogate pair), returning the clipped string
/// and whether clipping occurred.
({String text, bool clipped}) _clipUtf8(String text, int limit) {
  var bytes = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final pair =
        unit >= 0xd800 &&
        unit <= 0xdbff &&
        i + 1 < text.length &&
        text.codeUnitAt(i + 1) >= 0xdc00 &&
        text.codeUnitAt(i + 1) <= 0xdfff;
    final size = pair ? 4 : (unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3));
    if (bytes + size > limit) {
      return (text: text.substring(0, i), clipped: true);
    }
    bytes += size;
    if (pair) i++;
  }
  return (text: text, clipped: false);
}

/// Opens a bounded, cursor-paged, credential-redacted live output viewer for
/// a harness-observed [ShellWork]. Never reads or displays host file paths,
/// working directories, or OS PIDs.
Future<void> showShellOutputDialog(
  BuildContext context, {
  required SessionLiveController live,
  required ShellWork shell,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ShellOutputDialog(live: live, initialShell: shell),
);

class _ShellOutputDialog extends StatefulWidget {
  const _ShellOutputDialog({required this.live, required this.initialShell});

  final SessionLiveController live;
  final ShellWork initialShell;

  @override
  State<_ShellOutputDialog> createState() => _ShellOutputDialogState();
}

class _ShellOutputDialogState extends State<_ShellOutputDialog> {
  final _cancellation = SessionShellCancellation();
  final _scroll = ScrollController();
  late ShellWork _lastObserved = widget.initialShell;
  String _output = '';
  int _cursor = 0;
  int _size = 0;
  bool _truncated = false;
  bool _cappedLocally = false;
  bool _unavailable = false;
  bool _gone = false;
  bool _stoppedLocally = false;
  SessionShellStopOutcome? _stopOutcome;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage(reset: true));
  }

  @override
  void dispose() {
    _cancellation.cancel();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isLive =>
      widget.live.phase == SessionLivePhase.live &&
      widget.live.view?.stale != true;

  ({ShellWork shell, bool removed}) _resolveShell() {
    final state = widget.live.state;
    if (state == null) {
      return (shell: _lastObserved, removed: _stoppedLocally || _gone);
    }
    for (final item in state.shells) {
      if (item.id == widget.initialShell.id) {
        _lastObserved = item;
        return (shell: item, removed: _stoppedLocally || _gone);
      }
    }
    return (shell: _lastObserved, removed: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (_loading || _cancellation.isCancelled || !_isLive) return;
    final port = widget.live.shells;
    if (port == null || !port.canObserve) {
      if (mounted) setState(() => _unavailable = true);
      return;
    }
    if (!reset && _cappedLocally) return;
    final requestCursor = reset ? 0 : _cursor;
    setState(() => _loading = true);
    try {
      final page = await port.readOutput(
        widget.initialShell.id,
        cursor: requestCursor,
        limit: _outputPageBytes,
        cancellation: _cancellation,
      );
      if (!mounted || _cancellation.isCancelled) return;
      if (page == null) {
        final confirmedGone =
            _isLive && (widget.live.shells?.canObserve ?? false);
        setState(() {
          _unavailable = true;
          if (confirmedGone) _gone = true;
          _loading = false;
        });
        return;
      }
      final combined = reset ? page.output : '$_output${page.output}';
      final redacted = redactCredentialText(combined);
      final clipped = _clipUtf8(redacted, _outputMaxDisplayBytes);
      setState(() {
        _unavailable = false;
        _gone = false;
        _output = clipped.text;
        _cursor = page.cursor;
        _size = reset ? page.size : max(_size, page.size);
        _truncated = reset
            ? (page.truncated || clipped.clipped)
            : (_truncated || page.truncated || clipped.clipped);
        _cappedLocally =
            clipped.clipped ||
            utf8.encode(clipped.text).length >= _outputMaxDisplayBytes;
        _loading = false;
      });
    } on Object {
      if (!mounted || _cancellation.isCancelled) return;
      // Transient read error: surface unavailable notice while keeping Refresh
      // enabled so the user can retry once connectivity recovers.
      setState(() {
        _unavailable = true;
        _loading = false;
      });
    }
  }

  Future<void> _stopShell() async {
    if (!_isLive) return;
    final port = widget.live.shells;
    if (port == null || !port.canStop) return;
    final outcome = await port.stop(widget.initialShell.id);
    if (!mounted) return;
    setState(() {
      _stopOutcome = outcome;
      if (outcome == SessionShellStopOutcome.accepted ||
          outcome == SessionShellStopOutcome.notFound) {
        _stoppedLocally = true;
        _gone = true;
        _unavailable = true;
      }
    });
  }

  String _statusText(
    ShellWork shell,
    V2Localizations l10n, {
    required bool removed,
    required bool current,
  }) {
    if (removed) {
      if (_stoppedLocally) return l10n.liveShellKilled;
      if (!shell.isRunning) {
        return _terminalStatusText(shell, l10n);
      }
      return l10n.liveShellOutputUnavailable;
    }
    if (!current) return l10n.liveSubagentsUnknown;
    if (shell.isRunning) return l10n.toolRunning;
    return _terminalStatusText(shell, l10n);
  }

  String _terminalStatusText(
    ShellWork shell,
    V2Localizations l10n,
  ) => switch (shell.status.known) {
    ShellStatus.timeout =>
      shell.exitToken != null
          ? '${l10n.liveShellTimedOut} · ${l10n.liveShellExitCode} ${shell.exitToken}'
          : l10n.liveShellTimedOut,
    ShellStatus.killed =>
      shell.exitCode != null
          ? '${l10n.liveShellKilled} · ${l10n.liveShellExitCode} ${shell.exitCode}'
          : l10n.liveShellKilled,
    ShellStatus.exited => switch ((shell.exitCode, shell.exitToken)) {
      (0, _) => l10n.liveToolDone,
      (final int code, _) =>
        '${l10n.statusFailed} · ${l10n.liveShellExitCode} $code',
      (null, final String token) => '${l10n.liveShellExitCode} $token',
      _ => l10n.liveSubagentsUnknown,
    },
    ShellStatus.running => l10n.toolRunning,
    null => l10n.liveSubagentsUnknown,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.live,
    builder: (context, _) {
      final l10n = context.v2L10n;
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final current = _isLive;
      final resolved = _resolveShell();
      final shell = resolved.shell;
      final removed = resolved.removed;
      final port = widget.live.shells;
      final canStop =
          current &&
          !removed &&
          port != null &&
          port.canStop &&
          shell.isRunning;
      final stopping = port?.isStopping(shell.id) ?? false;
      final command = redactCredentialText(shell.command);
      final status = _statusText(
        shell,
        l10n,
        removed: removed,
        current: current,
      );
      final unavailable = _unavailable || removed;
      final hasMore =
          current && !unavailable && !_cappedLocally && _cursor < _size;
      final canRefresh =
          current && !removed && (port?.canObserve ?? false) && !_loading;
      final screen = MediaQuery.sizeOf(context);
      final failed =
          shell.status.known == ShellStatus.timeout ||
          shell.status.known == ShellStatus.killed ||
          (shell.exitCode != null && shell.exitCode != 0);
      final stopFeedback = switch (_stopOutcome) {
        SessionShellStopOutcome.rejected => l10n.liveStopFailed,
        SessionShellStopOutcome.uncertain => l10n.liveStopUnconfirmed,
        _ => null,
      };

      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: Dialog(
          key: ValueKey('shell-output-dialog-${shell.id}'),
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: max(220, screen.height * 0.78),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.terminal,
                        size: 20,
                        color: failed
                            ? scheme.error
                            : (!removed && shell.isRunning)
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          command,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      if (port?.canObserve ?? false)
                        IconButton(
                          key: ValueKey('shell-output-refresh-${shell.id}'),
                          tooltip: l10n.liveRetry,
                          onPressed: canRefresh
                              ? () => unawaited(_loadPage(reset: true))
                              : null,
                          icon: const Icon(Symbols.refresh),
                        ),
                      IconButton(
                        key: const ValueKey('shell-output-close'),
                        tooltip: l10n.chatClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Symbols.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          status,
                          key: ValueKey('shell-output-status-${shell.id}'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: failed
                                ? scheme.error
                                : (!removed && shell.isRunning)
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (canStop)
                        TextButton.icon(
                          key: ValueKey('shell-output-stop-${shell.id}'),
                          onPressed: stopping
                              ? null
                              : () => unawaited(_stopShell()),
                          icon: const Icon(Symbols.stop_circle, size: 18),
                          label: Text(
                            stopping ? l10n.liveStopping : l10n.liveStop,
                          ),
                        ),
                    ],
                  ),
                  if (stopFeedback != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      stopFeedback,
                      key: ValueKey('shell-output-stop-notice-${shell.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: unavailable && _output.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.liveShellOutputUnavailable,
                                  key: const ValueKey(
                                    'shell-output-unavailable',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : _output.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.liveShellOutputEmpty,
                                  key: const ValueKey('shell-output-empty'),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Scrollbar(
                                controller: _scroll,
                                child: SingleChildScrollView(
                                  controller: _scroll,
                                  child: SelectionArea(
                                    child: Text(
                                      _output,
                                      key: ValueKey(
                                        'shell-output-text-${shell.id}',
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(fontFamily: 'monospace'),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (unavailable && _output.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.liveShellOutputUnavailable,
                      key: const ValueKey('shell-output-unavailable'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_truncated || (_cappedLocally && _cursor < _size)) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.liveShellOutputPartial,
                      key: const ValueKey('shell-output-truncated'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (hasMore) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: ValueKey('shell-output-more-${shell.id}'),
                        onPressed: _loading
                            ? null
                            : () => unawaited(_loadPage(reset: false)),
                        child: Text(l10n.liveShellLoadMore),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
