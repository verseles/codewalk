import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart' hide Page;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/layout/window_size_class.dart';
import '../../shared/sessions/server_path.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../hosts/endpoint_health_controller.dart';
import '../hosts/hosts_controller.dart';
import 'message_action_bar.dart';
import 'message_forward.dart';
import 'project_contexts_controller.dart';
import 'session_tab_strip.dart';
import 'session_tabs_controller.dart';
import 'sessions_controller.dart';

/// Forward for [item] of [source] in its bar (#542): a sent prompt or a
/// whole answer with text, where the conversations of [profile] are listed
/// and their sessions can be opened.
MessageAction? forwardMessageAction(
  BuildContext context, {
  required SessionSummary source,
  required EndpointProfile profile,
  required TimelineItem item,
}) {
  final text = forwardableText(item);
  if (text == null) return null;
  final directory = context.read<SessionLiveDirectory?>();
  final catalog = context.read<SessionsController?>();
  if (directory == null ||
      catalog == null ||
      catalog.selectedProfile?.id != profile.id) {
    return null;
  }
  return MessageAction(
    id: MessageActionId.forward,
    label: context.v2L10n.messageForward,
    icon: Symbols.forward,
    onSelected: (context) => unawaited(
      showForwardMessageDialog(
        context,
        source: source,
        profile: profile,
        text: text,
      ),
    ),
  );
}

/// Asks which conversations [text] goes to, then sends it to each.
Future<void> showForwardMessageDialog(
  BuildContext context, {
  required SessionSummary source,
  required EndpointProfile profile,
  required String text,
}) {
  final catalog = context.read<SessionsController>();
  final directory = context.read<SessionLiveDirectory>();
  final hosts = context.read<HostsController>();
  final health = context.read<EndpointHealthController?>();
  final contexts = context.read<ProjectContextsController?>();
  final tabs = context.read<SessionTabsController?>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.maybeOf(context);
  final root = Navigator.of(context, rootNavigator: true);
  final l10n = context.v2L10n;
  final compact = WindowSizeClass.fromWidth(
    MediaQuery.sizeOf(context).width,
  ).isCompact;
  final provenance = l10n.messageForwardFrom(
    forwardOrigin(source, untitled: l10n.sessionExportUntitled),
  );
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final dialog = ForwardMessageDialog(
        source: source.info.ref,
        catalog: catalog,
        contexts: contexts,
        health: health,
        provenance: provenance,
        text: text,
        offline: () =>
            health?.view(profile).status == EndpointHealthStatus.offline,
        open: (session) async {
          final credential = hosts.credentialFor(profile);
          if (credential == null) {
            throw const SessionLiveException(
              SessionLiveFailure.authenticationRequired,
            );
          }
          // Only for the moment of the send: nothing is answered on the
          // user's behalf while it is open.
          return directory.open(
            profile: profile,
            credential: credential,
            session: session,
            watching: false,
          );
        },
        onForwarded: tabs?.outboxChanged,
        onDone: (count) =>
            showAppSnackBar(messenger, l10n.messageForwardDone(count)),
        onOpen: router == null
            ? null
            : (ref) {
                // A page shown over the conversations, as a history, goes
                // too.
                root.popUntil((route) => route.settings is Page);
                router.go(sessionTabLocation(ref));
              },
      );
      if (compact) return Dialog.fullscreen(child: SafeArea(child: dialog));
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: dialog,
        ),
      );
    },
  );
}

/// Picks the conversations, then shows how sending to each went.
class ForwardMessageDialog extends StatefulWidget {
  const ForwardMessageDialog({
    super.key,
    required this.source,
    required this.catalog,
    required this.contexts,
    required this.provenance,
    required this.text,
    required this.open,
    this.health,
    this.offline,
    this.onForwarded,
    this.onDone,
    this.onOpen,
    this.readyTimeout = const Duration(seconds: 20),
  });

  final SessionRef source;
  final SessionsController catalog;
  final ProjectContextsController? contexts;

  /// Tells when [offline] may have changed.
  final Listenable? health;
  final String provenance;
  final String text;
  final Future<SessionLiveHandle> Function(SessionRef session) open;
  final bool Function()? offline;

  /// A target whose outbox now records the message.
  final void Function(SessionRef session)? onForwarded;

  /// Every target received it, with their count.
  final void Function(int count)? onDone;

  /// Opens a conversation whose delivery is not confirmed.
  final void Function(SessionRef session)? onOpen;
  final Duration readyTimeout;

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  final _query = TextEditingController();
  // Each pick keeps its row, so one that leaves the list still goes and
  // reports why it was not sent to.
  final _selected = <SessionRef, SessionSummary>{};
  MessageForwardRun? _run;

  @override
  void initState() {
    super.initState();
    widget.catalog.addListener(_changed);
    widget.contexts?.addListener(_changed);
    widget.health?.addListener(_changed);
  }

