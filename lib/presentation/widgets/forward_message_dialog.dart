import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/i18n/l10n_context.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/project.dart';
import '../services/forward_message_service.dart';
import '../theme/app_shapes.dart';

/// Modal dialog that lists the user's recent sessions grouped by project
/// and lets them forward a single message to one or more destinations.
///
/// v1 scope: targets are restricted to the active server's open projects
/// (multi-server forwarding is deferred to a follow-up).
class ForwardMessageDialog extends StatefulWidget {
  const ForwardMessageDialog({
    super.key,
    required this.message,
    required this.forwardService,
    required this.selection,
    required this.originLabel,
  });

  /// The message to forward. Only text parts are extracted (file/agent
  /// parts are out of scope for v1 per the feature spec).
  final ChatMessage message;

  /// Pre-built service so the dialog stays a pure widget and the caller
  /// owns the lifetime of the providers it captures.
  final ForwardMessageService forwardService;

  /// Provider/model/variant applied to the forwarded user message.
  final ForwardSelection selection;

  /// Short human-readable label used in the snackbar and provenance
  /// prefix, e.g. "Project A / My session".
  final String originLabel;

  /// Show the dialog using the given navigator state. Returns the
  /// [ForwardResult] when the user confirms, or null if they cancel.
  static Future<ForwardResult?> show({
    required BuildContext context,
    required ChatMessage message,
    required ForwardMessageService forwardService,
    required ForwardSelection selection,
    required String originLabel,
  }) {
    return showDialog<ForwardResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ForwardMessageDialog(
        message: message,
        forwardService: forwardService,
        selection: selection,
        originLabel: originLabel,
      ),
    );
  }

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  static const int _maxSessionsPerProject = 20;

  ForwardSessionsBundle? _bundle;
  final Set<String> _selectedSessionIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _loading = true;
  Object? _loadError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (_searchController.text == _query) return;
    setState(() {
      _query = _searchController.text;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final bundle = await widget.forwardService.loadTargetSessions(
        perProjectLimit: _maxSessionsPerProject,
      );
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  String get _forwardedText => _extractForwardableText(widget.message);

  bool get _canSubmit =>
      !_submitting && _selectedSessionIds.isNotEmpty && (_bundle?.serverReachable ?? false);

  List<ForwardProjectGroup> get _visibleGroups {
    final groups = _bundle?.groups ?? const <ForwardProjectGroup>[];
    if (_query.trim().isEmpty) return groups;
    final needle = _query.trim().toLowerCase();
    return groups
        .map(
          (g) => ForwardProjectGroup(
            project: g.project,
            sessions: g.sessions
                .where(
                  (s) =>
                      s.title.toLowerCase().contains(needle) ||
                      (s.lastMessagePreview?.toLowerCase().contains(needle) ??
                          false),
                )
                .toList(growable: false),
          ),
        )
        .where((g) => g.sessions.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _onConfirm() async {
    if (!_canSubmit) return;
    final selectedIds = _selectedSessionIds.toSet();
    final groups = _bundle?.groups ?? const <ForwardProjectGroup>[];
    final targets = <ForwardTarget>[];
    for (final group in groups) {
      for (final session in group.sessions) {
        if (!selectedIds.contains(session.id)) continue;
        targets.add(
          ForwardTarget(
            sessionId: session.id,
            directory: session.directory,
            providerId: session.providerId,
            modelId: session.modelId,
          ),
        );
      }
    }
    if (targets.isEmpty) return;

    setState(() {
      _submitting = true;
    });

    final provenanceLine = context.l10n.forwardProvenanceLabel(widget.originLabel);
    final result = await widget.forwardService.forwardToSessions(
      text: _forwardedText,
      provenanceLine: provenanceLine,
      targets: targets,
      selection: widget.selection,
    );

    if (!mounted) return;
    Navigator.of(context).pop<ForwardResult>(result);
  }

  void _onCancel() {
    Navigator.of(context).pop<ForwardResult>(null);
  }

  void _toggleSession(ForwardSession session) {
    setState(() {
      if (_selectedSessionIds.contains(session.id)) {
        _selectedSessionIds.remove(session.id);
      } else {
        _selectedSessionIds.add(session.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.width < 600;
    final previewText = _previewText();

    final dialogChild = _DialogScaffold(
      compact: compact,
      originLabel: widget.originLabel,
      previewText: previewText,
      child: _buildBody(context),
    );

    return PopScope(
      // Prevent barrier / system back while a send is in flight so the
      // ForwardResult + undo mapping cannot be silently dropped by
      // dismissing the dialog mid-send.
      canPop: !_submitting,
      child: Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppShapes.borderLarge,
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? double.infinity : 560,
          maxHeight: mediaQuery.size.height - 64,
        ),
        child: dialogChild,
      ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return _LoadingState(label: context.l10n.forwardLoading);
    }
    if (_loadError != null) {
      return _ErrorState(
        message: _loadError.toString(),
        onRetry: _load,
      );
    }
    final bundle = _bundle;
    if (bundle == null) {
      return const SizedBox.shrink();
    }
    if (!bundle.serverReachable) {
      return _ServerOfflineState();
    }
    final groups = _visibleGroups;
    if (bundle.totalSessions == 0) {
      return _EmptyState(label: context.l10n.forwardNoOpenProjects);
    }
    if (groups.isEmpty) {
      return _EmptyState(label: context.l10n.forwardNoSessions);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.forwardSearchHint,
              prefixIcon: const Icon(Symbols.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            style: theme.textTheme.bodyMedium,
            textInputAction: TextInputAction.search,
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _ProjectGroupSection(
                project: group.project,
                sessions: group.sessions,
                selectedIds: _selectedSessionIds,
                onToggle: _toggleSession,
                searchQuery: _query,
              );
            },
          ),
        ),
        const Divider(height: 1),
        _FooterBar(
          selectedCount: _selectedSessionIds.length,
          canSubmit: _canSubmit,
          submitting: _submitting,
          onCancel: _onCancel,
          onConfirm: _onConfirm,
        ),
      ],
    );
  }

  String _previewText() {
    final raw = _extractForwardableText(widget.message);
    if (raw.isEmpty) return '—';
    return raw.length > 140 ? '${raw.substring(0, 139).trimRight()}…' : raw;
  }
}

class _DialogScaffold extends StatelessWidget {
  const _DialogScaffold({
    required this.compact,
    required this.originLabel,
    required this.previewText,
    required this.child,
  });

  final bool compact;
  final String originLabel;
  final String previewText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.forwardDialogTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.forwardDialogSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: AppShapes.borderSmall,
                ),
                child: Text(
                  previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(child: child),
      ],
    );
  }
}