  @override
  void dispose() {
    widget.catalog.removeListener(_changed);
    widget.contexts?.removeListener(_changed);
    widget.health?.removeListener(_changed);
    _run?.removeListener(_changed);
    _run?.detach();
    _query.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// The open projects, in the drawer's order; without them, the projects
  /// of the listed conversations.
  List<String> get _directories {
    final open = widget.contexts?.ordered;
    if (open != null && open.isNotEmpty) return open;
    return {
      for (final row in widget.catalog.sessions)
        ?row.info.project?.canonicalDirectory,
    }.toList();
  }

  List<SessionSummary>? _rowsOf(String directory) {
    if (widget.contexts?.ordered.isNotEmpty ?? false) {
      return widget.catalog.contextRows(directory);
    }
    return [
      for (final row in widget.catalog.sessions)
        if (row.info.project?.canonicalDirectory == directory) row,
    ];
  }

  bool _available(SessionRef ref) {
    final row = widget.catalog.findSession(ref);
    return row != null && forwardTargetAllowed(row, widget.source);
  }

  /// The target as its server has it now; an archive the list has not
  /// learned yet counts.
  Future<bool> _confirm(SessionRef ref) async {
    final task = widget.catalog.read(ref);
    if (task == null) return _available(ref);
    return forwardTargetAllowed(await task.result, widget.source);
  }

  Future<void> _send(List<ForwardGroup> groups) async {
    // One run, however many times Forward is pressed before it shows.
    if (_run != null || _selected.isEmpty) return;
    // Once each, in the list's order; a pick hidden by the search, or no
    // longer listed, still goes.
    final rows = <SessionRef, SessionSummary>{
      for (final group in groups)
        for (final row in group.rows ?? const <SessionSummary>[])
          if (_selected.containsKey(row.info.ref)) row.info.ref: row,
    };
    for (final MapEntry(key: ref, value: picked) in _selected.entries) {
      rows.putIfAbsent(ref, () => widget.catalog.findSession(ref) ?? picked);
    }
    final run = _run = MessageForwardRun(
      text: forwardedText(provenance: widget.provenance, text: widget.text),
      targets: rows.values.toList(),
      open: widget.open,
      available: _available,
      confirm: _confirm,
      offline: widget.offline,
      readyTimeout: widget.readyTimeout,
    )..addListener(_changed);
    setState(() {});
    await run.run();
    _finish(run);
  }

  Future<void> _retry() async {
    final run = _run;
    if (run == null || run.running) return;
    await run.retryFailed();
    _finish(run);
  }

  void _finish(MessageForwardRun run) {
    if (!mounted || !identical(run, _run)) return;
    for (final target in run.targets) {
      if (target.done || target.status == ForwardStatus.unconfirmed) {
        widget.onForwarded?.call(target.ref);
      }
    }
    if (!run.allDone) return;
    Navigator.of(context).pop();
    widget.onDone?.call(run.targets.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final run = _run;
    return PopScope(
      canPop: !(run?.running ?? false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: LayoutBuilder(
          // A short window, as a phone on its side with the keyboard up,
          // keeps the list and its buttons and leaves the preview out.
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.messageForwardTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (constraints.maxHeight >= 400) ...[
                _Preview(provenance: widget.provenance, text: widget.text),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: run == null
                    ? _picker(context, l10n)
                    : _results(l10n, run),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker(BuildContext context, V2Localizations l10n) {
    final offline = widget.offline?.call() ?? false;
    final directories = _directories;
    final groups = forwardTargetGroups(
      directories: directories,
      rowsOf: _rowsOf,
      source: widget.source,
      query: _query.text,
    );
    final loading = groups.any((group) => group.rows == null);
    final none = groups.every((group) => group.rows?.isEmpty ?? true);
    final catalog = widget.catalog;
    // A read that failed, of the list or of another open project: what is
    // still unread offers Retry instead of a spinner.
    final failed =
        (catalog.failure != null || catalog.contextsFailing) &&
        !catalog.loading;
    Widget retry(Key key) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(l10n.messageForwardLoadFailed),
        const SizedBox(height: 8),
        TextButton(
          key: key,
          onPressed: () => unawaited(catalog.refresh()),
          child: Text(l10n.chatRetry),
        ),
      ],
    );
    Widget body;
    if (none && failed) {
      body = retry(const ValueKey('forward_retry_load'));
    } else if (none && (loading || catalog.loading)) {
      body = const Center(child: AppIndeterminateRing(size: 24));
    } else if (directories.isEmpty) {
      body = _Notice(l10n.messageForwardNoProjects);
    } else if (none) {
      body = _Notice(
        _query.text.trim().isEmpty
            ? l10n.messageForwardNoSessions
            : l10n.messageForwardNoMatch,
      );
    } else {
      body = ListView(
        key: const ValueKey('forward_targets'),
        children: [
          for (final group in groups)
            if (group.rows == null || group.rows!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                child: Text(
                  serverPathName(group.directory),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (group.rows == null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: failed
                      ? retry(ValueKey('forward_retry_${group.directory}'))
                      : const Center(child: AppIndeterminateRing(size: 20)),
                )
              else
                for (final row in group.rows!)
                  CheckboxListTile(
                    key: ValueKey('forward_target_${row.info.ref.storageKey}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _selected.containsKey(row.info.ref),
                    onChanged: (value) => setState(() {
                      if (value ?? false) {
                        _selected[row.info.ref] = row;
                      } else {
                        _selected.remove(row.info.ref);
                      }
                    }),
                    title: Text(
                      row.info.title.trim().isEmpty
                          ? l10n.sessionExportUntitled
                          : row.info.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: row.updatedAt == null
                        ? null
                        : Text(
                            _age(l10n, row.updatedAt!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
            ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('forward_search'),
          controller: _query,
          autofocus: !offline,
          decoration: InputDecoration(
            hintText: l10n.messageForwardSearch,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (offline)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.messageForwardOffline,
              key: const ValueKey('forward_offline'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(child: body),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(l10n.messageForwardSelected(_selected.length)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('forward_send'),
              onPressed: _selected.isEmpty || offline
                  ? null
                  : () => unawaited(_send(groups)),
              child: Text(l10n.messageForward),
            ),
          ],
        ),
      ],
    );
  }

  Widget _results(V2Localizations l10n, MessageForwardRun run) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('forward_results'),
            children: [
              for (final target in run.targets)
                ListTile(
                  key: ValueKey('forward_result_${target.ref.storageKey}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: _StatusIcon(target.status),
                  title: Text(
                    target.row.info.title.trim().isEmpty
                        ? l10n.sessionExportUntitled
                        : target.row.info.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_outcome(l10n, target)),
                  // A delivery not confirmed is checked in its conversation.
                  onTap:
                      target.status == ForwardStatus.unconfirmed &&
                          widget.onOpen != null &&
                          !run.running
                      ? () {
                          Navigator.of(context).pop();
                          widget.onOpen!(target.ref);
                        }
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.messageForwardPartial(run.done, run.targets.length),
              ),
            ),
            if (run.running)
              TextButton(
                key: const ValueKey('forward_stop'),
                onPressed: run.stopped ? null : run.stop,
                child: Text(l10n.messageForwardStop),
              )
            else ...[
              if (run.anyFailed ||
                  run.targets.any(
                    (target) => target.status == ForwardStatus.stopped,
                  ))
                TextButton(
                  key: const ValueKey('forward_retry'),
                  onPressed: () => unawaited(_retry()),
                  child: Text(l10n.chatRetry),
                ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('forward_close'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.chatClose),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _outcome(V2Localizations l10n, ForwardTarget target) =>
    switch (target.status) {
      ForwardStatus.pending ||
      ForwardStatus.sending => l10n.messageForwardSending,
      ForwardStatus.queued => l10n.messageForwardQueued,
      ForwardStatus.sent => l10n.messageForwardSent,
      ForwardStatus.unconfirmed => l10n.messageForwardUnconfirmed,
      ForwardStatus.stopped => l10n.messageForwardStopped,
      ForwardStatus.failed => switch (target.miss) {
        ForwardMiss.offline => l10n.messageForwardMissOffline,
        ForwardMiss.gone => l10n.messageForwardMissGone,
        ForwardMiss.busy => l10n.messageForwardMissBusy,
        ForwardMiss.capacity => l10n.messageForwardMissCapacity,
        ForwardMiss.refused => l10n.messageForwardMissRefused,
        ForwardMiss.unavailable || null => l10n.messageForwardMissUnavailable,
      },
    };

/// How long ago [at] was, in the largest whole unit.
String _age(V2Localizations l10n, DateTime at) {
  final passed = DateTime.now().difference(at);
  if (passed.inMinutes < 1) return l10n.messageForwardNow;
  if (passed.inHours < 1) return l10n.messageForwardMinutes(passed.inMinutes);
  if (passed.inDays < 1) return l10n.messageForwardHours(passed.inHours);
  return l10n.messageForwardDays(passed.inDays);
}

class _Preview extends StatelessWidget {
  const _Preview({required this.provenance, required this.text});

  final String provenance;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provenance,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              key: const ValueKey('forward_preview'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);
  final ForwardStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      ForwardStatus.pending => Icon(Symbols.schedule, color: scheme.outline),
      ForwardStatus.sending => const AppIndeterminateRing(size: 20),
      ForwardStatus.queued ||
      ForwardStatus.sent => Icon(Symbols.check_circle, color: scheme.primary),
      ForwardStatus.unconfirmed => Icon(Symbols.help, color: scheme.tertiary),
      ForwardStatus.failed => Icon(Symbols.error, color: scheme.error),
      ForwardStatus.stopped => Icon(Symbols.block, color: scheme.outline),
    };
  }
}