class _ProjectGroupSection extends StatelessWidget {
  const _ProjectGroupSection({
    required this.project,
    required this.sessions,
    required this.selectedIds,
    required this.onToggle,
    required this.searchQuery,
  });

  final Project project;
  final List<ForwardSession> sessions;
  final Set<String> selectedIds;
  final ValueChanged<ForwardSession> onToggle;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Symbols.folder,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    project.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final session in sessions)
            _SessionTile(
              session: session,
              selected: selectedIds.contains(session.id),
              onTap: () => onToggle(session),
            ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final ForwardSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.borderSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelative(session.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (session.lastMessagePreview != null &&
                      session.lastMessagePreview!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      session.lastMessagePreview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelative(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inSeconds < 60) {
      return L10nBridge.current?.forwardTimeNow ?? 'now';
    }
    if (diff.inMinutes < 60) {
      return L10nBridge.current?.forwardTimeMinutes(diff.inMinutes) ??
          '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return L10nBridge.current?.forwardTimeHours(diff.inHours) ??
          '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return L10nBridge.current?.forwardTimeDays(diff.inDays) ??
          '${diff.inDays}d';
    }
    return L10nBridge.current?.forwardTimeWeeks((diff.inDays / 7).floor()) ??
        '${(diff.inDays / 7).floor()}w';
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({
    required this.selectedCount,
    required this.canSubmit,
    required this.submitting,
    required this.onCancel,
    required this.onConfirm,
  });

  final int selectedCount;
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.forwardSelectedCount(selectedCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: submitting ? null : onCancel,
            child: Text(context.l10n.forwardCancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canSubmit ? onConfirm : null,
            child: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.forwardSend),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.error,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Symbols.refresh),
            label: Text(context.l10n.forwardRetry),
          ),
        ],
      ),
    );
  }
}

class _ServerOfflineState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.cloud_off,
            color: theme.colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.forwardServerOffline,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _extractForwardableText(ChatMessage message) {
  final buffer = StringBuffer();
  for (final part in message.parts) {
    if (part is TextPart && part.text.trim().isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write(part.text.trim());
    }
  }
  return buffer.toString();
}
